#!/usr/bin/perl

require './tomcat-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'jru_publish'}, "", "publish", 0, 0);

# Show tabs
@tabs = ( [ "upload", $text{'publish_tabupload'}, "edit_publish.cgi?mode=upload" ]);

print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "upload", 1);

# Display installation form
print &ui_tabs_start_tab("mode", "upload");
print "$text{'publish_desc1'}<p>\n";

print &ui_form_start("publish_upload.cgi", "form-data");
print &ui_table_start($text{'publish_upload'}, undef, 2);

my $upload_path = get_catalina_home().'/jasper_reports/reports';

print &ui_table_row($text{'publish_destination'},
  &ui_textbox("destination", '/', 40)." ".
  &file_chooser_button("destination", 1, 0, $upload_path, 1));

print &ui_table_row($text{'publish_source'},
	&ui_radio_table("source", 0,
		[ [ 0, $text{'source_local'}, &ui_textbox("file", undef, 40)." ". &file_chooser_button("file", 0) ],
		  [ 1, $text{'source_uploaded'}, &ui_upload("upload", 40) ],
		  [ 2, $text{'source_ftp'},&ui_textbox("url", undef, 40) ]
	  ]).
  &ui_checkbox("publish_extract", 1, '<i>'.$text{'publish_extract'}."</i>", 0).'</br>'.
  &ui_checkbox("publish_overwrite", 1, '<i>'.$text{'publish_overwrite'}."</i>", 0)
  );

print &ui_table_end();
print &ui_form_end([ [ "", $text{'publish_ok'} ] ]);
print &ui_tabs_end_tab();

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});
