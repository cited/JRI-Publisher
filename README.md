# Jasper Publisher

[![Documentation Status](https://readthedocs.org/projects/jri-publisher/badge/?version=latest)](https://jripub.davidghedini.com/en/latest/?badge=latest)

Webmin module for installing, configuring, and managing JasperReportsIntegration.

![JRI Publisher](docs/_static/JRI-Publisher-Main.png)


# About

Jasper Publisher is a Webmin module that installs, configures, and manages Tomcat, Java, and JasperReportsIntegration

It also provides Publishing, Scheduling, Email Templates, and Report Management.

It can be used with Oracle (with or without Oracle APEX), PostgreSQL, MySQL, and Microsoft SQL Server.

# Docs

https://jripub.davidghedini.com

# Operating Systems
CentOS 7<br>
Ubuntu 20 LTS
Ubuntu 22 LTS

# Install via Script:

      wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/pre-install.sh
      chmod +x pre-install.sh
      ./pre-install.sh
      
Go to Servers > JRI Publisher to complete installation using the wizard

# Install via Git:

Archive module

	$ git clone https://github.com/DavidGhedini/jri-publisher
	$ mv jri-publisher-master jri_publisher
	$ tar -cvzf jri_publisher.wbm.gz jri_publisher/

Upload from Webmin->Webmin Configuration->Webmin Modules

Go to Servers > JRI Publisher to complete installation using the wizard


# 2.7.1 Release Notes

* Added one-click JDNI support for PostgreSQL, MySQL, and MSSQL.
* Added Responsive HTML Email Templates for scheduled reports.
* Added Security tab to fix common security issues.
* Proxy is still configured during set up, but is no longer enabled by default.
* Support for Ubuntu 20 LTS
* Added contextual help links
* Added PHP Report Example
* Updated url links to accomodate new version (08-12-2020)

# Notes
## CentOS
May need to install x11 fonts when using OpenJDK

# Links
- [JasperReportsIntegration](https://github.com/daust/JasperReportsIntegration)
- [JasperReportsIntegration Forum](https://gitq.com/daust/JasperReportsIntegration)
