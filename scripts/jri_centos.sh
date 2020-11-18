#!/bin/bash -e
# David Ghedini
# For use on fresh CentOS 8 install only!!!

function disable_selinux(){
	setenforce 0
	sed -i.save 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
}

function install_tomcat_archive(){

	if [ ! -d /home/tomcat ]; then
		useradd -m tomcat
	fi
	cd /home/tomcat

	if [ ! -d apache-tomcat-${TOMCAT_VER} ]; then
		if [ ! -f /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz ]; then
			wget --no-check-certificate -P/tmp http://www.us.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz
		fi
		tar xzf /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz
		chown -R tomcat:tomcat apache-tomcat-${TOMCAT_VER}
		rm -rf /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz
	fi

	if [ $(grep -m 1 -c CATALINA_HOME /etc/environment) -eq 0 ]; then
		cat >>/etc/environment <<EOF
export CATALINA_HOME=${CATALINA_HOME}
export CATALINA_BASE=${CATALINA_HOME}
EOF
	fi

  echo "CATALINA_PID=\"/home/tomcat/apache-tomcat-${TOMCAT_VER}/temp/tomcat.pid\"" >> ${CATALINA_HOME}/bin/setenv.sh

	TOMCAT_MANAGER_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32);
	TOMCAT_ADMIN_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32);

	if [ $(grep -m 1 -c 'tomcat manager pass' /root/auth.txt) -eq 0 ]; then
		echo "tomcat manager pass: ${TOMCAT_MANAGER_PASS}" >> /root/auth.txt
	else
		sed -i.save "s/tomcat manager pass: .*/tomcat manager pass: ${TOMCAT_MANAGER_PASS}/" /root/auth.txt
	fi

	if [ $(grep -m 1 -c 'tomcat admin pass' /root/auth.txt) -eq 0 ]; then
		echo "tomcat admin pass: ${TOMCAT_ADMIN_PASS}" >> /root/auth.txt
	else
		sed -i.save "s/tomcat admin pass: .*/tomcat admin pass: ${TOMCAT_ADMIN_PASS}/" /root/auth.txt
	fi

	cat >${CATALINA_HOME}/conf/tomcat-users.xml <<EOF
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
<role rolename="manager-gui" />
<user username="manager" password="${TOMCAT_MANAGER_PASS}" roles="manager-gui" />

<role rolename="admin-gui" />
<user username="admin" password="${TOMCAT_ADMIN_PASS}" roles="manager-gui,admin-gui" />
</tomcat-users>
EOF

	#folder is created after tomcat is started, but we need it now
	mkdir -p ${CATALINA_HOME}/conf/Catalina/localhost/
	cat >${CATALINA_HOME}/conf/Catalina/localhost/manager.xml <<EOF
<Context privileged="true" antiResourceLocking="false" docBase="\${catalina.home}/webapps/manager">
	<Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*\$" />
</Context>
EOF

	chown -R tomcat:tomcat /home/tomcat

	cat >/etc/init.d/tomcat <<EOF
#!/bin/bash
### BEGIN INIT INFO
# Provides:        tomcat
# Required-Start:  \$network
# Required-Stop:   \$network
# Default-Start:   2 3 4 5
# Default-Stop:    0 1 6
# Short-Description: Start/Stop Tomcat server
### END INIT INFO

# Source function library.
. /etc/environment;	#Catalina variables
. \$CATALINA_HOME/bin/setenv.sh

RETVAL=\$?

function start(){
	echo "Starting Tomcat"
	/bin/su - tomcat \$CATALINA_HOME/bin/startup.sh
	RETVAL=\$?
}

function stop(){
	echo "Stopping Tomcat"
	/bin/su - tomcat -c "\$CATALINA_HOME/bin/shutdown.sh 60 -force"
	RETVAL=\$?
}

case "\$1" in
 start)
		start;
        ;;
 stop)
		stop;
        ;;
 restart)
		echo "Restarting Tomcat"
    stop;
		start;
        ;;
 status)

		if [ -f "\${CATALINA_PID}" ]; then
			TOMCAT_PID=\$(cat "\${CATALINA_PID}")
			echo "Tomcat is running with PID \${TOMCAT_PID}";
			RETVAL=1
		else
			echo "Tomcat is not running";
			RETVAL=0
		fi
		;;
 *)
        echo \$"Usage: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac
exit \$RETVAL
EOF

	chmod +x /etc/init.d/tomcat
	systemctl enable tomcat
	systemctl start tomcat
}

function install_webmin(){
	cat >/etc/yum.repos.d/webmin.repo <<EOF
[Webmin]
name=Webmin Distribution Neutral
baseurl=http://download.webmin.com/download/yum
enabled=1
gpgcheck=1
gpgkey=http://www.webmin.com/jcameron-key.asc
EOF

	dnf install -y webmin
}

function install_java(){
	dnf install -y java-1.8.0-openjdk-headless java-1.8.0-openjdk-devel
}

function install_jri_module(){
  wget --no-check-certificate -P/tmp https://github.com/DavidGhedini/jri-publisher/archive/master.zip

  unzip /tmp/master.zip
  rm -f /tmp/master.zip

  mv jri-publisher-master jri_publisher
	tar -czf /tmp/jri_publisher.wbm.gz jri_publisher
	rm -rf jri_publisher

	/usr/libexec/webmin/install-module.pl /tmp/jri_publisher.wbm.gz
	rm -f /tmp/jri_publisher.wbm.gz

  mv /usr/libexec/webmin/jri_publisher/gen_jri_report.sh /usr/local/bin/
  chmod +x /usr/local/bin/gen_jri_report.sh

	#install the module app
	cp -r /usr/libexec/webmin/jri_publisher/app/* /var/www/html
	chown -R apache:apache /var/www/html/

	HOST_IP=$(hostname -I | cut -f1 -d' ')
	sed -i.save "s/xyzIP/${HOST_IP}/g" /var/www/html/index.html
	rm -f /var/www/html/index.html.save

	if [ ! -d /etc/webmin/authentic-theme ]; then
		mkdir -p /etc/webmin/authentic-theme
		cp -r /usr/libexec/webmin/jri_publisher/app/portal/*  /etc/webmin/authentic-theme
	fi
	rm -rf /usr/share/webmin/jri_publisher/app
}

function install_jri_war(){

  JASPER_HOME="${CATALINA_HOME}/jasper_reports"
	mkdir -p "${JASPER_HOME}"

  JRI_URL_PATH=$(wget -O- https://github.com/daust/JasperReportsIntegration/releases/latest | sed -n 's|.*\(/daust/JasperReportsIntegration/releases/download/.*\.zip\).*|\1|p')

  wget --no-check-certificate -P/tmp "https://github.com/${JRI_URL_PATH}"
  JRI_ARCHIVE=$(basename ${JRI_URL_PATH})

  unzip /tmp/${JRI_ARCHIVE}
  rm -f /tmp/${JRI_ARCHIVE}

  JRI_FOLDER=$(echo ${JRI_ARCHIVE} | sed 's/.zip//')
  mv ${JRI_FOLDER}/webapp/jri.war ${CATALINA_HOME}/webapps/JasperReportsIntegration.war

  for d in reports conf logs schedules; do
    if [ -d ${JRI_FOLDER}/${d} ]; then
      mv ${JRI_FOLDER}/${d} ${JASPER_HOME}/${d}
    else
      mkdir ${JASPER_HOME}/${d}
    fi
  done

  #run jri script setConfigDir.sh
  pushd ${JRI_FOLDER}/bin
    chmod +x encryptPasswords.sh
    if [ -f setConfigDir.sh ]; then
      chmod +x setConfigDir.sh
      ./setConfigDir.sh ${CATALINA_HOME}/webapps/JasperReportsIntegration.war ${JASPER_HOME}
    fi
  popd
  rm -rf ${JRI_FOLDER}

  chown -R tomcat:tomcat ${JASPER_HOME}

  echo "OC_JASPER_CONFIG_HOME=\"${JASPER_HOME}\"" >> ${CATALINA_HOME}/bin/setenv.sh

  systemctl restart tomcat
}

function install_jri_pg(){
  JRI_PG_VER=$(wget -O- https://jdbc.postgresql.org/download.html | sed -n 's/.*href="download\/postgresql\-\([0-9\.]\+\)\.jar.*/\1/p' | head -n 1)

  wget --no-check-certificate -P/tmp "https://jdbc.postgresql.org/download/postgresql-${JRI_PG_VER}.jar"
  mv /tmp/postgresql-${JRI_PG_VER}.jar ${CATALINA_HOME}/lib/

  sed -i.save '/^<\/Context>/d' ${CATALINA_HOME}/conf/context.xml

  cat >>${CATALINA_HOME}/conf/context.xml <<CMD_EOF
<Resource name="jdbc/postgres" auth="Container" type="javax.sql.DataSource"
  driverClassName="org.postgresql.Driver"
  maxTotal="20" initialSize="0" minIdle="0" maxIdle="8"
  maxWaitMillis="10000" timeBetweenEvictionRunsMillis="30000"
  minEvictableIdleTimeMillis="60000" testWhileIdle="true"
  validationQuery="select user" maxAge="600000"
  rollbackOnReturn="true"
  url="jdbc:postgresql://localhost:5432/xxx"
  username="xxx"
  password="xxx"
/>
</Context>
CMD_EOF


  sed -i.save '/^<\/web-app>/d' ${CATALINA_HOME}/webapps/JasperReportsIntegration/WEB-INF/web.xml

  cat >>${CATALINA_HOME}/webapps/JasperReportsIntegration/WEB-INF/web.xml <<CMD_EOF
<resource-ref>
  <description>postgreSQL Datasource example</description>
  <res-ref-name>jdbc/postgres</res-ref-name>
  <res-type>javax.sql.DataSource</res-type>
  <res-auth>Container</res-auth>
</resource-ref>
</web-app>
CMD_EOF
}

function install_jri_mysql(){
  JRI_MYSQL_VER=$(wget -O- https://dev.mysql.com/downloads/connector/j/ | sed -n 's/.*<h1>Connector\/J\s*\([0-9\.]\+\).*/\1/p')

  wget --no-check-certificate -P/tmp "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${JRI_MYSQL_VER}.zip"
  pushd /tmp/
    unzip /tmp/mysql-connector-java-${JRI_MYSQL_VER}.zip
    mv mysql-connector-java-${JRI_MYSQL_VER}/mysql-connector-java-${JRI_MYSQL_VER}.jar ${CATALINA_HOME}/lib/
    rm -rf mysql-connector-java-${JRI_MYSQL_VER}/
  popd

  sed -i.save '/^<\/Context>/d' ${CATALINA_HOME}/conf/context.xml
  cat >>${CATALINA_HOME}/conf/context.xml <<CMD_EOF
<Resource name="jdbc/MySQL" auth="Container" type="javax.sql.DataSource"
maxTotal="100" maxIdle="30" maxWaitMillis="10000"
driverClassName="com.mysql.jdbc.Driver"
username="xxx" password="xxx"  url="jdbc:mysql://localhost:3306/xxx"/>
</Context>
CMD_EOF

  sed -i.save '/^<\/web-app>/d' ${CATALINA_HOME}/webapps/JasperReportsIntegration/WEB-INF/web.xml
  cat >>${CATALINA_HOME}/webapps/JasperReportsIntegration/WEB-INF/web.xml <<CMD_EOF
<resource-ref>
<description>MySQL Datasource example</description>
<res-ref-name>jdbc/MySQL</res-ref-name>
<res-type>javax.sql.DataSource</res-type>
<res-auth>Container</res-auth>
</resource-ref>
</web-app>
CMD_EOF
}

function install_jri_mssql(){
  wget -O/tmp/mssql.html 'https://docs.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server?view=sql-server-ver15'

  JRI_MSSQL_URL=$(grep 'Download Microsoft JDBC Driver' /tmp/mssql.html | grep 'SQL Server (zip)' | grep 'linkid=' | cut -f2 -d'"')
  JRI_MSSQL_VER=$(grep -m 1 "${JRI_MSSQL_URL}" /tmp/mssql.html | sed -n 's/.*Download Microsoft JDBC Driver \([0-9\.]\+\) for SQL Server (zip).*/\1/p')
  wget -O/tmp/mssql.zip "${JRI_MSSQL_URL}"

  mkdir -p temp
  pushd temp
    unzip /tmp/mssql.zip
    find "sqljdbc_${JRI_MSSQL_VER}\\enu/" -type f -name "mssql-jdbc-*.jre8.jar" -exec mv {} ${CATALINA_HOME}/lib/ \;
  popd
  rm -r temp /tmp/mssql.zip

  sed -i.save '/^<\/Context>/d' ${CATALINA_HOME}/conf/context.xml
  cat >>${CATALINA_HOME}/conf/context.xml <<CMD_EOF
<Resource name="jdbc/MSSQL" auth="Container" type="javax.sql.DataSource"
maxTotal="100" maxIdle="30" maxWaitMillis="10000"
driverClassName="com.microsoft.sqlserver.jdbc.SQLServerDriver"
username="xxx" password="xxx"  url="jdbc:sqlserver://localhost:1433;databaseName=xxx"/>
</Context>
CMD_EOF


sed -i.save '/^<\/web-app>/d' ${CATALINA_HOME}/webapps/JasperReportsIntegration/WEB-INF/web.xml
cat >>${CATALINA_HOME}/webapps/JasperReportsIntegration/WEB-INF/web.xml <<CMD_EOF
<resource-ref>
<description>MSSQL Datasource example</description>
<res-ref-name>jdbc/MSSQL</res-ref-name>
<res-type>javax.sql.DataSource</res-type>
<res-auth>Container</res-auth>
</resource-ref>
</web-app>
CMD_EOF
}

function install_email_template(){
  mkdir ${JASPER_HOME}/email_tmpl
  mv /usr/libexec/webmin/jri_publisher/email_template.html "${JASPER_HOME}/email_tmpl/"
  chown -R tomcat:tomcat "${JASPER_HOME}/email_tmpl"
}

function setup_webapp_proxy(){
	dnf install -y httpd

	mkdir -p /etc/httpd/conf.d/includes/
	cat >/etc/httpd/conf.d/includes/tomcat.conf <<CMD_EOF
LoadModule proxy_module				modules/mod_proxy.so
LoadModule proxy_http_module	modules/mod_proxy_http.so
LoadModule rewrite_module			modules/mod_rewrite.so

ProxyRequests Off
ProxyPreserveHost On
<Proxy *>
	Order allow,deny
	Allow from all
</Proxy>
ProxyPass				 / http://localhost:8080/
ProxyPassReverse / http://localhost:8080/
CMD_EOF

}

function install_jri_module_deps(){
	dnf install -y haveged mutt zip postfix
	systemctl start haveged
}

touch /root/auth.txt

sed -i.save 's/enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-PowerTools.repo
dnf install -y wget epel-release wget unzip tar

TOMCAT_VER=$(wget -qO- --no-check-certificate https://tomcat.apache.org/download-90.cgi | grep '<a href="#9.' | cut -f2 -d'>' | cut -f1 -d'<' | head -n 1)
if [ -z "${TOMCAT_VER}" ]; then
	echo "Error: Failed to get tomcat version"; exit 1;
fi
CATALINA_HOME="/home/tomcat/apache-tomcat-${TOMCAT_VER}"

setup_webapp_proxy;
disable_selinux;
install_java;
install_tomcat_archive;
install_jri_war;  #needs to be here, since it takes time to deploy
install_webmin;
install_jri_module_deps;
install_jri_module;
#jri webapp must be deployed yet
install_jri_pg;
install_jri_mysql;
install_jri_mssql;

install_email_template;

echo "Passwords saved in /root/auth.txt"
cat /root/auth.txt
