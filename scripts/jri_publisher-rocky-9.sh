#!/bin/bash -e
#For use on clean Rocky Linux 9 only!!!
#Cited, Inc. Wilmington, Delaware
#Description: JRI Publisher Rocky Linux installer

# default menu options
WEBMIN_MODS='jri_publisher certbot'
TOMCAT_MAJOR=9
JAVA_FLAVOR='OpenJDK'

#Get hostname

HNAME=$(hostname | sed -n 1p | cut -f1 -d' ' | tr -d '\n')

#Set postgresql version and password (random)

PG_VER='15'
PG_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32);

BUILD_SSL='no'

#Create certificate for use by postgres

function make_cert_key(){
  name=$1

  SSL_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c32);
  if [ $(grep -m 1 -c "ssl ${name} pass" /root/auth.txt) -eq 0 ]; then
    echo "ssl ${name} pass: ${SSL_PASS}" >> /root/auth.txt
  else
    sed -i.save "s/ssl ${name} pass:.*/ssl ${name} pass: ${SSL_PASS}/" /root/auth.txt
  fi
  openssl genrsa -des3 -passout pass:${SSL_PASS} -out ${name}.key 2048
  openssl rsa -in ${name}.key -passin pass:${SSL_PASS} -out ${name}.key

  chmod 400 ${name}.key

  openssl req -new -key ${name}.key -days 3650 -out ${name}.crt -passin pass:${SSL_PASS} -x509 -subj "/C=CA/ST=Frankfurt/L=Frankfurt/O=${HNAME}/CN=${HNAME}/emailAddress=info@acugis.com"
}


function disable_pg_versions(){
	# disable other PG versions repos
	dnf config-manager --set-disabled pgdg*
	dnf config-manager --set-enabled pgdg${PG_VER} pgdg-common
}

#Install PostgreSQL
function install_postgresql(){
	#1. Install PostgreSQL repo
	PG_V2=$(echo ${PG_VER} | sed 's/\.//')
	if [ ! -f /etc/yum.repos.d/pgdg-redhat-all.repo ]; then
		rpm -ivh https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
	fi

	#2. Disable CentOS repo for PostgreSQL
	if [ $(grep -m 1 -c 'exclude=postgresql' /etc/yum.repos.d/CentOS-Base.repo) -eq 0 ]; then
		sed -i.save '/\[base\]/a\exclude=postgresql*' /etc/yum.repos.d/CentOS-Base.repo
		sed -i.save '/\[updates\]/a\exclude=postgresql*' /etc/yum.repos.d/CentOS-Base.repo
	fi

	#3. Install PostgreSQL
	# postgresql${PG_V2}-devel*
	dnf install -y postgresql${PG_V2} postgresql${PG_VER}-devel postgresql${PG_V2}-server postgresql${PG_V2}-libs postgresql${PG_V2}-contrib postgresql${PG_V2}-plperl postgresql${PG_V2}-plpython3 postgresql${PG_V2}-pltcl postgresql${PG_V2}-odbc

	export PGDATA='/var/lib/pgsql/${PG_VER}/data'
	export PATH="${PATH}:/usr/pgsql-${PG_VER}/bin/"
	if [ $(grep -m 1 -c '/usr/pgsql-${PG_VER}/bin/' /etc/environment) -eq 0 ]; then
		echo "PATH=${PATH}" >> /etc/environment
	fi

	if [ $(grep -m 1 -c 'PGDATA' /etc/environment) -eq 0 ]; then
		echo "PGDATA=${PGDATA}" >> /etc/environment
	fi

	if [ ! -f /var/lib/pgsql/${PG_VER}/data/pg_hba.conf ]; then
		sudo -u postgres /usr/pgsql-${PG_VER}/bin/initdb -D /var/lib/pgsql/${PG_VER}/data
	fi

	systemctl start postgresql-${PG_VER}

	#5. Set postgres Password
	if [ $(grep -m 1 -c 'pg pass' /root/auth.txt) -eq 0 ]; then
		sudo -u postgres psql 2>/dev/null -c "alter user postgres with password '${PG_PASS}'"
		echo "pg pass: ${PG_PASS}" > /root/auth.txt
	fi

	#6. Configure ph_hba.conf
	cat >/var/lib/pgsql/${PG_VER}/data/pg_hba.conf <<CMD_EOF
local	all all 							trust
host	all all 127.0.0.1	255.255.255.255	scram-sha-256
host	all all 0.0.0.0/0					scram-sha-256
host	all all ::1/128						scram-sha-256
hostssl all all 127.0.0.1	255.255.255.255	scram-sha-256
hostssl all all 0.0.0.0/0					scram-sha-256
hostssl all all ::1/128						scram-sha-256
CMD_EOF
	sed -i.save "s/.*listen_addresses.*/listen_addresses = '*'/" /var/lib/pgsql/${PG_VER}/data/postgresql.conf
	sed -i.save "s/.*ssl =.*/ssl = on/" /var/lib/pgsql/${PG_VER}/data/postgresql.conf

	#10. Create Symlinks for Backward Compatibility from PostgreSQL 9 to PostgreSQL 8
	ln -sf /usr/pgsql-${PG_VER}/bin/pg_config /usr/bin
	ln -sf /var/lib/pgsql/${PG_VER}/data /var/lib/pgsql
	ln -sf /var/lib/pgsql/${PG_VER}/backups /var/lib/pgsql

	#create SSL certificates
	if [ ! -f /var/lib/pgsql/${PG_VER}/data/server.key -o ! -f /var/lib/pgsql/${PG_VER}/data/server.crt ]; then
		make_cert_key 'server'
    chown postgres.postgres server.key server.crt
		mv server.key server.crt /var/lib/pgsql/${PG_VER}/data
	fi

	systemctl restart postgresql-${PG_VER}
	systemctl enable postgresql-${PG_VER}
	
	disable_pg_versions
}

function info_for_user()

{

#End message for user

echo -e "Installation is now completed."
echo -e "postgres and other passwords are saved in /root/auth.txt file"
	
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

function install_openlayers(){
  OL_VER=$(wget -q -L -O- https://github.com/openlayers/openlayers/releases/latest | grep '<title>Release' | sed 's/.*v\([0-9\.]\+\).*/\1/')
  wget --quiet -P/tmp "https://github.com/openlayers/openlayers/releases/download/v${OL_VER}/v${OL_VER}-package.zip"

	mkdir /var/www/html/OpenLayers
	pushd /var/www/html/OpenLayers
	  unzip -u /tmp/v${OL_VER}-package.zip
	popd
	rm -f /tmp/v${OL_VER}-package.zip

  chown -R apache:apache /var/www/html/OpenLayers
}

function install_leafletjs(){
  LL_VER=$(wget -q -O- 'https://leafletjs.com/download.html' | sed -n 's/.*\/leaflet\/v\([0-9\.]\+\)\/leaflet\.zip.*/\1/p' | sort -rn | head -1)

  wget --quiet -P/tmp "https://leafletjs-cdn.s3.amazonaws.com/content/leaflet/v${LL_VER}/leaflet.zip"

  unzip /tmp/leaflet.zip -d /var/www/html/leafletjs
  rm -f /tmp/leaflet.zip
  chown -R apache:apache /var/www/html/leafletjs
  
  dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm 
  dnf module enable php:remi-8.1 -y
  dnf install php-{common,gmp,fpm,curl,intl,pdo,mbstring,gd,xml,cli,zip,pgsql} -y
}

function install_postgis_pkgs(){
  dnf install -y postgis33_${PG_VER} postgis33_${PG_VER}-client pgrouting_${PG_VER}
	
	#osm2pg{sql,routing} are not available in Rocky Linux
	dnf install -y cmake make gcc-c++ boost-devel expat-devel zlib-devel \
  	bzip2-devel proj-devel lua-devel libpq-devel libpqxx-devel
}


function install_webmin(){
	wget -P/tmp 'https://download.webmin.com/developers-key.asc'
	rpm --import /tmp/developers-key.asc || true
	cp -f /tmp/developers-key.asc /etc/pki/rpm-gpg/RPM-GPG-KEY-webmin-developers

  cat >/etc/yum.repos.d/webmin.repo <<EOF
[Webmin]
name=Webmin Distribution Neutral
baseurl=https://download.webmin.com/download/newkey/yum
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-webmin-developers
EOF

  dnf --nogpgcheck install -y webmin tar rsync
	
	mkdir -p /etc/webmin/authentic-theme
	cp -r /var/www/html/portal/*  /etc/webmin/authentic-theme
}

function install_postgis_module(){

  pushd /opt/
		wget --quiet https://github.com/AcuGIS/PostGIS-Module/archive/master.zip
		unzip master.zip
		mv PostGIS-Module-master postgis
		rm -f postgis/setup.cgi
		tar -czf /opt/postgis.wbm.gz postgis
		rm -rf postgis master.zip

    /usr/libexec/webmin/install-module.pl postgis.wbm.gz
		rm -rf postgis.wbm.gz
  popd

}

function install_certbot_module(){

	dnf install -y python3-certbot-apache certbot mod_ssl
	
	systemctl restart httpd

  pushd /opt/
    wget --quiet https://github.com/cited/Certbot-Webmin-Module/archive/master.zip
    unzip master.zip
    mv Certbot-Webmin-Module-master certbot
    tar -czf /opt/certbot.wbm.gz certbot
    rm -rf certbot master.zip

    /usr/libexec/webmin/install-module.pl certbot.wbm.gz
		rm -rf certbot.wbm.gz
  popd
}

function install_jri_publisher_module(){

  pushd /opt/
		wget --quiet https://github.com/DavidGhedini/jri-publisher/archive/master.zip
		unzip master.zip
		mv jri-publisher-master jri_publisher
		tar -czf /opt/jri_publisher.wbm.gz jri_publisher
		rm -rf jri_publisher master.zip

		/usr/libexec/webmin/install-module.pl jri_publisher.wbm.gz
		rm -f jri_publisher.wbm.gz
  popd
}

function install_tomcat(){

	#dnf install -y haveged

	if [ ! -d /home/tomcat ]; then
		useradd -m tomcat
	fi
	cd /home/tomcat

	if [ ! -d apache-tomcat-${TOMCAT_VER} ]; then
		if [ ! -f /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz ]; then
			wget -P/tmp http://www.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz
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
		
	if [ $(sestatus | grep -cm1 enabled) -eq 1 ]; then
		find ${CATALINA_HOME}/bin/ -type f -name "*.sh" -exec  semanage fcontext --add --type initrc_exec_t {} \;
		restorecon -rv ${CATALINA_HOME}/bin
	fi

	systemctl daemon-reload
	systemctl enable tomcat
	systemctl start tomcat
}

function install_java(){
	dnf install -y java-11-openjdk-headless
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
  mv /usr/libexec/webmin/jri_publisher/email_template.html "${JASPER_HOME}/email_tmpl/"
  chown -R tomcat:tomcat "${JASPER_HOME}/email_tmpl"
}

function setup_webapp_proxy(){

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
	
	dnf module disable -y postgresql
	dnf config-manager --enable crb		# PowerTools
	dnf install -y epel-release
	dnf install -y wget unzip tar httpd bzip2 epel-release policycoreutils-python-utils haveged mutt zip postfix
	
	# Get Tomcat 9 latest version and set CATALINA_HOME
	TOMCAT_VER=$(wget -qO- --no-check-certificate https://tomcat.apache.org/download-${TOMCAT_MAJOR:0:1}0.cgi | grep "<a href=\"#${TOMCAT_MAJOR}." | cut -f2 -d'>' | cut -f1 -d'<' | head -n 1)
	if [ -z "${TOMCAT_VER}" ]; then
		echo "Error: Failed to get tomcat version"; exit 1;
	fi
	CATALINA_HOME="/home/tomcat/apache-tomcat-${TOMCAT_VER}"

	GEO_VER=$(wget http://geoserver.org/release/stable/ -O- 2>/dev/null | sed -n 's/^[ \t]\+<h1>GeoServer \(.*\)<\/h1>.*/\1/p')
	
	cat >/etc/httpd/conf.d/default.conf <<CAT_EOF
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/html
	ServerName ${HNAME}
</VirtualHost>
CAT_EOF
}

function setup_firewalld(){
  #apache and django app
  firewall-cmd --permanent --zone=public --add-port=80/tcp
	firewall-cmd --permanent --zone=public --add-port=443/tcp
  
	firewall-cmd --permanent --zone=public --add-port=8080/tcp
	firewall-cmd --permanent --zone=public --add-port=10000/tcp
	
  #crunchy services
  firewall-cmd --permanent --zone=public --add-port=7800/tcp
  firewall-cmd --permanent --zone=public --add-port=9000/tcp

	  systemctl reload firewalld
  sleep 10;
}

function setup_selinux(){
	
  #allow apache port for django app
  semanage port -a -t http_port_t -p tcp 7800
  semanage port -m -t http_port_t -p tcp 9000

  setsebool -P httpd_can_network_connect 1
}

function install_jri_script(){
	cp /usr/libexec/webmin/jri_publisher/gen_jri_report.sh /usr/local/bin
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
	'Installing Libraries....'
	'Installing LeafletJS Apps...'
	'Installing PostgreSQL Repository....'
	'Installing PostGIS Packages....'
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
	'install_openlayers'
	'install_leafletjs'
	'install_postgresql'
	'install_postgis_pkgs'	
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

# setup SELinux only if enabled
if [ $(sestatus | grep -cm1 enabled) -eq 1 ]; then
	STEPS+=("SELinux setup")
	CMDS+=("setup_selinux")
fi

# setup firewalld only if installed and enabled
if [ -f /usr/bin/firewall-cmd ] && [ $(firewall-cmd --state | grep -cm1 running) -eq 1 ]; then
	STEPS+=("Firewalld setup")
	CMDS+=("setup_firewalld")
fi

if [ ${BUILD_SSL} == 'yes' ]; then
	STEPS+=("Provisioning SSL")
	CMDS+=('provision_ssl')
fi

STEPS+=('Installing Email Template' 'Install JRI Script')
CMDS+=('install_email_template' 'install_jri_script')

# -------------------- #

whiptail_gauge;
info_for_user
