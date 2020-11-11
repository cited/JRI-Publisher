.. This is a comment. Note how any initial comments are moved by
   transforms to after the document title, subtitle, and docinfo.

.. demo.rst from: http://docutils.sourceforge.net/docs/user/rst/demo.txt

.. |EXAMPLE| image:: static/yi_jing_01_chien.jpg
   :width: 1em

**********************
Calling Reports
**********************

.. contents:: Table of Contents

Calling Reports
========================

The information below is a quick start guide to calling reports from non-APEX environments.

Cautions
==============

It is important that the following be observed::
   
   Access to the JRI installation via 8080 must be limited to the web server.
   
   Do not disply the report URL in any way
   
   
   
Example
==========

Below is a basic example of calling Jasper reports via a drop-down using PHP.

The drop-down contains the _reportName parameter, which is passed to the PHP code.  

The code then parses the _reportName parameter to create the url.

.. code-block:: bash
   :linenos:



	<?php


if (isset($_GET['report_name'])) {

    $data = array(
        "_repName"=> $_GET['report_name'],
        "_repFormat"=>"pdf",
        "_dataSource"=>"DAVIDDS",
        "_outFilename"=>"report.pdf"      
    );
   
    $file = 'http://161.35.78.233:8080/JasperReportsIntegration/report?' . http_build_query($data);
     
    header("Pragma: public");
    header("Expires: 0");
    header("Content-Type: application/octet-stream");
    header("Cache-Control: must-revalidate, post-check=0, pre-check=0");
    header("Cache-Control: public");
    header("Content-Description: File Transfer");
    header('Content-Disposition: attachment; filename="'. $data['_outFilename'] . '"');
    header("Content-Transfer-Encoding: binary\n");

    readfile($file);
    exit();
}
?>

<!DOCTYPE html>
<html>
    <body>
        Report Form
        <br>
        <form action="" method="get">
            <select name="report_name">
                <option value="uks">Student Reports</option>
                <option value="dcs">Teacher Reports</option>
                <option value="uks">Class Reports</option>
                <option value="uks">Grade Reports</option>
            </select>
            <button type="submit">Submit</button>
        </form>
       

    </body>
</html>


Blocking Port
================

Be certain that access to port 8080/8443 is open only to the web server.







