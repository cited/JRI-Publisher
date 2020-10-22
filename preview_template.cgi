#!/usr/bin/perl

require './tomcat-lib.pl';
require './jru-lib.pl';
&error_setup($text{'manual_err'});
&ReadParse();

# Work out the file
@files = get_email_template_files();
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

&ui_print_header(undef, $text{'template_title_edit'}, "");
$data = &read_file_contents($in{'file'});
print $data;
&ui_print_footer("/jri_publisher/edit_template.cgi?file=".&urlize($in{'file'}), $text{'index_return_tmpl'});
