#!/usr/bin/perl

require './tomcat-lib.pl';
require './jru-lib.pl';

&error_setup($text{'manual_err'});
&ReadParse();

# Work out the file
my $tmpl_dir = get_email_tmpl_dir();
my $tmpl_file = $tmpl_dir."/".$in{'new_filename'};
# Write to it

&copy_source_dest($module_root_directory."/email_template.html", $tmpl_dir."/".$in{'new_filename'})

&redirect("/jri_publisher/edit_template.cgi?file=".&urlize($tmpl_file));
