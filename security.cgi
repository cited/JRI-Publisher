#!/usr/bin/perl
# index.cgi

require './tomcat-lib.pl';
require '../webmin/webmin-lib.pl';	#for OS detection
require './checks-lib.pl';

# Check if config file exists
if (! -r $config{'jri_publisher_config'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print &text('index_econfig', "<tt>$config{'jri_publisher_config'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
}

if(-f "$module_root_directory/setup.cgi"){
	&redirect("setup.cgi?mode=checks");
	exit;
}

my %version = get_catalina_version();

&ui_print_header(undef, $text{'security_title'}, "", "security", 0, 0);


&icons_table(\@links, \@titles, \@icons, 4);

print ui_buttons_end();

if($config{'jri_checks'}){
	my $anounce_msg = '<p>&nbsp;&nbsp;The following security issues were detected:</p>';
	my $prop_mtime = (stat(get_prop_file()))[9];
	my %last_check;
	read_file_cached($module_config_directory.'/checks_cache', \%last_check);

	my $num_fixes = 0;
	if(check_firewall() == 0){
		print &ui_hr().$anounce_msg if($num_fixes++ == 0);
		print_fix_form('&nbsp;&nbsp;&nbsp;Firewalld is not installed  ', 'install_firewalld');
	}

	if($last_check{'application.properties'} < $prop_mtime){
		if(check_info_page_is_enabled() == 1){
			print &ui_hr().$anounce_msg if($num_fixes++ == 0);
			print_fix_form('&nbsp;&nbsp;&nbsp;<b>infoPageIsEnabled</b> is set to True', 'disable_infopage');
		}

		if(check_reports_demo() == 1){
			print &ui_hr().$anounce_msg if($num_fixes++ == 0);
			print_fix_form('&nbsp;&nbsp;&nbsp;Demo directory exists', 'remove_demodir');
		}

		if(check_prop_passwords() == 1){
			print &ui_hr().$anounce_msg if($num_fixes++ == 0);
			print_fix_form('&nbsp;&nbsp;&nbsp;Unencrypted passwords detected', 'enc_prop_pwd');
		}

		if(check_ip_addresses_allowed_is_enabled() == 1){
			print &ui_hr().$anounce_msg if($num_fixes++ == 0);
			print_fix_form('&nbsp;&nbsp;&nbsp;ipAddressesAllowed is not enabled', 'enter_allowed_ips');
		}

		if($num_fixes == 0){
			$last_check{'application.properties'} = time();
			&write_file($module_config_directory.'/checks_cache', \%last_check);
		}
	}

	if($num_fixes > 0){
		print "Total of $num_fixes issues found</br>";
	}
}

&ui_print_footer("/", $text{"index"});
