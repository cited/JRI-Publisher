# Jasper Publisher

[![Documentation Status](https://readthedocs.org/projects/jri-publisher/badge/?version=latest)](https://jripub.davidghedini.com/en/latest/?badge=latest)

Webmin module for installing, configuring, and managing JasperReportsIntegration.



![JRI Publisher](docs/_static/JRI-Publisher-Landing.png)


![JRI Publisher](docs/_static/JRI-Publisher-Main.png)



# About

Jasper Publisher is a Webmin module that installs, configures, and manages Tomcat, Java, and JasperReportsIntegration

It also provides Publishing, Scheduling, Email Templates, and Report Management.

It can be used with Oracle (with or without Oracle APEX), PostgreSQL, MySQL, and Microsoft SQL Server.

# Docs

https://jripub.davidghedini.com

# Operating Systems

Ubuntu 22 LTS

Rocky Linux 9

# Run the Installer:

      wget https://raw.githubusercontent.com/cited/jri-publisher/master/scripts/jri_publisher-installer.sh
      chmod +x jri_publisher-installer.sh
      ./jri_publisher-installer.sh
      

# 2.10.1 Release Notes

* Updated for JaseperReportsIntegration latest releases
* Support for Ubuntu 22 LTS
* Fixed PostgreSQL JNDI error
* Fixed install script

# Notes
## Rocky Linux
May need to install x11 fonts when using OpenJDK

# Links
- [JasperReportsIntegration](https://github.com/daust/JasperReportsIntegration)
- [JasperReportsIntegration Forum](https://gitq.com/daust/JasperReportsIntegration)
