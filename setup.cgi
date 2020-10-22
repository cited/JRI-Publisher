#!/usr/bin/perl

require './tomcat-lib.pl';
require 'java-lib.pl';
require 'jru-lib.pl';
require '../webmin/webmin-lib.pl';	#for OS detection
foreign_require('software', 'software-lib.pl');
foreign_require('apache', 'apache-lib.pl');

$www_user = 'www-data';

sub sort_version {
	my @A = split(/\./, $a);
	my @B = split(/\./, $b);
	# a sort subroutine, expect $a and $b
	for(my $i=0; $i < 3; $i++){
		if ($A[$i] < $B[$i]) { return -1 } elsif ($A[$i] > $B[$i]) { return 1 }
	}
	return 0;
}

sub sort_version_des {
	my @A = split(/\./, $a);
	my @B = split(/\./, $b);
	# a sort subroutine, expect $a and $b
	for(my $i=0; $i < 3; $i++){
		if ($A[$i] < $B[$i]) { return 1 } elsif ($A[$i] > $B[$i]) { return -1 }
	}
	return 0;
}

sub add_tomcat_user{
	#check if tomcat user exists
	if(read_file_contents('/etc/passwd') !~ /\ntomcat:/){
		#add tomcat user
		local $out = &backquote_command('useradd -m tomcat', 0);
	}elsif(! -d '/home/tomcat'){
		&make_dir("/home/tomcat", 0755, 1);
		&set_ownership_permissions('tomcat','tomcat', undef, '/home/tomcat');
	}
}

sub get_tomcat_major_versions(){
	my @majors = ('8', '7','6', '9');
	return @majors;
}

sub major_tomcat_versions{
	my $major = $_[0];	#Tomcat major version 6,7,8

	my $tmpfile = download_file("http://archive.apache.org/dist/tomcat/tomcat-$major/");
	if(! -f $tmpfile){
		error($error);
	}

	my @latest_versions;
	open(my $fh, '<', $tmpfile) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /<a\s+href="v($major\.[0-9\.]+)\/">v[0-9\.]+\/<\/a>/){
			push(@latest_versions, $1);
		}
	}
	close $fh;

	return sort sort_version @latest_versions;
}

sub download_and_install{
	my $tomcat_ver;
	my $major;

	#download tomcat archive
	if($in{'source'} == 100){
			$tomcat_ver = $in{'source_archive'};
			$major = substr($tomcat_ver, 0,1);
			$in{'url'} = "http://archive.apache.org/dist/tomcat/tomcat-$major/v$tomcat_ver/bin/apache-tomcat-$tomcat_ver.tar.gz";
			$in{'source'} = 2;
	}
	my $tmpfile = process_file_source();

	if($tmpfile =~ /.*apache-tomcat-([0-9\.]+).tar.gz$/i){
		$tomcat_ver = $1;
	}else{
		&error("Failed to match Tomcat version from archive");
	}
	$major = substr($tomcat_ver, 0,1);

	#extract tomcat archive
	print "<hr>Extracting to /home/tomcat/apache-tomcat-$tomcat_ver/ ...<br>";
	exec_cmd("tar -x --overwrite -f \"$tmpfile\" -C/home/tomcat/");
	print "Done<br>";


	#folder is created after tomcat is started, but we need it now
	&make_dir("/home/tomcat/apache-tomcat-$tomcat_ver/conf/Catalina/localhost/", 0755, 1);

	open(my $fh, '>', "/home/tomcat/apache-tomcat-$tomcat_ver/conf/Catalina/localhost/manager.xml") or die "open:$!";
	print $fh <<EOF;
<Context privileged="true" antiResourceLocking="false" docBase="\${catalina.home}/webapps/manager">
	<Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*\$" />
</Context>
EOF
	close $fh;

	#&set_ownership_permissions('tomcat','tomcat', undef, "/home/tomcat/apache-tomcat-$tomcat_ver/");
	&execute_command("chown -R tomcat:tomcat /home/tomcat/apache-tomcat-$tomcat_ver");

	return $tomcat_ver;
}

sub setup_catalina_env{
	my $tomcat_ver = $_[0];

	my %os_env;

	print "<hr>Setting CATALINA environment...";

	read_env_file('/etc/environment', \%os_env);
	$os_env{'CATALINA_HOME'} = "/home/tomcat/apache-tomcat-$tomcat_ver/";
	$os_env{'CATALINA_BASE'} = "/home/tomcat/apache-tomcat-$tomcat_ver/";
	write_env_file('/etc/environment', \%os_env, 0);

	open(my $fh, '>>', "/home/tomcat/apache-tomcat-$tomcat_ver/bin/setenv.sh") or die "open:$!";
	print $fh "CATALINA_PID=\"/home/tomcat/apache-tomcat-$tomcat_ver/temp/tomcat.pid\"";
	close $fh;
}

sub setup_tomcat_users{
	my $tomcat_ver = $_[0];
	my @pw_chars = ("A".."Z", "a".."z", "0".."9", "_", "-");
	my $manager_pass;
	my $admin_pass;

	$manager_pass .= $pw_chars[rand @pw_chars] for 1..32;
	$admin_pass   .= $pw_chars[rand @pw_chars] for 1..32;

	#Save tomcat-users.xml
	open(my $fh, '>', "/home/tomcat/apache-tomcat-$tomcat_ver/conf/tomcat-users.xml") or die "open:$!";
	print $fh <<EOF;
<?xml version='1.0' encoding='utf-8'?>
<tomcat-users>
<role rolename="manager-gui" />
<user username="manager" password="$manager_pass" roles="manager-gui" />

<role rolename="admin-gui" />
<user username="admin" password="$admin_pass" roles="manager-gui,admin-gui" />
</tomcat-users>
EOF
	close $fh;
	print "<hr>Setting Tomcat users...";
}

sub setup_tomcat_service{
	my $tomcat_ver = $_[0];
	copy_source_dest("$module_root_directory/tomcat.service", '/etc/init.d/tomcat');
	&set_ownership_permissions('root','root', 0555, "/etc/init.d/tomcat");
	print "<hr>Setting Tomcat service ...";
}

sub install_tomcat_from_archive{

	add_tomcat_user();
	my $tomcat_ver = download_and_install();

	setup_catalina_env($tomcat_ver);
	setup_tomcat_users($tomcat_ver);
	setup_tomcat_service($tomcat_ver);
}

sub get_apache_proxy_file(){
	my $proxy_file;

	if(	( $osinfo{'real_os_type'} =~ /centos/i) or	#CentOS
		($osinfo{'real_os_type'} =~ /fedora/i)	){	#Fedora
		if( ! -d '/etc/httpd/'){
			return 0;
		}
		$proxy_file = '/etc/httpd/conf.d/includes/tomcat.conf';

	}elsif( ($osinfo{'real_os_type'} =~ /ubuntu/i) or
			($osinfo{'real_os_type'} =~ /debian/i) 	){	#ubuntu or debian
		if( ! -d '/etc/apache2/'){
			return 0;
		}
		$proxy_file = '/etc/apache2/conf-available/tomcat.conf';
	}
	return $proxy_file;
}

sub setup_default_apache_proxy(){
	my $proxy_file = get_apache_proxy_file();

	if(-f $proxy_file){
		return 0;
	}

	open(my $fh, '>', $proxy_file) or die "open:$!";

	if(	($osinfo{'real_os_type'} =~ /centos/i) or	#CentOS
		($osinfo{'real_os_type'} =~ /fedora/i)	){	#Fedora

		&exec_cmd('setsebool httpd_can_network_connect 1');

		print $fh "LoadModule proxy_module 		modules/mod_proxy.so\n";
		print $fh "LoadModule proxy_http_module modules/mod_proxy_http.so\n";
		print $fh "LoadModule rewrite_module  	modules/mod_rewrite.so\n";

	}elsif( $osinfo{'os_type'} =~ /debian/i){	#ubuntu or debian

		print $fh "LoadModule proxy_module /usr/lib/apache2/modules/mod_proxy.so\n";
		print $fh "LoadModule proxy_http_module  /usr/lib/apache2/modules/mod_proxy_http.so\n";
		print $fh "LoadModule rewrite_module  /usr/lib/apache2/modules/mod_rewrite.so\n";
	}

	print $fh "ProxyRequests Off\n";
	print $fh "ProxyPreserveHost On\n";
	print $fh "    <Proxy *>\n";
	print $fh "       Order allow,deny\n";
	print $fh "       Allow from all\n";
	print $fh "    </Proxy>\n";
	print $fh "ProxyPass / http://localhost:8080/\n";
	print $fh "ProxyPassReverse / http://localhost:8080/\n";

	close $fh;

	print "Added proxy configuration / -> 8080 in $proxy_file\n";
}

sub select_jasper_version{
	print "$text{'jru_desc4'}<p>\n";

	print <<EOF;
	<script type="text/javascript">
	function update_versions(){
		var checkBox = document.getElementsByName("show_beta")[0];
		if (checkBox.checked == true){
			get_pjax_content('/jri_publisher/setup.cgi?mode=select_jasper_version&show_beta=1');
		}else{
			get_pjax_content('/jri_publisher/setup.cgi?mode=select_jasper_version');
		}
	}
	</script>
EOF

	print &ui_form_start("setup.cgi", "form-data");
	print ui_hidden('mode', 'install_jasper_reports');
	print &ui_table_start($text{'base_options'}, undef, 2);

	my $beta_enabled = 0;
	if($in{'show_beta'}){
		$beta_enabled = 1;
	}

	my %jr_vers = &get_jasper_reports_versions($beta_enabled);
	my @jr_opts = ( );
	foreach my $v (sort sort_version_des keys %jr_vers) {
		if($v =~ /([0-9\-\.a-z]+) BETA$/){
			push(@jr_opts, [ $jr_vers{$v}, $1 ]);	#drop BETA from version label
		}else{
			push(@jr_opts, [ $jr_vers{$v}, $v ]);
		}
	}

	print &ui_table_row($text{'jru_release'}, &ui_select("jr_ver", undef, \@jr_opts,1, 0).'</br>'.
																						&ui_checkbox("show_beta", 1, $text{'jru_show_beta'}, $beta_enabled, 'onclick="update_versions()"'));

	print &ui_table_end();
	print &ui_form_end([ [ "", $text{'base_installok'} ] ]);
}

sub select_tomcat_archive{
	print "$text{'base_desc1'}<p>\n";
	print &ui_form_start("setup.cgi", "form-data");
	print ui_hidden('mode', 'tomcat_install');
	print &ui_table_start($text{'base_options'}, undef, 2);

	my @tmver = sort sort_version_des &get_tomcat_major_versions();
	my $sel_tmver = $in{'tmver'} || $tmver[0];
	my @tm_opts = ( );
	foreach my $v (@tmver) {
		push(@tm_opts, [ $v, $v ]);
	}

	print <<EOF;
	<script type="text/javascript">
	function update_select(){
		var majorSel = document.getElementById('base_major');
		var major = majorSel.options[majorSel.selectedIndex].value;

		get_pjax_content('/jri_publisher/setup.cgi?mode=tomcat_install_form&tmver='+major);
	}
	</script>
EOF

	print &ui_table_row($text{'base_major'},
		&ui_select("base_major", $sel_tmver, \@tm_opts, 1, 0, undef, undef, 'id="base_major" onchange="update_select()"'));

	my @tver = sort sort_version_des &major_tomcat_versions($sel_tmver);
	my @tver_opts = ( );
	foreach my $v (@tver) {
		push(@tver_opts, [ $v, $v ]);
	}

	print &ui_table_row($text{'base_installsource'},
		&ui_radio_table("source", 100,
			[ [ 100, $text{'source_archive'},  &ui_select("source_archive", undef, \@tver_opts,1, 0)],
			  [ 0, $text{'source_local'}, &ui_textbox("file", undef, 40)." ". &file_chooser_button("file", 0) ],
			  [ 1, $text{'source_uploaded'}, &ui_upload("upload", 40) ],
			  [ 2, $text{'source_ftp'},&ui_textbox("url", undef, 40) ]
		    ]));

	print &ui_table_end();
	print &ui_form_end([ [ "", $text{'base_installok'} ] ]);
}

sub parse_jr_versions{
	my $base_url = $_[0];
	my %latest_versions;
	my $tmpfile = download_file($base_url);
	if(! $tmpfile){
		return %latest_versions;
	}

	open(my $fh, '<', $tmpfile) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /<a\s+href="([0-9\.]+(\-beta)?)\/">[0-9\.]+(\-beta)?\/<\/a>/){
			$latest_versions{$1} = $1.'@download';
		}
	}
	close $fh;
	return %latest_versions;
}

sub parse_jr_gh_versions{
	my $base_url = $_[0];
	my %latest_versions;
	my $tmpfile = download_file($base_url);
	if(! $tmpfile){
		return %latest_versions;
	}

	open(my $fh, '<', $tmpfile) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /<a\s+href="(\/daust\/JasperReportsIntegration\/releases\/download\/v([0-9\.]+)\/[^\-]*\-[0-9\.\-]+\.zip)/){
			$latest_versions{$2} = $2.'@'.$1;
		}
	}
	close $fh;
	return %latest_versions;
}

sub get_jasper_reports_versions(){
	my $beta_enabled = $_[0];
	my %jr_versions = parse_jr_versions('http://www.opal-consulting.de/downloads/free_tools/JasperReportsIntegration/');
	my %gh_versions = parse_jr_gh_versions('https://github.com/daust/JasperReportsIntegration/releases');

	foreach my $v (keys %gh_versions){
		$jr_versions{$v} = $gh_versions{$v};
	}

	if($beta_enabled){
		my %beta_versions = parse_jr_versions('http://www.opal-consulting.de/downloads/free_tools/JasperReportsIntegration/Beta-releases/');
		foreach my $v (keys %beta_versions){
			$jr_versions{$v." BETA"} = $beta_versions{$v};
		}
	}
	return %jr_versions;
}

sub get_jasper_archive_url{
	my $jr_ver = $_[0];
	my $beta_release = $_[1];
	my $jr_site = $_[2];

	#if our version is from github
	if($jr_site =~ /\/daust\/JasperReportsIntegration\//){
		return 'https://github.com'.$jr_site;
	}

	my $zip_ver = "${jr_ver}.0";
	my $base_url = 'http://www.opal-consulting.de/downloads/free_tools/JasperReportsIntegration';

	if($beta_release){
		$base_url .= '/Beta-releases';
	}

	my $tmpfile = download_file($base_url.'/'.${jr_ver}.'/');
	if(! $tmpfile){
		return "${base_url}/${jr_ver}/JasperReportsIntegration-${zip_ver}.zip";
	}

	open(my $fh, '<', $tmpfile) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /<a\s+href="JasperReportsIntegration-([0-9\.]+)\.zip/){
			$zip_ver = $1;
			last;
		}
	}
	close $fh;

	return "${base_url}/${jr_ver}/JasperReportsIntegration-${zip_ver}.zip";
}

#set the oc.jasper.config.home manually
sub update_oc_jasper_config_home(){
	my $webxml = get_catalina_home().'/webapps/JasperReportsIntegration/WEB-INF/web.xml';

	if(! -f $webxml){
		print "Error: $webxml not found. Update oc.jasper.config.home manually\n";
		return;
	}

	my $lref = &read_file_lines($webxml);
	my $lnum = 0;

	foreach my $line (@$lref) {
		if($line =~ /^[ \t]+<param\-name>oc\.jasper\.config\.home</){
			@{$lref}[$lnum+1] = '<param-value>'.get_catalina_home().'/jasper_reports</param-value>';
			last;
		}
		$lnum++;
	}
	flush_file_lines($webxml);
}

sub install_jasper_reports(){
	#get Jasper version
	my @jr_ver_site = split(/@/, $in{'jr_ver'});
	my $jr_ver = $jr_ver_site[0];
	my $jr_site = $jr_ver_site[1];

	my $catalina_home = get_catalina_home();
	my $jasper_home = $catalina_home.'/jasper_reports';

	my $beta_release = 0;
	if($jr_ver =~ /([0-9\-\.a-z]+) BETA$/){
		$jr_ver = $1;
		$beta_release = 1;
	}

	print "<p>Installing Jasper Reports $jr_ver</p>";

	my $jr_archive_url = get_jasper_archive_url($jr_ver, $beta_release, $jr_site);
	my $tmpfile = download_file($jr_archive_url);
	my $unzip_dir = unzip_me($tmpfile);

	#github releases are in a subfolder
	my $subdir = substr(file_basename($tmpfile), 0, -4);	#take filename, and drop .zip
	if(-d $unzip_dir.'/'.$subdir){
		$unzip_dir = $unzip_dir.'/'.$subdir;
	}

	my $war_name = 'JasperReportsIntegration.war';
	if( -f $unzip_dir.'/webapp/JasperReportsIntegration.war'){	#before v.2.6.1
		 $war_name = 'JasperReportsIntegration.war';
	}elsif(-f $unzip_dir.'/webapp/jri.war'){	# from v.2.6.1
		$war_name = 'jri.war';
	}else{
		die("Error: No war file found");
	}

	print "Installing $war_name</br>";

	&rename_file($unzip_dir.'/webapp/'.$war_name, $catalina_home.'/webapps/JasperReportsIntegration.war');

	#make the jasper home
	&make_dir($jasper_home, 0750, 0);
	&rename_file($unzip_dir.'/conf', $jasper_home.'/conf');
	&rename_file($unzip_dir.'/reports', $jasper_home.'/reports');
	&rename_file($unzip_dir.'/logs', $jasper_home.'/logs');
	&make_dir($jasper_home.'/schedules', 0750, 0);

	#TODO: Configure your database access
	print '<b>Warning</b>: Skipping configuration of conf/application.properties</br>';

	#set configuration directory
	print 'shell: setConfigDir.sh</br>';
	$tmpfile = &transname('script.sh');
	open(my $fh, '>', $tmpfile) or die "open:$!";
	print $fh "cd $unzip_dir/bin\n";
	print $fh "chmod +x encryptPasswords.sh\n";
	#print $fh "sh ./encryptPasswords.sh ${$jasper_home}/conf/application.properties\n";
	if(-f $unzip_dir.'/bin/setConfigDir.sh'){
		print $fh "chmod +x setConfigDir.sh\n";
		print $fh "sh ./setConfigDir.sh $catalina_home/webapps/JasperReportsIntegration.war $jasper_home\n";
	}
	print $fh "chown -R tomcat:tomcat ${jasper_home}\n";
	close $fh;
	exec_cmd('bash '.$tmpfile);

	print "Adding OC_JASPER_CONFIG_HOME to Tomcat setenv.sh</br>";
	open(my $fh, '>>', $catalina_home.'/bin/setenv.sh') or die "open:$!";
	print $fh "\nOC_JASPER_CONFIG_HOME=\"${jasper_home}\"";
	close $fh;

	tomcat_service_ctl('restart');

	print "Done</br>";
}

sub install_gen_jri_report(){
	&copy_source_dest($module_root_directory.'/gen_jri_report.sh', '/usr/local/bin');
	&set_ownership_permissions('root', 'root', 0755, '/usr/local/bin/gen_jri_report.sh');
	print 'Installed in /usr/local/bin/gen_jri_report.sh';
}

sub check_jdbc_pg_exists(){
	my $catalina_home = get_catalina_home();
  opendir(DIR, $catalina_home.'/lib') or die $!;
  my @jars
        = grep { /^postgresql\-[0-9\.]+\.jar$/       # pg jar
      			&& -f "$catalina_home/lib/$_"  # and is a file
	} readdir(DIR);
  closedir(DIR);

	if(@jars){
  	return $catalina_home.'/lib/'.$jars[0];
	}else{
		return $catalina_home.'/lib/';
	}
}

sub check_jdbc_mysql_exists(){
	my $catalina_home = get_catalina_home();
  opendir(DIR, $catalina_home.'/lib') or die $!;
  my @jars
        = grep { /^mysql-connector-java\-[0-9\.]+\.jar$/       # pg jar
      			&& -f "$catalina_home/lib/$_"  # and is a file
	} readdir(DIR);
  closedir(DIR);

	if(@jars){
  	return $catalina_home.'/lib/'.$jars[0];
	}else{
		return $catalina_home.'/lib/';
	}
}

sub check_jdbc_mssql_exists(){
	my $catalina_home = get_catalina_home();
  opendir(DIR, $catalina_home.'/lib') or die $!;
  my @jars
        = grep { /^mssql-jdbc\-[0-9\.]+\.jre[0-9]+\.jar$/   # mssql jar
      			&& -f "$catalina_home/lib/$_"  									# and is a file
	} readdir(DIR);
  closedir(DIR);

	if(@jars){
  	return $catalina_home.'/lib/'.$jars[0];
	}else{
		return $catalina_home.'/lib/';
	}
}

sub jri_add_datasource{
	my $ds = $_[0];
	my $ds_name = $_[1];
	open(my $fh, '>>', get_catalina_home().'/jasper_reports/conf/application.properties') or die "open:$!";
	print $fh "[datasource:$ds]\n";
	print $fh "type=jndi\n";
	print $fh "name=$ds_name\n";
	close $fh
}

sub ctx_xml_add{
	my $ref_str = $_[0];

	my $ctxxml = get_catalina_home().'/conf/context.xml';
	my $lref = &read_file_lines($ctxxml);
	my $lnum = 0;

	foreach my $line (@$lref) {
		if($line =~ /^<\/Context>/){
			@{$lref}[$lnum] = $ref_str."\n$line";
			last;
		}
		$lnum++;
	}
	flush_file_lines($ctxxml);
	&set_ownership_permissions('tomcat','tomcat', undef, $ctxxml);
}

sub web_xml_add{
	my $ref_str = $_[0];
	my $webxml = get_catalina_home().'/webapps/JasperReportsIntegration/WEB-INF/web.xml';

	my $lref = &read_file_lines($webxml);
	my $lnum = 0;

	foreach my $line (@$lref) {
		if($line =~ /^<\/web-app>/){
			@{$lref}[$lnum] = $ref_str."\n$line";
			last;
		}
		$lnum++;
	}
	flush_file_lines($webxml);
	&set_ownership_permissions('tomcat','tomcat', undef, $webxml);
}

sub install_jri_pg(){
	#download JDBC versions page
	my $tmpfile = download_file('https://jdbc.postgresql.org/download.html');
	if(!$tmpfile){
		die('Error: Failed to get JDBC PG page');
	}

	#find latest
	$jdbc_pg_ver = '';
	open(my $fh, '<', $tmpfile) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /<a\s+href="download\/postgresql\-([0-9\.]+)\.jar/){
			$jdbc_pg_ver = $1;
			last;
		}
	}
	close $fh;

	print "Downloading JDBC PG ver. ".$jdbc_pg_ver."</br>";
	$tmpfile = download_file('https://jdbc.postgresql.org/download/postgresql-'.$jdbc_pg_ver.'.jar');
	if(!$tmpfile){
		die('Error: Failed to get JDBC PG jar');
	}

	my $jar_filepath = get_catalina_home().'/lib/'.file_basename($tmpfile);
	&rename_file($tmpfile, $jar_filepath);
	print "Moving jar to ".$jar_filepath."</br>";

	my $ref_str = '<Resource name="jdbc/postgres" auth="Container" type="javax.sql.DataSource"'."\n";
  $ref_str .= 'driverClassName="org.postgresql.Driver"'."\n";
  $ref_str .= 'maxTotal="20" initialSize="0" minIdle="0" maxIdle="8"'."\n";
  $ref_str .= 'maxWaitMillis="10000" timeBetweenEvictionRunsMillis="30000"'."\n";
	$ref_str .= 'minEvictableIdleTimeMillis="60000" testWhileIdle="true"'."\n";
	$ref_str .= 'validationQuery="select user" maxAge="600000"'."\n";
	$ref_str .= 'rollbackOnReturn="true"'."\n";
	$ref_str .= 'url="jdbc:postgresql://localhost:5432/xxx"'."\n";
	$ref_str .= 'username="xxx"'."\n";
	$ref_str .= 'password="xxx"'."\n";
	$ref_str .= '/>'."\n";
	ctx_xml_add($ref_str);

	my $ref_str = "<resource-ref>\n";
	$ref_str .= "<description>postgreSQL Datasource example</description>\n";
	$ref_str .= "<res-ref-name>jdbc/postgres</res-ref-name>\n";
	$ref_str .= "<res-type>javax.sql.DataSource</res-type>\n";
	$ref_str .= "<res-auth>Container</res-auth>\n";
	$ref_str .= "</resource-ref>";
	web_xml_add($ref_str);

	jri_add_datasource('postgres', 'postgres');

	print "Done</br>";
}

sub install_jri_mysql(){
	#download JDBC versions page
	my $tmpfile = download_file('https://dev.mysql.com/downloads/connector/j/');
	if(!$tmpfile){
		die('Error: Failed to get JDBC MySQL page');
	}

	#find latest
	$jdbc_mysql_ver = '';
	open(my $fh, '<', $tmpfile) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /<h1>Connector\/J[ \t]+([0-9\.]+)[ \t]/){
			$jdbc_mysql_ver = $1;
			last;
		}
	}
	close $fh;

	if(!$jdbc_mysql_ver){
		die('Error: Failed to parse JDBC MySQL version');
	}

	print "Downloading JDBC MySQL ver. ".$jdbc_mysql_ver."</br>";
	$tmpfile = download_file('https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-'.$jdbc_mysql_ver.'.zip');
	if(!$tmpfile){
		die('Error: Failed to get JDBC MySQL zip');
	}

	my $unzip_dir = unzip_me($tmpfile);

	my $jar_filepath = get_catalina_home().'/lib/mysql-connector-java-'.$jdbc_mysql_ver.'.jar';
	&rename_file($unzip_dir.'/mysql-connector-java-'.$jdbc_mysql_ver.'/mysql-connector-java-'.$jdbc_mysql_ver.'.jar', $jar_filepath);
	print "Moving jar to ".$jar_filepath."</br>";

	my $ref_str = '<Resource name="jdbc/MySQL" auth="Container" type="javax.sql.DataSource"'."\n";
	$ref_str .= 'maxTotal="100" maxIdle="30" maxWaitMillis="10000"'."\n";
	$ref_str .= 'driverClassName="com.mysql.jdbc.Driver"'."\n";
	$ref_str .= 'username="xxx" password="xxx"  url="jdbc:mysql://localhost:3306/xxx"/>'."\n";
	ctx_xml_add($ref_str);

	$ref_str = "<resource-ref>\n";
	$ref_str .= "<description>MySQL Datasource example</description>\n";
	$ref_str .= "<res-ref-name>jdbc/MySQL</res-ref-name>\n";
	$ref_str .= "<res-type>javax.sql.DataSource</res-type>\n";
	$ref_str .= "<res-auth>Container</res-auth>\n";
	$ref_str .= "</resource-ref>";

	web_xml_add($ref_str);

	jri_add_datasource('MySQL', 'MySQL');

	print "Done</br>";
}

sub install_jri_mssql(){
	#download JDBC versions page
	my $tmpfile = download_file('https://docs.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server?view=sql-server-ver15');
	if(!$tmpfile){
		die('Error: Failed to get JDBC MySQL page');
	}

	#find latest
	$jdbc_mssql_ver = '';
	$jdbc_mssql_url = 'https://go.microsoft.com/fwlink/?linkid=2137600';
	open(my $fh, '<', $tmpfile) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /Download Microsoft JDBC Driver ([0-9\.]+)/){
			$jdbc_mssql_ver = $1;

			if($line =~ /"(https:\/\/go\.microsoft\.com\/fwlink\/?linkid=[0-9]+)"/){
				$jdbc_mssql_url = $1;
				last;
			}
		}
	}
	close $fh;

	if(!$jdbc_mssql_url){
		die('Error: Failed to parse JDBC MySQL version');
	}

	print "Downloading JDBC MySQL ver. ".$jdbc_mssql_ver."</br>";
	$tmpfile = download_file($jdbc_mssql_url);
	if(!$tmpfile){
		die('Error: Failed to get JDBC MySQL zip');
	}

	my $unzip_dir = unzip_me($tmpfile);

	#find which java we have
	my %jv = get_java_version();
	my $jdk_major = $jv{'major'};

	my $sqljdbc_dir = $unzip_dir.'/sqljdbc_'.$jdbc_mssql_ver.'\\enu/';
  opendir(DIR, $sqljdbc_dir) or die $!;
  my @jars = grep { /^mssql\-jdbc\-[0-9\.]+\.jre$jdk_major\.jar/ && -f "$sqljdbc_dir/$_" } readdir(DIR);
  closedir(DIR);

	if(!@jars){
		die('Error: Failed to get JDBC MySQL jar for JDK '.$jv{'major'});
	}

	my $jar_filepath = get_catalina_home().'/lib/'.$jars[0];
	&rename_file($sqljdbc_dir.'/'.$jars[0], $jar_filepath);
	print "Moving jar to ".$jar_filepath."</br>";

	my $ref_str = '<Resource name="jdbc/MSSQL" auth="Container" type="javax.sql.DataSource"'."\n";
	$ref_str .= 'maxTotal="100" maxIdle="30" maxWaitMillis="10000"'."\n";
	$ref_str .= 'driverClassName="com.microsoft.sqlserver.jdbc.SQLServerDriver"'."\n";
	$ref_str .= 'username="xxx" password="xxx"  url="jdbc:sqlserver://localhost:1433;databaseName=xxx"/>'."\n";
	ctx_xml_add($ref_str);

	$ref_str = "<resource-ref>\n";
	$ref_str .= "<description>MSSQL Datasource example</description>\n";
	$ref_str .= "<res-ref-name>jdbc/MSSQL</res-ref-name>\n";
	$ref_str .= "<res-type>javax.sql.DataSource</res-type>\n";
	$ref_str .= "<res-auth>Container</res-auth>\n";
	$ref_str .= "</resource-ref>";

	web_xml_add($ref_str);

	jri_add_datasource('MSSQL', 'MSSQL');

	print "Done</br>";
}

sub install_email_template(){
	my $tmp_dir = get_email_tmpl_dir();
	if(! -d $tmp_dir){
		&make_dir($tmp_dir, 0755, 1);
		&set_ownership_permissions('tomcat','tomcat', undef, $tmp_dir);
	}

	&rename_file($module_root_directory.'/email_template.html', $tmp_dir.'/email_template.html');
	print "Done</br>";
}

sub install_html_app(){
	my $app_dir = $module_root_directory.'/app';
	&unlink_file('/var/www/html');
	&rename_file($app_dir, '/var/www/html');
	&exec_cmd("chown -R $www_user:$www_user /var/www/html");

	opendir(DIR, $app_dir.'/portal') or die $!;
	my @portal_files = grep { -f "$app_dir/portal/$_" } readdir(DIR);
	closedir(DIR);

	if (! -d '/etc/webmin/authentic-theme/'){
		&make_dir('/etc/webmin/authentic-theme/', 0755, 1);
	}

	foreach my $f (@portal_files){
		&copy_source_dest($app_dir.'/portal/'.$f, '/etc/webmin/authentic-theme/'.$f);
	}

	my $hname = get_system_hostname();

	my $ln=0;
	my $html_file = '/var/www/html/index.html';
	$lref = &read_file_lines($html_file);
	foreach my $line (@$lref){
		chomp($line);
		if($line =~ /xyzIP/){
			$line = s/xyzIP/$hname/g;
			@{$lref}[$ln] = $line;
		}
		$ln++;
	}
	flush_file_lines($html_file);
}

sub setup_checks{

	#Check for commands
	if (!&has_command('java')) {
		print '<p>Warning: Java is not found. Install it manually or from the '.
			  "<a href='./edit_java.cgi?return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>Java tab</a></p>";
	}

	my @pinfo = software::package_info('haveged', undef, );
	if(!@pinfo){

		if( $osinfo{'real_os_type'} =~ /centos/i){	#CentOS
			@pinfo = software::package_info('epel-release', undef, );
			if(!@pinfo){
				print "<p>Warning: haveged needs epel-release. Install it manually or ".
						"<a href='../package-updates/update.cgi?mode=new&source=3&u=epel-release&redir=%2E%2E%2Fjri_publisher%2Fsetup.cgi&redirdesc=Setup'>click here</a> to have it downloaded and installed.</p>";
			}
		}
		print "<p>Warning: haveged package is not installed. Install it manually or ".
			  "<a href='../package-updates/update.cgi?mode=new&source=3&u=haveged&redir=%2E%2E%2Fjri_publisher%2Fsetup.cgi&redirdesc=Setup'>click here</a> to have it downloaded and installed.</p>";
	}

	my $tomcat_ver = installed_tomcat_version();
	if(!$tomcat_ver){
		print "<p>Apache Tomcat is not found. <a href='setup.cgi?mode=tomcat_install_form&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>Click here</a> to install Tomcat from Apache site.</p>";
	}

	my @pkg_deps;

	if(	( $osinfo{'real_os_type'} =~ /centos/i) or	#CentOS
			($osinfo{'real_os_type'} =~ /fedora/i)	){	#Fedora
		@pkg_deps = ('httpd', 'unzip', 'wget', 'mutt', 'zip');

	}elsif( ($osinfo{'real_os_type'} =~ /ubuntu/i) or
					($osinfo{'real_os_type'} =~ /debian/i) 	){	#ubuntu or debian
		@pkg_deps = ('apache2', 'unzip', 'wget', 'mutt', 'zip');
	}

	my @pkg_missing;
	foreach my $pkg (@pkg_deps){
		my @pinfo = software::package_info($pkg);
		if(!@pinfo){
			push(@pkg_missing, $pkg);
		}
	}

	if(@pkg_missing){
		my $url_pkg_list = '';
		foreach my $pkg (@pkg_missing){
			$url_pkg_list .= '&u='.&urlize($pkg);
		}
		my $pkg_list = join(', ', @pkg_missing);

		print "<p>Warning: Missing package dependencies - $pkg_list - are not installed. Install them manually or ".
				"<a href='../package-updates/update.cgi?mode=new&source=3${url_pkg_list}&redir=%2E%2E%2Fjri_publisher%2Fsetup.cgi&redirdesc=Setup'>click here</a> to have them installed.</p>";
	}

	my $proxy_file = get_apache_proxy_file();
	if(! -f $proxy_file){
		print "<p>Apache default proxy is not configured. ".
			  "<a href='./setup.cgi?mode=setup_apache_proxy&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
	}

	if($tomcat_ver){
		my $catalina_home = get_catalina_home();
		if(! -f $catalina_home.'/webapps/JasperReportsIntegration.war'){
			print "<p>JasperReportsIntegration is not installed. To select version and install, ".
					"<a href='./setup.cgi?mode=select_jasper_version&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
		}

		if(! -f check_jdbc_pg_exists()){
			print "<p>JRI PG support is not installed. To install it ".
					"<a href='./setup.cgi?mode=install_jri_pg&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
		}

		if(! -f check_jdbc_mysql_exists()){
			print "<p>JRI MySQL support is not installed. To install it ".
					"<a href='./setup.cgi?mode=install_jri_mysql&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
		}

		if(! -f check_jdbc_mssql_exists()){
			print "<p>JRI MSSQL support is not installed. To install it ".
					"<a href='./setup.cgi?mode=install_jri_mssql&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
		}
	}

	if(! -f '/usr/local/bin/gen_jri_report.sh'){
		print "<p>JRI report script is not installed. To install it ".
				"<a href='./setup.cgi?mode=install_gen_jri_report&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
	}

	if(! -d get_email_tmpl_dir()){
		print "<p>JRI email template is not installed. To install it ".
				"<a href='./setup.cgi?mode=install_email_template&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
	}

	if( -d $module_root_directory.'/app'){
		print "<p>HTML App is not installed. To install it ".
				"<a href='./setup.cgi?mode=install_html_app&return=%2E%2E%2Fjri_publisher%2Fsetup.cgi&returndesc=Setup&caller=jri_publisher'>click here</a></p>";
	}

	print '<p>If you don\'t see any warning above, you can complete setup from '.
		  "<a href='setup.cgi?mode=cleanup&return=%2E%2E%2Fjri_publisher%2F&returndesc=Setup&caller=jri_publisher'>here</a></p>";
}

#Remove all setup files
sub setup_cleanup{
	my $file = $module_root_directory.'/setup.cgi';
	print "Completing Installation</br>";
	&unlink_file($file);

	my @mods = ('proxy', 'proxy_http');
	foreach my $mod (@mods){
			my $err = &apache::add_configured_apache_module($mod);
			#if($err){
			#	print "Warning:Apache:$mod:$err</br>";
			#}
	}
	&apache::restart_apache();

	update_oc_jasper_config_home();

	print &js_redirect("index.cgi");
}


&ui_print_header(undef, $text{'setup_title'}, "");

if($ENV{'CONTENT_TYPE'} =~ /boundary=(.*)$/) {
	&ReadParseMime();
}else {
	&ReadParse(); $no_upload = 1;
}

%osinfo = &detect_operating_system();

if(	( $osinfo{'real_os_type'} =~ /centos/i) or	#CentOS
		($osinfo{'real_os_type'} =~ /fedora/i)	or  #Fedora
		($osinfo{'real_os_type'} =~ /scientific/i)	){
	$www_user = 'apache';
}

my $mode = $in{'mode'} || "checks";

if($mode eq "checks"){							setup_checks();
	&ui_print_footer('', $text{'index_return'});
	exit 0;
}elsif($mode eq "cleanup"){						setup_cleanup();
	&ui_print_footer('', $text{'index_return'});
	exit 0;
}elsif($mode eq "tomcat_install_form"){			select_tomcat_archive();
}elsif($mode eq "select_jasper_version"){			select_jasper_version();
}elsif($mode eq "tomcat_install"){				install_tomcat_from_archive();
}elsif($mode eq "setup_apache_proxy"){			setup_default_apache_proxy();
}elsif($mode eq "install_jasper_reports"){	install_jasper_reports();
}elsif($mode eq "install_gen_jri_report"){	install_gen_jri_report();
}elsif($mode eq "install_jri_pg"){		install_jri_pg();
}elsif($mode eq "install_jri_mysql"){	install_jri_mysql();
}elsif($mode eq "install_jri_mssql"){	install_jri_mssql();
}elsif($mode eq "install_email_template"){	install_email_template();
	}elsif($mode eq "install_html_app"){	install_html_app();
}else{
	print "Error: Invalid setup mode\n";
}

&ui_print_footer('setup.cgi', $text{'setup_title'});
