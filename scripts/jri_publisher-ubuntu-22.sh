#!/bin/bash -e
#For use on clean Ubuntu 22.04 only!!!
#Cited, Inc. Wilmington, Delaware
#Description: JRI Publisher Ubuntu installer

# default menu options
WEBMIN_MODS='jri_publisher certbot'
TOMCAT_MAJOR=9
JAVA_FLAVOR='OpenJDK'

#Get hostname

HNAME=$(hostname | sed -n 1p | cut -f1 -d' ' | tr -d '\n')

BUILD_SSL='no'

function info_for_user()

{

#End message for user

echo -e "Installation is now completed."
echo -e "postgres and info passwords are saved in /root/auth.txt file"
	
	if [ ${BUILD_SSL} == 'yes' ]; then
		if [ ! -f /etc/letsencrypt/live/${HNAME}/privkey.pem ]; then
			echo 'SSL Provisioning failed.  Please see jri_publisher.docs.acugis.com for troubleshooting tips.'
		else
			echo 'SSL Provisioning Success.'
		fi
	fi
}

function install_bootstrap_app(){
	wget --quiet -P/tmp https://github.com/DavidGhedini/jri-publisher/archive/refs/heads/master.zip
	unzip /tmp/master.zip -d/tmp

	cp -r /tmp/jri-publisher-master/app/* /var/www/html/
	cp -r /tmp/jri-publisher-master/app/portal /var/www/html/

	rm -rf /tmp/master.zip
	
	#update app
	find /var/www/html/ -type f -not -path "/var/www/html/latest/*" -name "*.html" -exec sed -i.save "s/MYLOCALHOST/${HNAME}/g" {} \;
}

function install_webmin(){
  echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
  wget --quiet -qO - http://www.webmin.com/jcameron-key.asc | apt-key add -
  apt-get -y update
  apt-get -y install webmin
	
	mkdir -p /etc/webmin/authentic-theme
	cp -r /var/www/html/portal/*  /etc/webmin/authentic-theme
}

function install_certbot_module(){

	apt-get -y install python3-certbot-apache

	a2enmod ssl
	a2ensite default-ssl

	systemctl restart apache2

  pushd /opt/
    wget --quiet https://github.com/cited/Certbot-Webmin-Module/archive/master.zip
    unzip master.zip
    mv Certbot-Webmin-Module-master certbot
    tar -czf /opt/certbot.wbm.gz certbot
    rm -rf certbot master.zip

    /usr/share/webmin/install-module.pl certbot.wbm.gz
	rm -rf certbot.wbm.gz
  popd
}

function install_jri_publisher_module(){

  pushd /opt/
    wget --quiet https://github.com/DavidGhedini/jri-publisher/archive/master.zip
    unzip master.zip
		mv jri-publisher-master jri_publisher
                rm -f jri_publisher/setup.cgi
		tar -czf /opt/jri_publisher.wbm.gz jri_publisher
		rm -rf jri_publisher master.zip

		/usr/share/webmin/install-module.pl jri_publisher.wbm.gz
		rm -f jri_publisher.wbm.gz
  popd
}

function install_tomcat(){

	apt-get -y install haveged

	if [ ! -d /home/tomcat ]; then
		useradd -m tomcat
	fi
	cd /home/tomcat

	if [ ! -d apache-tomcat-${TOMCAT_VER} ]; then
		if [ ! -f /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz ]; then
			wget -q -P/tmp "https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz"
		fi
		tar xzf /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz
		chown -R tomcat:tomcat apache-tomcat-${TOMCAT_VER}
		rm -rf /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz
	fi

	if [ $(grep -m 1 -c CATALINA_HOME /etc/environment) -eq 0 ]; then
		cat >>/etc/environment <<EOF
CATALINA_HOME=/home/tomcat/apache-tomcat-${TOMCAT_VER}
CATALINA_BASE=/home/tomcat/apache-tomcat-${TOMCAT_VER}
EOF
	fi

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

	cat >/home/tomcat/apache-tomcat-${TOMCAT_VER}/conf/tomcat-users.xml <<EOF
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
<role rolename="manager-gui" />
<user username="manager" password="${TOMCAT_MANAGER_PASS}" roles="manager-gui" />

<role rolename="admin-gui" />
<user username="admin" password="${TOMCAT_ADMIN_PASS}" roles="manager-gui,admin-gui" />
</tomcat-users>
EOF

	#folder is created after tomcat is started, but we need it now
	mkdir -p /home/tomcat/apache-tomcat-${TOMCAT_VER}/conf/Catalina/localhost/
	cat >/home/tomcat/apache-tomcat-${TOMCAT_VER}/conf/Catalina/localhost/manager.xml <<EOF
<Context privileged="true" antiResourceLocking="false" docBase="\${catalina.home}/webapps/manager">
	<Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*\$" />
</Context>
EOF

	chown -R tomcat:tomcat /home/tomcat

	cat >>"${CATALINA_HOME}/bin/setenv.sh" <<CMD_EOF
CATALINA_PID="${CATALINA_HOME}/temp/tomcat.pid"
JAVA_OPTS="\${JAVA_OPTS} -server -Djava.awt.headless=true -Dorg.geotools.shapefile.datetime=false -XX:+UseParallelGC -XX:ParallelGCThreads=4 -Dfile.encoding=UTF8 -Duser.timezone=UTC -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -DGEOSERVER_CSRF_DISABLED=true -DPRINT_BASE_URL=http://localhost:8080/geoserver/pdf -Dgwc.context.suffix=gwc"
CMD_EOF

cat >/etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Tomcat ${TOMCAT_VER}
After=multi-user.target

[Service]
User=tomcat
Group=tomcat

WorkingDirectory=${CATALINA_HOME}
Type=forking
Restart=always

EnvironmentFile=/etc/environment

ExecStart=$CATALINA_HOME/bin/startup.sh
ExecStop=$CATALINA_HOME/bin/shutdown.sh 60 -force

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
	
	systemctl enable tomcat
	systemctl start tomcat
}

function install_java(){
	if [ "${JAVA_FLAVOR}" == 'OpenJDK' ]; then
		apt-get -y install default-jdk-headless default-jre-headless
	else
		apt-get -y install default-jdk-headless default-jre-headless;
	fi
}

function install_jri_war(){

  JASPER_HOME="${CATALINA_HOME}/jasper_reports"
	mkdir -p "${JASPER_HOME}"

  JRI_LATEST=$(wget -O- https://github.com/daust/JasperReportsIntegration/tags | sed -n 's|.*/daust/JasperReportsIntegration/releases/tag/\(v[0-9\.]\+\).*|\1|p' | head -n 1)
	JRI_RELEASE=$(wget -O- https://github.com/daust/JasperReportsIntegration/releases/expanded_assets/${JRI_LATEST} | sed -n "s|.*\(/jri\-${JRI_LATEST:1}\-jasper\-[0-9\.\-]\+\.zip\).*|\1|p" | head -n 1)
	JRI_URL_PATH="https://github.com/daust/JasperReportsIntegration/releases/download/${JRI_LATEST}${JRI_RELEASE}"

  wget --no-check-certificate -P/tmp "${JRI_URL_PATH}"
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

function wait_deploy_jri_war(){
	while [ ! -f ${CATALINA_HOME}/webapps/JasperReportsIntegration/WEB-INF/web.xml ]; do
		sleep 1;
	done
}

function jri_add_datasource(){
	ds="${0}"
	ds_name="${1}"
	cat >> "${CATALINA_HOME}/jasper_reports/conf/application.properties" <<CAT_EOF
[datasource:${ds}]
type=jndi
name=${ds_name}
CAT_EOF
}

function install_jri_pg(){
  JRI_PG_VER=$(wget -O- https://jdbc.postgresql.org/download | sed -n 's/.*<a href="\/download\/postgresql\-\([0-9\.]\+\)\.jar.*/\1/p' | head -n 1)

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

	jri_add_datasource 'postgres' 'postgres'
}

function install_jri_mysql(){
  JRI_MYSQL_VER=$(wget -O- https://dev.mysql.com/downloads/connector/j/ | sed -n 's/.*<h1>Connector\/J\s*\([0-9\.]\+\).*/\1/p')

  wget --no-check-certificate -P/tmp "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${JRI_MYSQL_VER}.zip"
  pushd /tmp/
    unzip /tmp/mysql-connector-j-${JRI_MYSQL_VER}.zip
    mv mysql-connector-j-${JRI_MYSQL_VER}/mysql-connector-j-${JRI_MYSQL_VER}.jar ${CATALINA_HOME}/lib/
    rm -rf mysql-connector-j-${JRI_MYSQL_VER}/ /tmp/mysql-connector-j-${JRI_MYSQL_VER}.zip
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
	
	jri_add_datasource 'MySQL' 'MySQL'
}

function install_jri_mssql(){
  wget -O/tmp/mssql.html 'https://docs.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server?view=sql-server-ver15'

  JRI_MSSQL_URL=$(grep 'Download Microsoft JDBC Driver' /tmp/mssql.html | grep 'SQL Server (zip)' | grep 'linkid=' | cut -f2 -d'"')
  JRI_MSSQL_VER=$(grep -m 1 "${JRI_MSSQL_URL}" /tmp/mssql.html | sed -n 's/.*Download Microsoft JDBC Driver \([0-9\.]\+\) for SQL Server (zip).*/\1/p')
  wget -O/tmp/mssql.zip "${JRI_MSSQL_URL}"

  mkdir -p temp
  pushd temp
    unzip /tmp/mssql.zip
		JAR_FILE=$(find "sqljdbc_${JRI_MSSQL_VER}/enu/" -type f -name "mssql-jdbc-*.jar" | sort -V | tail -n 1)
    mv ${JAR_FILE} ${CATALINA_HOME}/lib/
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
	
	jri_add_datasource 'MSSQL' 'MSSQL'
}

function install_email_template(){
  mkdir ${JASPER_HOME}/email_tmpl
  mv /usr/share/webmin/jri_publisher/email_template.html "${JASPER_HOME}/email_tmpl/"
  chown -R tomcat:tomcat "${JASPER_HOME}/email_tmpl"
}

function setup_webapp_proxy(){

	cat >/etc/apache2/conf-available/tomcat.conf <<CMD_EOF
ProxyRequests Off
ProxyPreserveHost On
<Proxy *>
	Order allow,deny
	Allow from all
</Proxy>
ProxyPass				 / http://localhost:8080/
ProxyPassReverse / http://localhost:8080/
CMD_EOF
	a2enmod proxy proxy_http rewrite
}

function menu(){
	# disable error flag
	set +e
	
	SUITE_FLAVOR=$(whiptail --title "JRI Publisher Installer" --menu \
									"Select the JRI Publisher version you want to install:" 20 78 4 \
									"JRI Publisher Full Installation" " " 3>&1 1>&2 2>&3)
	
	exitstatus=$?
	if [ $exitstatus != 0 ]; then
		echo "JRI Publisher installation cancelled."
		exit 1
	fi
	
	# set options based on flavor we have
	case ${SUITE_FLAVOR} in
		"JRI Publisher Full Installation")
			;;
	esac

	whiptail --title "Hostname is $(hostname -f)" --yesno \
		--yes-button "Continue" --no-button "Quit" \
		"Be sure to set the hostname if you wish to use SSL" 8 78
	
	exitstatus=$?
	if [ $exitstatus != 0 ]; then
	    exit 0
	fi

	whiptail --title "JRI Publisher can provision SSL for ${HNAME}" --yesno \
		"Provision SSL for  ${HNAME}?" 8 78
	
	exitstatus=$?
	if [ $exitstatus == 0 ]; then
			BUILD_SSL='yes'
	fi
	
	# enable error flag
	set -e
	
	echo "Begining installation:"
	echo -e "\tSuite Version: ${SUITE_FLAVOR}"
	echo -e "\tControl Panel Modules: ${WEBMIN_MODS}"
	echo -e "\tTomcat Version: ${TOMCAT_MAJOR}"
	echo -e "\tJava Version: ${JAVA_FLAVOR}"
}

function install_deps(){
	touch /root/auth.txt

	export DEBIAN_FRONTEND=noninteractive
	apt-add-repository -y universe
	apt-get -y update
	apt-get -y install wget unzip tar apache2 bzip2 rename php libapache2-mod-php php-pgsql haveged mutt zip postfix
	
	# Get Tomcat latest version and set CATALINA_HOME
	TOMCAT_VER=$(wget -q -O- --no-check-certificate https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/ | sed -n "s|.*<a href=\"v\(${TOMCAT_MAJOR}\.[0-9.]\+\)/\">v.*|\1|p" | sort -V | tail -n 1)
	if [ -z "${TOMCAT_VER}" ]; then
		echo "Error: Failed to get tomcat version"; exit 1;
	fi
	CATALINA_HOME="/home/tomcat/apache-tomcat-${TOMCAT_VER}"

	GEO_VER=$(wget http://geoserver.org/release/stable/ -O- 2>/dev/null | sed -n 's/^[ \t]\+<h1>GeoServer \(.*\)<\/h1>.*/\1/p')
}

function install_jri_script(){
	cp /usr/share/webmin/jri_publisher/gen_jri_report.sh /usr/local/bin
	chown root:root /usr/local/bin/gen_jri_report.sh
	chmod +x /usr/local/bin/gen_jri_report.sh
}

function whiptail_gauge(){
  local MAX_STEPS=${#STEPS[@]}
	let STEP_PERC=100/MAX_STEPS
	local perc=0

  for step in "${!STEPS[@]}"; do
    echo "XXX"
		echo $perc
    echo "${STEPS[step]}\\n"
    echo "XXX"

    ${CMDS[$step]} 1>"/tmp/${CMDS[$step]}.log" 2>&1

    let perc=perc+STEP_PERC || true
  done | whiptail --gauge "Please wait while install completes..." 6 50 0
}

function provision_ssl(){
	/bin/bash /tmp/build-ssl.sh || true
}

################################################################################

menu;

declare -x STEPS=(
  'Checking Requirements...'
  'Installing Demo Data....'
	'Installing Webmin...'
	'Installing Java....'
	'Installing Apache Tomcat....'
	'Installing JRI WAR'
	'Deploying JRI WAR'
	'Installing JRI PG'
	'Installing JRI MySQL'
	'Installing JRI MSSQL'
	'Setting web proxy'
)
declare -x CMDS=(
	'install_deps'
	'install_bootstrap_app'
	'install_webmin'
	'install_java'
	'install_tomcat'
	'install_jri_war'
	'wait_deploy_jri_war'
	'install_jri_pg'
	'install_jri_mysql'
	'install_jri_mssql'
	'setup_webapp_proxy'
)

for mod in ${WEBMIN_MODS}; do
	mod=$(echo ${mod} | sed 's/"//g')
	STEPS+=("${mod} module")
	CMDS+=("install_${mod}_module")
done

if [ ${BUILD_SSL} == 'yes' ]; then
	STEPS+=("Provisioning SSL")
	CMDS+=('provision_ssl')
fi

STEPS+=('Installing Email Template' 'Install JRI Script')
CMDS+=('install_email_template' 'install_jri_script')

# -------------------- #

whiptail_gauge;
info_for_user
