#!/usr/bin/perl

require './jru-lib.pl';

&ReadParse();

&ui_print_header(undef, $text{'jri_reports'}, "");

my $schid = $in{'schid'};
my $sch_env = get_jasper_home().'/schedules/'.$schid.'_env.sh';

if(! -f $sch_env){
  print("Error: $sch_id is not a valid schedule id\n");
}else{
  my $cmd = $jri_report_script.' '.$schid; # ex. gen_jri_report.sh 1
  if($in{'back'} ne 'schedule' && $config{'mail_on_run'} == 0){
    $cmd .= ' nomail'; # ex. gen_jri_report.sh 1 nomail
  }
  exec_cmd($cmd);
}

if($in{'back'} eq 'schedule'){
  &ui_print_footer("", $text{'index_return'}, 'edit_schedule.cgi', $text{'jru_schedule'});
}else{
  &ui_print_footer("", $text{'index_return'}, 'edit_reports.cgi', $text{'jri_reports'});
}
