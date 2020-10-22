************
Installation
************

Installation can be done using the pre-installer.sh script or via GIT.

Using the Pre-Installer
=======================

On a fresh CentOS 8 or Ubuntu 18 or 20 installation, the fastest method is to use the pre-installer script:

.. code-block:: console
   :linenos:
   
    wget https://raw.githubusercontent.com/DavidGhedini/jri-publisher/master/scripts/pre-install.sh
    
    chmod +x pre-install.sh

    ./pre-install.sh
    
The above will install Webmin, Apache HTTPD Server, JRI Publisher module, as well as our (optional) Certbot Module for SSL.

When the script completes, you will see the message below:

.. code-block:: console
   :linenos:

    /opt ~
    Installed CertBot in /usr/share/webmin/certbot (336 kb)
    ~
    JRI Publisher is now installed. Go to Servers > JRI Publisher to complete installation


.. note::
    Following above, you will need to log in to Webmin to complete installation using the install :ref:`wizard-label`.



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

