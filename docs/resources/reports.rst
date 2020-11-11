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
