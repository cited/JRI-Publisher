#!/usr/bin/perl

require './jru-lib.pl';
use File::Basename;
use File::Path 'rmtree';

sub inst_error{
	print "<b>$main::whatfailed : $_[0]</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
}

if($ENV{'CONTENT_TYPE'} =~ /boundary=(.*)$/) { &ReadParseMime(); }
else { &ReadParse(); $no_upload = 1; }

$| = 1;
$theme_no_table = 1 if ($in{'source'} == 2 || $in{'source'} == 4);
&ui_print_header(undef, $text{'install_title'}, "");

my $upload_path = get_jasper_home().'/reports';
my $dest_dir = $upload_path.'/'.$in{'destination'};

#check if upload dir has .. in path
if($dest_dir =~ /\.\./){
	print "Error: Invalid upload dir $dest_dir</br>";
	&ui_print_footer("", $text{'index_return'});
	exit;
}

my $file = process_file_source();
if(! $file){
	print "Error: Invalid file $file</br>";
	&ui_print_footer("", $text{'index_return'});
	exit;
}
my $unzip_dir = '';
my @files;  #file to be published

#Check if its a .zip or .jar
print "Source: $file<br>";
if($in{'publish_extract'} && $file =~ /\.zip$/){
	$unzip_dir = unzip_me($file);

	#make a list of extension jars
	opendir(DIR, $unzip_dir) or die $!;
	@files = grep { $_ = $unzip_dir.'/'.$_ ; -f } readdir(DIR);
	closedir(DIR);
}else{
	push(@files, $file);
}

if(! -d $dest_dir){
	&make_dir($dest_dir, 0750, 1);
	&set_ownership_permissions('tomcat','tomcat', 0750, $dest_dir);
	print "Created $dest_dir</br>";
}

foreach my $f (@files) {
	my $file_name = basename($f);
	if($in{'publish_overwrite'} == 0 && -f $dest_dir.'/'.$file_name){
		print "Error: $dest_dir.'/'.$file_name exists</br>";
		next;
	}
	&rename_file($f, $dest_dir);
	&set_ownership_permissions('tomcat','tomcat', 0644, $dest_dir.'/'.$file_name);
	print "Published $file_name successfully in $dest_dir/$file_name</br>";
}

if($unzip_dir ne ''){
	&rmtree($unzip_dir);	#remove temp dir
}

&ui_print_footer("", $text{'index_return'});
