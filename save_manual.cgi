#!/usr/bin/perl
# Update a manually edited config file

require './tomcat-lib.pl';
require './jru-lib.pl';
&error_setup($text{'manual_err'});
&ReadParseMime();

my $catalina_home = get_catalina_home();

# Work out the file
@files = (	"$catalina_home/bin/setenv.sh",
			"$catalina_home/conf/context.xml",
			"$catalina_home/conf/server.xml",
			"$catalina_home/conf/tomcat-users.xml",
			"$catalina_home/conf/web.xml",
			"$catalina_home/jasper_reports/conf/application.properties",
			"$catalina_home/webapps/JasperReportsIntegration/WEB-INF/web.xml");

if($in{'file'}){
	push(@files, $in{'file'});
}
push(@files, get_email_template_files());

#&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});
$in{'data'} =~ s/\r//g;
$in{'data'} =~ /\S/ || &error($text{'manual_edata'});

# Write to it
&open_lock_tempfile(DATA, ">$in{'file'}");
&print_tempfile(DATA, $in{'data'});
&close_tempfile(DATA);

&webmin_log("manual", undef, $in{'file'});
&redirect("");
