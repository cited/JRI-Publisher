# JRI Publisher

[![Documentation Status](https://readthedocs.org/projects/jri-publisher/badge/?version=latest)](https://jripub.davidghedini.com/en/latest/?badge=latest)

Webmin module for installing, configuring, and managing JasperReportsIntegration.

![JRI Publisher](docs/_static/JRI-Publisher-Main.png)


# About

JRI Publisher is a Webmin module that installs, configures, and manages Tomcat, Java, and JasperReportsIntegration

It also provides Publishing, Scheduling, Email Templates, and Report Management.

It can be used with Oracle (with or without Oracle APEX), PostgreSQL, MySQL, and Microsoft SQL Server.

# Docs

https://jripub.davidghedini.com

# Operating Systems
CentOS 7<br>
CentOS 8<br>
Ubuntu 18 LTS<br>
Ubuntu 20 LTS

# Simple Install (Ubuntu):

      wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/jri_unattended_ubuntu.sh
      chmod +x jri_unattended_ubuntu.sh
      ./jri_unattended_ubuntu.sh
      
# Simple Install (CentOS):

      wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/jri_unattended_centos.sh
      chmod +x jri_unattended_centos.sh
      ./jri_unattended_centos.sh

# Advanced Install:

      wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/pre-install.sh
      chmod +x pre-install.sh
      ./pre-install.sh


# Install via Git:

Archive module

	$ git clone https://github.com/DavidGhedini/jri-publisher
	$ mv jri-publisher-master jri_publisher
	$ tar -cvzf jri_publisher.wbm.gz jri_publisher/

Upload from Webmin->Webmin Configuration->Webmin Modules


# 2.7.0 Release Notes

* Added one-click JDNI support for PostgreSQL, MySQL, and MSSQL.
* Added Responsive HTML Email Templates for scheduled reports.
* Added Security tab to fix common security issues.
* Proxy is still configured during set up, but is no longer enabled by default.
* Support for Ubuntu 20 LTS
* Added contextual help links
* Added PHP Report Example

# Notes
## CentOS
May need to install x11 fonts when using OpenJDK

# Links
- [JasperReportsIntegration](https://github.com/daust/JasperReportsIntegration)
- [JasperReportsIntegration Forum](https://gitq.com/daust/JasperReportsIntegration)
