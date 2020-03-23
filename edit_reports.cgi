#!/usr/bin/perl

require './jru-lib.pl';

#Return all schedule ids, based on report id
sub get_schids{
  my $report_name = $_[0];
  my @rv;

  foreach my $schid (keys %schedules){
    my %sched = %{$schedules{$schid}};
    if($sched{'rep_id'} eq $report_name){
      push(@rv, $schid);
    }
  }
  return sort @rv;
}

&ui_print_header(undef, $text{'reports_title'}, "");

print $text{'reports_desc1'}.' '.get_jasper_home();

#load all reports
%report_data = scan_for_reports();
%schedules = load_schedules();

my $counter = 0;
my @tds = map { "width=".$_."%"} (10, 5, 5, 10, 5, 10, 30, 15, 10);
my $crop_len = length(get_jasper_home().'/reports/');

foreach my $dirpath (sort keys %report_data){
  my @files = @{$report_data{$dirpath}};
  my $report_folder = substr($dirpath, $crop_len);

  print &ui_hidden_table_start('/'.$report_folder, undef, 2, 'dirpath'.$counter, 0);
  my $col_tbl = &ui_columns_start(['Name', 'Actions', 'SchID', 'Cron', 'Format', 'Datasource', 'Output', 'Email', 'Optional Params'], 100, 0, \@tds);

  foreach my $report_name (@files){
    my $report_id = ($report_folder) ? $report_folder.'/'.$report_name : $report_folder.$report_name;

    my @schid_arr = get_schids($report_id);

    my $jrxml_link = '<a href="edit_manual.cgi?backlink=edit_reports.cgi&file='.&urlize($dirpath.'/'.$report_name.'.jrxml').'">'.$report_name."</a>";

    if(scalar(@schid_arr) == 0){
      my @cols;
      push(@cols, $jrxml_link);
      push(@cols, '<a href="edit_schedule.cgi?mode=add&name='.$report_id.'"><img border="0" alt="Add Schedule" src="images/icons8-schedule-16.png" width="20" height="20"></a>');
      $col_tbl .= &ui_columns_row(\@cols, \@tds);
      next;
    }

    my $first_schid = 1;
    foreach my $schid (@schid_arr){
      my @cols;
      my %sched = %{$schedules{$schid}};
      my %report_files = get_all_reports($report_id, $sched{'rep_file'});

      if($first_schid){
        @cols = ($jrxml_link);  #we show report name only on first schedule
      }else{
        push(@cols, '');
      }
      my @action_links = ('<a href="report_run.cgi?&schid='.$schid.'"><img border="0" alt="Add Schedule" src="images/icons8-play-property-16.png" width="20" height="20"></a>');
      if(%report_files){
        push(@action_links, '<a href="report_clean.cgi?&schid='.$schid.'"><img border="0" alt="Cleanup" src="images/icons8-broom-16.png" width="20" height="20"></a>');
        push(@action_links, '<a href="report_download.cgi?&schid='.$schid.'"><img border="0" alt="Download" src="images/icons8-download-16.png" width="20" height="20"></a>');
      }
      push(@cols, join(' ', @action_links));


      $sched{'schid'} = '<a href="edit_schedule.cgi?mode=add&schid='.&urlize($schid).'">'.$schid."</a>";

      if($config{'report_ls'} == 1){
        #to show all links at once
        if(%report_files){
          my @file_links = map { '<a href="/updown/fetch.cgi?fetch='.&urlize($report_files{$_}).'" target="blank">'.$_.'</a>'} sort keys %report_files;
          $sched{'rep_file'} = join('</br>', @file_links);
        }
      }elsif($config{'report_ls'} == 2){
        $sched{'rep_file'} = '<a href="/filemin/index.cgi?path='.&urlize($dirpath).'" target="blank">Browse</a>';
      }else{
        #to show most recent link
        if(%report_files){
          my @rep_filenames = sort keys %report_files;
          my $most_recent = $rep_filenames[-1];
          $sched{'rep_file'} = '<a href="/updown/fetch.cgi?fetch='.&urlize($report_files{$most_recent}).'" target="blank">'.$sched{'rep_file'}.'</a>';
        }
      }
      $sched{'url_opt_params'} = join('</br>', split(/&/, $sched{'url_opt_params'}));

      push(@cols, ($sched{'schid'}, $sched{'cron'}, $sched{'rep_format'}, $sched{'rep_ds'}, $sched{'rep_file'}, $sched{'rep_rcpt'}, $sched{'url_opt_params'}));

      $col_tbl .= &ui_columns_row(\@cols, \@tds);
      $first_schid = 0;
    } #end foreach($schid)
  } #end foreach($report_name)


  $col_tbl .= &ui_columns_end();
  print &ui_table_row($report_name, $col_tbl);
  print &ui_hidden_table_end('dirpath'.$counter);

  $counter = $counter + 1;
}

&ui_print_footer("", $text{'index_return'});
