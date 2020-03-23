#!/usr/bin/perl

require './jru-lib.pl';

&ReadParse();

my $schid = $in{'schid'};

&ui_print_header(undef, $text{'jri_reports_clean'}, "");

my %schedules = load_schedules();
if(!exists($schedules{$schid})){
  print("Error: $schid is not a valid schedule id\n");
  &ui_print_footer("", $text{'index_return'}, 'edit_reports.cgi', $text{'jri_reports'});
  return(0);
}

my %sched = %{$schedules{$schid}};  #schedule data
my %reports = get_all_reports($sched{'rep_id'}, $sched{'rep_file'});

if($in{'but_delete'}){  #actual delete
  my @files = split(/\0/, $in{'chk_filename'});
  foreach my $filename (@files){
    print "Deleting ".$filename."</br>";
    &unlink_file($reports{$filename});
  }

}else{  #show files to be deleted

  print $text{'reports_desc2'}."</br>";

  my @links_row = &ui_links_row([&select_all_link('chk_filename', 0), &select_invert_link('chk_filename', 0)]);
  print &ui_grid_table(\@links_row, 2, 100, [ undef, "align='right'" ]);

  print &ui_form_start("report_clean.cgi", "post");
    print &ui_hidden('schid', $in{'schid'});

    my @tds = ( "width=100" );
    print &ui_columns_start(['#', 'Filename', 'Size'], 100, 0, \@tds);

    foreach my $filename (sort keys %reports){
      my $file_size = (stat $reports{$filename})[7];
      my $file_link = '<a href="/updown/fetch.cgi?fetch='.&urlize($reports{$filename}).'" target="blank">'.$filename.'</a>';
      my @cols = ($file_link, $file_size);
      print &ui_checked_columns_row(\@cols, \@tds, 'chk_filename', $filename, 1, 0);
    }
    print &ui_columns_end();
  print &ui_form_end([ ["but_delete", $text{'jru_delete'}] ]);
}

&ui_print_footer("", $text{'index_return'}, 'edit_reports.cgi', $text{'jri_reports'});
