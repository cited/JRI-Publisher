# !/bin/bash -e
# JRI Pre-Install Script for CentOS and Ubuntu
# For use on clean CentOS or Ubuntu box only
# Usage:
# wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/pre-install.sh
# chmod +x pre-installer
# ./pre-installer.sh

function get_repo(){
	if [ -f /etc/centos-release ]; then
		REPO='rpm'
 
	elif [ -f /etc/debian_version ]; then
		REPO='apt'
fi
}

function install_webmin(){

	if [ "${REPO}" == 'apt' ]; then

	echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
	wget -qO - http://www.webmin.com/jcameron-key.asc | apt-key add -
	apt-get -y update
	apt-get -y install webmin

	elif [ "${REPO}" == 'rpm' ]; then

cat >/etc/yum.repos.d/webmin.repo <<EOF
		[Webmin]
		name=Webmin Distribution Neutral
		baseurl=http://download.webmin.com/download/yum
		enabled=1
		gpgcheck=1
		gpgkey=http://www.webmin.com/jcameron-key.asc
EOF
		yum -y install webmin

	fi
}

function install_java(){
        if [ "${REPO}" == 'apt' ]; then
		apt-get -y install openjdk-8-jdk openjdk-8-jre-headless
	elif [ "${REPO}" == 'rpm' ]; then
		dnf install -y java-1.8.0-openjdk-headless java-1.8.0-openjdk-devel
	fi
    
	
}


function install_tomcat_archive(){

	if [ ! -d /home/tomcat ]; then
		useradd -m tomcat
	fi
	cd /home/tomcat

	if [ ! -d apache-tomcat-${TOMCAT_VER} ]; then
		if [ ! -f /tmp/apache-tomcat-${TOMCAT_VER}.tar.gz ]; then
			wget --no-check-certificate -P/tmp http://www.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz
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

function download_jri_publisher_module(){
pushd /tmp/
	wget https://github.com/DavidGhedini/jasper-publisher/archive/master.zip
	unzip master.zip
	mv jasper-publisher-master jri_publisher
	tar -czf /opt/jri_publisher.wbm.gz jri_publisher
	rm -rf jri_publisher master.zip
popd
  
}

function install_app(){

        if [ "${REPO}" == 'apt' ]; then
		cp -r /usr/share/webmin/jri_publisher/app/* /var/www/html
	elif [ "${REPO}" == 'rpm' ]; then
		cp -r /usr/libexec/webmin/jri_publisher/app/* /var/www/html
	fi
	
	if [ "${REPO}" == 'apt' ]; then
		chown -R apache:apache /var/www/html/
	elif [ "${REPO}" == 'rpm' ]; then
		chown -R www-data:www-data /var/www/html/
	fi
	
	HOST_IP=$(hostname -I | cut -f1 -d' ')
	sed -i.save "s/xyzIP/${HOST_IP}/g" /var/www/html/index.html
	rm -f /var/www/html/index.html.save
	
	if [ "${REPO}" == 'apt' ]; then
		chown -R www-data:www-data /var/www/html/
	elif [ "${REPO}" == 'rpm' ]; then
		chown -R apache:apache /var/www/html/
	fi
	
	if [ "${REPO}" == 'apt' ]; then
		mkdir -p /etc/webmin/authentic-theme
		cp -r /usr/share/webmin/jri_publisher/app/portal/*  /etc/webmin/authentic-theme
	elif [ "${REPO}" == 'rpm' ]; then
		mkdir -p /etc/webmin/authentic-theme
		cp -r /usr/libexec/webmin/jri_publisher/app/portal/*  /etc/webmin/authentic-theme
	fi
        echo -e "JRI Publisher is now installed. Go to Servers > JRI Publisher to complete installation"
}

function download_certbot_module(){
pushd /tmp/
	wget https://github.com/cited/Certbot-Webmin-Module/archive/master.zip
	unzip master.zip
	mv Certbot-Webmin-Module-master certbot
	tar -czf /opt/certbot.wbm.gz certbot
	rm -rf certbot master.zip
popd
}

function install_apache(){
	if [ "${REPO}" == 'apt' ]; then
		apt-get -y install apache2
	elif [ "${REPO}" == 'rpm' ]; then
		yum -y install httpd
	fi
}

function install_jri_publisher_module(){
pushd /opt/
        if [ "${REPO}" == 'apt' ]; then
       	/usr/share/webmin/install-module.pl jri_publisher.wbm.gz
        elif [ "${REPO}" == 'rpm' ]; then
        /usr/libexec/webmin/install-module.pl jri_publisher.wbm.gz
        fi
popd
        echo -e "JRI Publisher is now installed. Go to Servers > JRI Publisher to complete installation"
	
}

function install_certbot_module(){
pushd /opt/
	if [ "${REPO}" == 'apt' ]; then
	/usr/share/webmin/install-module.pl certbot.wbm.gz
        elif [ "${REPO}" == 'rpm' ]; then
        /usr/share/webmin/install-module.pl certbot.wbm.gz
        fi
popd
        echo -e "Certbot is now installed. Go to Servers > Certbot to complete installation"
	
}

function get_deps(){
if [ "${REPO}" == 'apt' ]; then
		apt-get -y install wget unzip
	elif [ "${REPO}" == 'rpm' ]; then
		yum -y install wget unzip bzip2
    fi
}

function install_apache(){
	if [ "${REPO}" == 'apt' ]; then
		apt-get -y install apache2
	elif [ "${REPO}" == 'rpm' ]; then
		yum -y install httpd
	fi
}

get_repo;
get_deps;
install_java;
install_tomcat_archive;
install_webmin;
install_apache;
download_jri_publisher_module;
download_certbot_module;
install_certbot_module;
install_jri_publisher_module;
install_app;
