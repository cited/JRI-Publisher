# !/bin/bash -e
# JRI Pre-Install Script for CentOS and Ubuntu
# For use on clean CentOS or Ubuntu box only
# Usage:
# wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/pre-install.sh
# chmod +x pre-installer
# ./pre-installer.sh

HNAME=$(hostname | sed -n 1p | cut -f1 -d' ' | tr -d '\n')

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

function download_jri_publisher_module(){
pushd /tmp/
	wget https://github.com/DavidGhedini/jri-publisher/archive/master.zip
	unzip master.zip
	mv jri-publisher-master jri_publisher
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
		chown -R www-data:www-data /var/www/html/
	elif [ "${REPO}" == 'rpm' ]; then
		chown -R apache:apache /var/www/html/
	fi
	
	HOST_IP=$(hostname -I | cut -f1 -d' ')
	sed -i.save "s/xyzIP/${HNAME}/g" /var/www/html/index.html
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
install_webmin;
install_apache;
download_jri_publisher_module;
download_certbot_module;
install_certbot_module;
install_jri_publisher_module;
install_app;