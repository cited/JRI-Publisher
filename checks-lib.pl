require 'jru-lib.pl';

sub check_firewall() {

  if(has_command('firewall-cmd')){
    return 1;
  }
  return 0;
}

sub check_info_page_is_enabled(){
  my %prop_env;
	read_env_file(get_prop_file(), \%prop_env);
  if($prop_env{'infoPageIsEnabled'} eq 'true'){
    return 1;
  }
  return 0;
}

sub check_ip_addresses_allowed_is_enabled(){
  my %prop_env;
	read_env_file(get_prop_file(), \%prop_env);
  if($prop_env{'ipAddressesAllowed'} || $prop_env{'ipAddressListAllowed'}){
    return 0;
  }
  return 1;
}

sub check_reports_demo(){
  if(-d get_jasper_home().'/reports/demo'){
    return 1;
  }
  return 0;
}

sub check_prop_passwords(){
  my $lref = &read_file_lines(get_prop_file(), 1);
	my $lnum = 0;

  foreach my $line (@$lref){
    chomp($line);

    #all encrypted passwords start with 1:
		if($line =~ /^password=(?!1:)/){
			return 1;
		}
		$lnum++;
	}
  return 0;
}

sub print_fix_form{
  my ($msg, $mode)  = @_;
  print &ui_form_start("checks.cgi", "post");
  print &ui_hidden('mode', $mode);
  print &ui_form_end([ [ "", $text{'check_fix_now'}, '&nbsp;'.$msg ] ]);
}
