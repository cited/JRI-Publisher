.. _wizard-label:

************
Wizard
************

Once the module is installed, the Wizard is used to configure the components.

Go to Servers > JRI Publisher:

.. image:: _static/3.png

The main Wizard screen will a link for completing each step.

While most steps are self-explanatory, we will cover Tomcat, JDK, and JRI selection below:

Install Java/JDK:
================

.. image:: _static/4-java.png

Select the JDK you wish to use.  We have tested with JDK 8

.. image:: _static/5-java.png

JRI Publihsher has been tested with OpenJDK 8 and Oracle JDK 8.


Apache Tomcat 
================

.. image:: _static/8-tomcat.png

JRI Publihsher has been tested with Apache Tomcat 8.x and 9.x:

.. image:: _static/9-tomcat.png


JasperReportsIntegration
========================

.. image:: _static/13-jri.png

JRI Publihsher has been tested with JasperReportsIntegration 2.5.1 and 2.6.2:

.. image:: _static/14-jri.png

.. note::
    If you wish to use a Beta version of JasperReporsIntegration, tick the "Show Beta Versions" select box 

JNDI Entries
========================

.. image:: _static/13-jri.png

JRI Publihsher allows you to add JNDI templates, and associated JARS for PostgreSQL, MySQL, and MSSQL

The JNDI entries are optional.

.. note::
    JNDI entries are created at /home/tomcat/tomcat-version/conf/context.xml
    
The JNDI elements added are shown below.  These defaults and must be edited with your own host, username, etc...

.. code-block:: xml
   :linenos:


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

    <Resource name="jdbc/MySQL" auth="Container" type="javax.sql.DataSource"
    maxTotal="100" maxIdle="30" maxWaitMillis="10000"
    driverClassName="com.mysql.jdbc.Driver"
    username="xxx" password="xxx"  url="jdbc:mysql://localhost:3306/xxx"/>
    
    <Resource name="jdbc/MSSQL" auth="Container" type="javax.sql.DataSource"
    maxTotal="100" maxIdle="30" maxWaitMillis="10000"
    driverClassName="com.microsoft.sqlserver.jdbc.SQLServerDriver"
    username="xxx" password="xxx"  url="jdbc:sqlserver://localhost:1433;databaseName=xxx"/>

    
Completing Installation
========================
 
Once each step of the Wizard is completed, the Wizard can be removed:

.. image:: _static/19-donei.png

With the Wizard completed, your module should appear as below:

.. image:: _static/start-jri.png



.. note::
    The JRI application is not deployed at this point.  You need to Start Tomcat
    in order to deploy it.  Do so before any further operations as it is required
    to write configuration files, etc...
    

About Haveged
===================

Haveged is an entropy generator that will provide markedly faster JVM startup times.
The caveat is that it will use much higher CPU load (although for shorter duration due
to decreased JVM start up time).  Bear this in mind if deploying on VM with limited CPU
or other critical applications.

