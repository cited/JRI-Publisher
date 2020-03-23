#!/usr/bin/perl

require './jru-lib.pl';

sub build_cronline{
  my $schid = $_[0];

  my $cron_line = '';
  if($in{'cron_period'} eq 'custom'){
    $cron_line .= $in{'cron_custom'};
    $cron_line .= ' root ';
  }
  $cron_line .= build_cmd_line(\%in);

  return $cron_line;
}

&ReadParse();

if($in{'cron_period'} eq 'now'){
  $in{'schid'} = '0'; #for on-demain schedules, we use the special ID 0
  my $cmd0 = build_cmd_line(\%in);

  #run the on-demand schedule
  &redirect("/jri_publisher/report_run.cgi?schid=0&back=schedule");
  return 0;
}

if($in{'submit_flag'} == 2){
  my %schedules = load_schedules();
  my %sched = %{$schedules{$in{'schid'}}};

  my $old_period = 'custom';
  if($sched{'cron'} =~ /^@(.*)/){
    $old_period = $1;
  }
  my $cronfile = get_jri_cronfile($old_period);  #file with old cron entry
  my $sch_env = get_jasper_home().'/schedules/'.$sched{'schid'}.'_env.sh';

  #get line number from id
  my $ln=0;
  if($sched{'fln'} =~ /[a-z]+([0-9]+)/){
    $ln = $1;
  }else{
    &error('Invalid schedule ID '.$sched{'fln'});
  }

  my $lref = &read_file_lines($cronfile);
  if($in{'cron_period'} ne $old_period){ #if period is different, files are different
    @{$lref}[$ln] = '#'.@{$lref}[$ln];  #just comment out the line
    $in{'submit_flag'} = 1; #change mode to add
    &unlink_file($sch_env);

  }elsif($in{'but_delete'}){
    @{$lref}[$ln] = '#'.@{$lref}[$ln];  #just comment out the line
    $in{'submit_flag'} = 0;
    $in{'schid'} = 0;
    &unlink_file($sch_env);

  }else{  #period is the same, so just update line

    @{$lref}[$ln] = build_cronline();
    $in{'submit_flag'} = 0;
    $in{'schid'} = 0;
  }
  &flush_file_lines($cronfile);
}

if($in{'submit_flag'} == 1){
  my $cron_filename = get_jri_cronfile($in{'cron_period'});

  if($in{'cron_period'} eq 'custom'){
    #if file doesn't exist, add a header
    if(! -f $cron_filename){
      open(my $fh, '>', $cron_filename) or die "open:$!";
        print $fh 'SHELL=/bin/sh'."\n";
        print $fh 'PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'."\n";
        print $fh '# m h dom mon dow user  command'."\n";
      close $fh;
    }
  }

  open(my $fh, '>>', $cron_filename) or die "open:$!".$cron_filename;
    $fh->autoflush;
    print $fh build_cronline()."\n";
  close $fh;
  unflush_file_lines($cron_filename);

  $in{'submit_flag'} = 0;
}

&ui_print_header(undef, $text{'jru_schedule'}, "");

print <<EOF;
<script type="text/javascript">
function update_select(){
	var Sel = document.getElementById('cron_period');
	if(Sel.options[Sel.selectedIndex].value == 'custom'){
    document.getElementById('cron_custom').disabled = false;
  }else{
    document.getElementById('cron_custom').disabled = true;
  }
}

function save_opt_params(){
	var Key = document.getElementsByName('optKey')[0];
  var Val = document.getElementsByName('optVal')[0];
  var Sel = document.getElementsByName('optSelParams')[0];

  var label = Key.value + '=' + Val.value;

  var option = document.createElement("option");
  option.text = label;
  option.value = label;
  option.selected = true;
  Sel.appendChild(option);

  Key.value = Val.value = '';
}

function clear_opt_params(){
  var Key = document.getElementsByName('optKey')[0];
  var Val = document.getElementsByName('optVal')[0];
  var Sel = document.getElementsByName('optSelParams')[0];
  var i;
  for(i = Sel.options.length - 1 ; i >= 0 ; i--)
  {
      Sel.remove(i);
  }
  Key.value = Val.value = '';
}

function clear_disable_obj(name){
  var Obj = document.getElementsByName(name)[0];
  Obj.disabled = !Obj.disabled;
}

function update_nomail(){
  var mailObjs = ['repEmail', 'repEmailSubj', 'repEmailBody'];
  mailObjs.forEach(clear_disable_obj);
}

</script>
EOF

# Show tabs
@tabs = ( [ "add",  $text{'schedule_tab_add'},  "edit_schedule.cgi?mode=add" ],
          [ "view", $text{'schedule_tab_view'}, "edit_schedule.cgi?mode=view" ]);

my @rep_formats = ('pdf', 'html', 'html2', 'rtf', 'xls', 'jxl', 'csv', 'xlsx', 'pptx', 'docx');
@opt_repformat = ();
foreach my $fmt (sort @rep_formats) {
	push(@opt_repformat, [ $fmt, $fmt]);
}

#re-read the file, after we have added/removed a user
%datasources = get_jru_datasources();
@opt_rep_id      = map { [$_, $_] } get_all_rep_ids();
@opt_datasources = map { [$_, $_]} sort keys %datasources;

@opt_cron_period = ();
unshift(@cron_period, 'now');
foreach my $per (@cron_period) {
  if($per eq 'now' || $per eq 'custom' || -d '/etc/cron.'.$per){
    push(@opt_cron_period, [ $per, $per]);
  }
}

%schedules = load_schedules();

print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "view", 1);

# START add tab
print &ui_tabs_start_tab("mode", "add");
print "$text{'schedule_desc1'}<p>\n";

print &ui_form_start("edit_schedule.cgi", "post");

print &ui_table_start($text{'schedule_params'}, undef, 2);

my %sched;
if($in{'name'}){
  $sched{'rep_id'} = $in{'name'};
}
if($in{'schid'}){
  %sched = %{$schedules{$in{'schid'}}};

  my $old_period = 'custom';
  if($sched{'cron'} =~ /^@(.*)/){
    $old_period = $1;
  }
  $sched{'cron'} = $old_period;
  print &ui_hidden('schid', $in{'schid'});
  print &ui_hidden('submit_flag', 2); #edit
}else{
  print &ui_hidden('submit_flag', 1); #add
}

#add cron variables - hour, minutes ...
print &ui_table_row($text{'schedule_cron'},       &ui_select("cron_period", $sched{'cron'}, \@opt_cron_period, 1, 0, undef, undef, 'id="cron_period" onchange="update_select()"').
                                                  "&nbsp".
                                                  &ui_textbox("cron_custom", '*/30 * * * *', 20, $sched{'cron'} eq 'custom' ? 0 : 1).
                                                  "&nbsp".
                                                  '<a href="https://crontab.guru" target="_blank">Cron helper</a>'
                                                  );
print &ui_table_row($text{'schedule_repname'},    &ui_select("repname", $sched{'rep_id'}, \@opt_rep_id, 1, 0));
print &ui_table_row($text{'schedule_repformat'},  &ui_select("repformat", $sched{'rep_format'}, \@opt_repformat, 1, 0));
print &ui_table_row($text{'schedule_datasource'}, &ui_select("datasource", $sched{'rep_ds'}, \@opt_datasources, 1, 0));
print &ui_table_row($text{'schedule_filename'},   &ui_textbox("filename", $sched{'rep_file'}, 20));
print &ui_table_row($text{'schedule_email'},      &ui_textbox("repEmail", $sched{'rep_rcpt'}, 20, $sched{'noemail'}).
                                                  &ui_checkbox("noemail", 1, '<i>'.$text{'schedule_noemail'}."</i>", $sched{'noemail'}, 'onclick="update_nomail()"'));
print &ui_table_end();


print &ui_hidden_table_start($text{'schedule_params_optional'}, undef, 2, 'optional_args', 0);
print &ui_table_row($text{'schedule_email_subj'}, &ui_textbox("repEmailSubj", $sched{'rep_email_subj'}, 20, $sched{'noemail'}));
print &ui_table_row($text{'schedule_email_body'}, &ui_textarea("repEmailBody", $sched{'rep_email_body'}, 2, 20, 'off', $sched{'noemail'}));

print &ui_table_row($text{'schedule_opt_params'},
    &ui_textbox("optKey", '', 10, $sched{'noemail'}, 20, 'id=optKey').'='.
    &ui_textbox("optVal", '', 10, $sched{'noemail'}, 20, 'id=optVal').
    &ui_button('Save', 'btnOptParamSave', $sched{'noemail'}, 'onclick="save_opt_params()"').
    &ui_button('Clear','btnOptParamClear', $sched{'noemail'}, 'onclick="clear_opt_params()"').
    '</br>'.
    &ui_select('optSelParams', [split(/&/, $sched{'url_opt_params'})], [split(/&/, $sched{'url_opt_params'})], undef, 1, undef, $sched{'noemail'})
    );
print &ui_hidden_table_end('optional_args');


if($in{'schid'}){ #if we have and id, its edit mode
  print &ui_form_end([ [ "but_update", $text{'jru_update'} ], ["but_delete", $text{'jru_delete'}] ]);
}else{
  print &ui_form_end([ [ "", $text{'jru_addok'} ] ]);
}
print &ui_tabs_end_tab();
#END add tab



# START view tab
print &ui_tabs_start_tab("mode", "view");
print "$text{'schedule_desc2'}<p>\n";

	my @tds = ( "width=5%", "width=10%", "width=25%", "width=5%", "width=10%", "width=20%", "width=15%", "width=10%");
	print &ui_columns_start(['SchID', 'Cron', 'Name', 'Format', 'Datasource', 'Output', 'Email', 'Optional Params'], 100, 0, \@tds);
    foreach my $schid (sort keys %schedules){
      my %sched = %{$schedules{$schid}};
      my @cols = ($schid, $sched{'cron'}, $sched{'rep_id'}, $sched{'rep_format'},
                  $sched{'rep_ds'}, $sched{'rep_file'}, $sched{'rep_rcpt'}, $sched{'url_opt_params'});

      $cols[0] = '<a href="/jri_publisher/edit_schedule.cgi?mode=add&schid='.&urlize($schid).'">'.$schid."</a>";
      $cols[7] = join('</br>', split(/&/, $cols[7]));
      print &ui_columns_row(\@cols, \@tds);
    }
	print &ui_columns_end();

print &ui_tabs_end_tab();
#END list tab

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});
