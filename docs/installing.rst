************
Installation
************

Installation can be done using the pre-installer.sh script or via GIT.

Using the Installer
=======================

1. Issue below to launch the Installer


            wget https://raw.githubusercontent.com/cited/jri-publisher/master/scripts/jri_publisher-installer.sh && chmod +x jri_publisher-installer.sh && ./jri_publisher-installer.sh


2. Follow the prompts to install

.. image:: _static/JRI-Installer.png

3. Upon completetion, below will be displayed::

        Version: JRI Publisher Full Installation
        Control Panel Modules: jri_publisher certbot
        Tomcat Version: 9
        Java Version: OpenJDK
            Installation is now completed.
            SSL Provisioning Success.


4. Click the Login link on the home page to log in.

.. image:: _static/JRI-Publisher-Main.png


Via Git or Download
===================

You can use Git to build module for an existing Webmin installation:

.. code-block:: console
   :linenos:

    git clone https://github.com/DavidGhedini/jri-publisher
    mv jri-publisher-master jri_publisher
    tar -cvzf jri_publisher.wbm.gz jri_publisher/

    
.. note::
    Following above, you will need to log in to Webmin to complete installation using the install :ref:`wizard-label`.
    
    
Postfix
===================

In order to use the email functionality for Report Scheduling, a working MTA is required.

If one is not already installed, the simplest to install is Postfix.

Postfix can be installed on Webmin.

Navigate to Servers > Unused Modules > Postfix Mail Server

Accept the defaults and click "Install Now" as shown below.

.. image:: _static/Postfix-install.png

