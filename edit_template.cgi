#!/usr/bin/perl

require './tomcat-lib.pl';
require './jru-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'template_title_edit'}, "", "templates", 0, 0);

# Work out and show the files
@files = get_email_template_files();
$in{'file'} ||= $files[0];
&indexof($in{'file'}, @files) >= 0 || &error($text{'manual_efile'});

print &ui_form_start("create_template.cgi", 'post');
print "<b>$text{'create_eml_tmpl'}</b>".&ui_textbox("new_filename", '', 20, 0).&ui_submit($text{'create_ok'});
print &ui_form_end();

print &ui_form_start("edit_template.cgi");
print "<b>$text{'manual_file'}</b>\n";
print &ui_select("file", $in{'file'}, [ map { [ $_ ] } @files ], 1, 0);
print &ui_submit($text{'manual_ok'});
print &ui_form_end();

# Show the file contents
print &ui_form_start("save_template.cgi", "form-data");
print &ui_hidden("file", $in{'file'}),"\n";
if($in{'tmpl_data'}){
  $data = $in{'tmpl_data'};
}else{
  $data = &read_file_contents($in{'file'});
}
print &ui_textarea("data", $data, 20, 80),"\n";
#print '<textarea id="data" name="data" onchange="update_preview()">'.$data.'</textarea>';
print &ui_form_end([ [ "save", $text{'save'}] ]);

print &ui_hr();
print '<a href="'.'/jri_publisher/preview_template.cgi?file='.&urlize($in{'file'}).'">Preview template</a>';

&ui_print_footer("", $text{'index_return'});
