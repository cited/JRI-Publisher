# JRI Publisher

[![Documentation Status](https://readthedocs.org/projects/jri-publisher/badge/?version=latest)](https://jripub.davidghedini.com/en/latest/?badge=latest)

Webmin module for installing, configuring, and managing JasperReportsIntegration.

![JRI Publisher](docs/_static/JRI-Publisher-Main.png)


# About

JRI Publisher is a Webmin module that installs, configures, and manages Tomcat, Java, and JasperReportsIntegration

It also provides Publishing, Scheduling, and Report Management.

It can be used with or without Oracle APEX.

# Docs

https://jripub.davidghedini.com

# Operating Systems
CentOS 7<br>
CentOS 8<br>
Ubuntu 16 LTS<br>
Ubuntu 18 LTS

# Install via Script:

      wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/pre-install.sh
      chmod +x pre-install.sh
      ./pre-install.sh


# Install via Git:

Archive module

	$ git clone https://github.com/DavidGhedini/jri-publisher
	$ mv jri-publisher-master jri_publisher
	$ tar -cvzf jri_publisher.wbm.gz jri_publisher/

Upload from Webmin->Webmin Configuration->Webmin Modules

# Notes
## CentOS
May need to install x11 fonts when using OpenJDK

# Links
- [JasperReportsIntegration](http://www.opal-consulting.de/downloads/free_tools/JasperReportsIntegration/2.4.0/Index.html)
- [JasperReportsIntegration Forum](https://gitq.com/daust/JasperReportsIntegration)
