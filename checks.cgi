
require 'checks-lib.pl';
require 'jru-lib.pl';

require '../webmin/webmin-lib.pl';	#for OS detection
foreign_require('software', 'software-lib.pl');

sub install_firewalld {
  software::update_system_install("firewalld", undef);

  #allow webmin
  exec_cmd('firewall-cmd --permanent --zone=public --add-port=10000/tcp');

  exec_cmd('firewall-cmd --permanent --zone=public --add-port=80/tcp');
  exec_cmd('firewall-cmd --permanent --zone=public --add-port=443/tcp');

  exec_cmd('firewall-cmd --permanent --zone=public --add-port=8080/tcp');

  exec_cmd('systemctl restart firewalld');
  exec_cmd('firewall-cmd --list-all');
}

sub disable_info_page_is_enabled(){
  my $prop_file = get_prop_file();

  my $ln=0;
  my $lref = &read_file_lines($prop_file);
  foreach my $line (@$lref){
    if($line =~ /infoPageIsEnabled=true/){
      @{$lref}[$ln] = "infoPageIsEnabled=false";
      print "Disabled infoPageIsEnabled in application.properties</br>";
      last;
    }
    $ln=$ln+1;
  }
  flush_file_lines($prop_file);
  print "infoPageIsEnabled disabled</br>";
}

sub remove_demodir(){
  my $demo_dir = get_jasper_home().'/reports/demo';

  &unlink_file($demo_dir);
  print $demo_dir.' removed</br>';
}

sub encrypt_prop_passwords(){
  #/home/tomcat/apache-tomcat-9.0.6/webapps/JasperReportsIntegration/WEB-INF/classes# java -cp ".:../lib/*" main/CommandLine encryptPasswords ../../../../jasper_reports/conf/application.properties
  my $web_inf = get_catalina_home().'/webapps/JasperReportsIntegration/WEB-INF';
  my $cmd = "cd $web_inf/classes; java -cp '.:../lib/*' main/CommandLine encryptPasswords ".get_jasper_home()."/conf/application.properties";
  exec_cmd($cmd);

  print "Password encrypted</br>";
}

sub enter_allowed_ips(){

  print &ui_form_start("checks.cgi");
  print ui_hidden('mode', 'update_allowed_ips');
  print "$text{'checks_enter_ips_desc'}: 127.0.0.1,10.10.10.10,192.168.178.31</br>";


  print $text{'checks_ip_list'}.&ui_textbox("ip_list", '', 40);

  print &ui_submit('save');
  print &ui_form_end();
}

sub update_allowed_ips(){
  my $prop_file = get_prop_file();

  #validate the input
  my @ips = split(/,/, $in{'ip_list'});
  foreach my $ip (@ips){
    if( (check_ipaddress($ip) == 1) ||
        (check_ip6address($ip) == 0)){
      next;
    }else{
      print "IP $ip is invalid</br>";
      return;
    }
  }

  my $ln=0;
  my $lref = &read_file_lines($prop_file);
  foreach my $line (@$lref){
    if($line =~ /(?:# )ipAddressListAllowed=/){
      @{$lref}[$ln] = "ipAddressListAllowed=".$in{'ip_list'};
      last;
    }
    $ln=$ln+1;
  }
  flush_file_lines($prop_file);
  print "ipAddressListAllowed updated to ".$in{'ip_list'}."</br>";
}

&ui_print_header(undef, $text{'checks_title'}, "");

if($ENV{'CONTENT_TYPE'} =~ /boundary=(.*)$/) {
	&ReadParseMime();
}else {
	&ReadParse(); $no_upload = 1;
}

%osinfo = &detect_operating_system();

my $mode = $in{'mode'} || "checks";

if($mode eq "install_firewalld"){       install_firewalld();
}elsif($mode eq "disable_infopage"){    disable_info_page_is_enabled();
}elsif($mode eq "remove_demodir"){      remove_demodir();
}elsif($mode eq "enc_prop_pwd"){        encrypt_prop_passwords();
}elsif($mode eq "enter_allowed_ips"){   enter_allowed_ips();
}elsif($mode eq "update_allowed_ips"){  update_allowed_ips();
}else{
	print "Error: Invalid checks mode\n";
}

&ui_print_footer("/", $text{"index_title"});
