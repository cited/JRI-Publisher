#!/usr/bin/perl

require './jru-lib.pl';
use File::Basename;

sub make_archive{
  my $rep_id = $_[0];
  my $tar_filename = $rep_id.'.'.$in{'archive_fmt'};
  $tar_filename =~ s/\//\-/g;

  my $tar_chroot = get_jasper_home().'/reports';
  #my $tar_filepath = &transname($tar_filename);
  my $tar_filepath = '/tmp/'.$tar_filename;

  my $dname = dirname($rep_id);
  my @fileArr = map { $dname.'/'.$_ } split(/\0/, $in{'chk_filename'});
  my $files =  join(' ', @fileArr);


  my $cmd;
  if($in{'archive_fmt'} eq 'tgz'){
     $cmd = 'tar --verbose -cz --overwrite -f "'.$tar_filepath.'" -C"'.$tar_chroot.'" '.$files;
  }elsif($in{'archive_fmt'} eq 'zip'){
    $cmd = 'cd "'.$tar_chroot.'" && zip "'.$tar_filepath.'" '.$files;
  }
  $out = &backquote_command($cmd);
	if($?){
    &error("Error: Archiving failed: $out");
  }
  return $tar_filepath;
}

sub stream_file{
  my $filepath = $_[0];
  my @st = stat($filepath);

  $| = 1;

  my $type = &guess_mime_type($filepath, undef);
  #$type ||= "application/octet-stream";
  $type = 'application/gzip; charset=binary';

  print "Content-Disposition: attachment; filename=".basename($filepath)."\n";
  print "Content-length: $st[7]\n";
  print "X-Content-Type-Options: nosniff\n";
  print "Content-type: $type\n\n";

  &open_readfile(FILE, $filepath) || &error('open_readfile'.$!);
  binmode FILE;

  while(read(FILE, $buffer, 100000)) {
    print("$buffer");
  }
  close(FILE);

  unlink_file($filepath);
}

&ReadParse();

my $schid = $in{'schid'};

if(!$in{'but_download'}){
  &ui_print_header(undef, $text{'jri_reports_download'}, "");
}

my %schedules = load_schedules();
if(!exists($schedules{$schid})){
  print("Error: $schid is not a valid schedule id\n");
  &ui_print_footer("", $text{'index_return'}, 'edit_reports.cgi', $text{'jri_reports'});
  return(0);
}

%sched = %{$schedules{$schid}};  #schedule data

if($in{'but_download'}){

  my $tar_filepath = make_archive($sched{'rep_id'});
  stream_file($tar_filepath);

}else{  #show files to be downloaded

  my %reports = get_all_reports($sched{'rep_id'}, $sched{'rep_file'});

  print $text{'reports_desc2'}."</br>";

  my @links_row = &ui_links_row([&select_all_link('chk_filename', 0), &select_invert_link('chk_filename', 0)]);
  print &ui_grid_table(\@links_row, 2, 100, [ undef, "align='right'" ]);

  print &ui_form_start("report_download.cgi", "get"); # must use GET to download file !
    print &ui_hidden('schid', $schid);

    my @tds = ( "width=100" );
    print &ui_columns_start(['#', 'Filename', 'Size'], 100, 0, \@tds);

    foreach my $filename (sort keys %reports){
      my $file_size = (stat $reports{$filename})[7];
      my $file_link = '<a href="/updown/fetch.cgi?fetch='.&urlize($reports{$filename}).'" target="blank">'.$filename.'</a>';
      my @cols = ($file_link, $file_size);
      print &ui_checked_columns_row(\@cols, \@tds, 'chk_filename', $filename, 1, 0);
    }
    print &ui_columns_end();

    my @opt_archive_fmt = ('tgz', 'zip');
    print &ui_select("archive_fmt", 'zip', \@opt_archive_fmt, 1, 0).'<b>'.$text{'report_archive_fmt'}.'</b>';

  print &ui_form_end([ ["but_download", $text{'jru_download'}] ]);

  &ui_print_footer("", $text{'index_return'}, 'edit_reports.cgi', $text{'jri_reports'});
}
