require './tomcat-lib.pl';

@ds_keys = ('type', 'name', 'url', 'username', 'password');
@cron_period = ('custom', 'hourly', 'daily', 'weekly', 'monthly');

$jri_report_script = '/usr/local/bin/gen_jri_report.sh';

sub get_jasper_home(){
  return get_catalina_home().'/jasper_reports';
}

sub get_prop_file(){
  return get_jasper_home().'/conf/application.properties';
}

sub get_jri_cronfile{
  my $period = $_[0];
  if($period eq 'custom'){
    return '/etc/cron.d/jri_schedule';
  }else{
    return '/etc/cron.'.$period.'/jri_schedules.sh';
  }
}

sub get_jru_datasources{
	my %rv;

	my $ds_name='';
	my %ds_entries = map { $_ => '' } @ds_keys;

	open(my $fh, '<', get_prop_file()) or die "open:$!";
	while(my $line = <$fh>){
		if($line =~ /^#/){
			next;
		}elsif($line =~ /^\[datasource:(.*)\]/){
			if($ds_name){
				$rv{$ds_name} = {%ds_entries};
				%ds_entries = map { $_ => '' } @ds_keys;
			}
			$ds_name = $1;
		}elsif($line =~ /^\[/){ #if we begin another section
	    if($ds_entries[0]){ #and have data
	      $rv{$ds_name} = {%ds_entries};  #push it to hash
	    }
		}else{
			foreach my $key (@ds_keys){
				if($line =~ /^$key=(.*)/){
					$ds_entries{$key} = $1;
				}
			}
		}
	}
	close $fh;

	if($ds_entries{'type'}){
		$rv{$ds_name} = {%ds_entries};
	}

	return %rv;
}

sub get_jndi_datasources(){
  my %rv;

  #get all 'javax.sql.DataSource' lines from server.xml
  open my $fh, '<:encoding(UTF-8)', get_catalina_home().'/conf/server.xml' or die "open:$!";
  while (my $line = <$fh>) {
      if ($line =~ /javax\.sql\.DataSource/) {
          #extract key/value from line
          my %tokens;
          foreach my $token (split (/ /, $line)){
            if($token =~ /(.*)="(.*)"/){
              $tokens{$1} = $2;
            }
          }
          #remove keys we don't edit
          delete $tokens{'type'};
          delete $tokens{'auth'};
          delete $tokens{'factory'};

          #insert our datastore
          #TODO: check if all keys are defined !
          $rv{$tokens{'name'}} = {%tokens};
      }
  }
  close $fh;

  return %rv;
}

sub load_custom_schedules{
  my $label = $_[0];
  my $cronfile = get_jri_cronfile($label);

  my %scheds;   #keys are the line numbers from schedule file
  my $ln=0;
  $lref = &read_file_lines($cronfile, 1);
	foreach my $line (@$lref){
    chomp($line);

    my $schid;      #schedule env file
    my $opt_nomail = 0;
    my $cron_period;

    if($line =~ /^[A-Z#]+/){  #skip variables and comments
      $ln=$ln+1;
      next;

    }elsif($line =~ /^@/){  #nickname cron line
      #@daily root /usr/local/bin/gen_jri_report.sh 1 [nomail]
      my @tokens = split(/ /, $line, 4);
      $schid = $tokens[3];
      $cron_per = '@'.$tokens[0];
      if(scalar(@tokens) == 5 && $tokens[4] == 'nomail'){
        $opt_nomail = 1;
      }

    }elsif($line =~ /^[0-9\*]+/){  #standard cron line
      #5 0 * * * root /usr/local/bin/gen_jri_report.sh 1 [nomail]
      my @tokens = split(/ /, $line, 9);
      $schid = $tokens[7];
      $cron_per = join(' ', @tokens[0..4]);
      if(scalar(@tokens) == 9 && $tokens[9] == 'nomail'){
        $opt_nomail = 1;
      }

    }elsif($line =~ /^$jri_report_script/){  #script line
      #/usr/local/bin/gen_jri_report.sh 1 [nomail]
      my @tokens = split(/ /, $line, 3);
      $schid = $tokens[1];
      $cron_per = '@'.$label;
      if(scalar(@tokens) == 3 && $tokens[3] == 'nomail'){
        $opt_nomail = 1;
      }
    }

    if($schid){  #if we have matched our scrpit in this line
      my %vars;
      my $sch_env = get_jasper_home().'/schedules/'.$schid.'_env.sh';
      read_env_file($sch_env, \%vars);

      #remove quotes from values
      foreach my $key (keys %vars){
        my $value = $vars{$key};
        if($value =~ /^".*"$/){
          $vars{$key} = substr($value, 1, length($value)-2);
        }
        $vars{$key} =~ s/<\/br>/\r\n/g;
      }

      $scheds{$schid} = {'cron'=>$cron_per, 'rep_id'=>$vars{'REP_ID'}, 'rep_format'=>$vars{'REP_FORMAT'},
                            'rep_ds'=>$vars{'REP_DATASOURCE'}, 'rep_file'=>$vars{'REP_FILE'}, 'rep_rcpt'=>$vars{'RECP_EMAIL'},
                            'rep_email_subj'=>$vars{'EMAIL_SUBJ'}, 'rep_email_body'=>$vars{'EMAIL_BODY'},
                            'url_opt_params'=>$vars{'OPT_PARAMS'}, 'fln'=>$label.$ln, 'noemail'=>$opt_nomail};
    }

		$ln=$ln+1;
	}
  return %scheds;
}

sub load_schedules{
  my %scheds = load_custom_schedules('custom');

  foreach my $period (@cron_period){
    if(-d '/etc/cron.'.$period && -f '/etc/cron.'.$period.'/jri_schedules.sh'){
      my %schedule = load_custom_schedules($period);
      foreach my $key (sort keys %schedule){
        $scheds{$key} = $schedule{$key};
      }
    }
  }

  return %scheds;
}

sub get_sch_id(){
  my $sch_cfg = get_jasper_home().'/schedules/.schid.sh';
  my %vars;
  if(-f $sch_cfg){
    read_env_file($sch_cfg, \%vars);
  }else{
    $vars{'SCHID'} = 0;
  }

  my $schid = $vars{'SCHID'} + 1;
  $vars{'SCHID'} = $schid;

  write_env_file($sch_cfg, \%vars);

  return $schid;
}

sub build_cmd_line{
  my %schedule = %{$_[0]};
  if(!exists($schedule{'schid'})){  #if we don't have a schedule id
    $schedule{'schid'} = get_sch_id();
  }

  #create report script from template
  my $sch_env = get_jasper_home().'/schedules/'.$schedule{'schid'}.'_env.sh';
  &set_ownership_permissions('root', 'root', 0660, $sch_env);


  my @optParams = split(/\0/, $in{'optSelParams'});

  $schedule{'repEmailBody'} =~ s/(\r?\n)+/<\/br>/g;

  my %vars = ('SCH_ID'=> $schedule{'schid'},
              'REP_ID'=> $schedule{'repname'}, 'REP_FORMAT'=>$schedule{'repformat'},
              'REP_DATASOURCE'=>$schedule{'datasource'}, 'REP_FILE'=>$schedule{'filename'},
              'RECP_EMAIL'=>$schedule{'repEmail'},
              'EMAIL_SUBJ'=>$schedule{'repEmailSubj'},
              'EMAIL_BODY'=>$schedule{'repEmailBody'},
              'OPT_PARAMS'=>'"'.join('&', @optParams).'"');
  write_env_file($sch_env, \%vars);

  my $cmd = $jri_report_script.' '.$schedule{'schid'}; # ex. gen_jri_report.sh /home/tomcat/apache-tomcat-8.5.50/schedules/1_env.sh
  if($schedule{'noemail'}){
    $cmd .= ' nomail'; # ex. gen_jri_report.sh 1 nomail
  }

  return $cmd;
}

sub get_all_reports{
  my $rep_id = $_[0];
  my $filename = $_[1];

  my $has_folder = index($rep_id, '/');
  my $rep_folder='';
  if($has_folder > 0){
    $rep_folder = substr($rep_id, 0, $has_folder);  #take folder name from report id
  }

  my $report_dir = get_jasper_home().'/reports/'.$rep_folder;
  opendir(DIR, $report_dir) or die "$!:$report_dir";
  my @reports = grep {
     /^[0-9_]+${filename}$/     # ends in $repname - 20200901_102211_orders.pdf
     && -f "$report_dir/$_"     # and is a file
  } readdir(DIR);
  closedir(DIR);

  my %rv;
  foreach my $report (@reports){
    $rv{$report} = $report_dir.'/'.$report;
  }
  return %rv;
}

sub scan_for_reports(){
  my %rv;
  my @subdirs = (get_jasper_home().'/reports');

  #while we have dirs to traverse
  while(scalar @subdirs){
    my $dirpath = pop(@subdirs);

    #scan through the dir
    opendir(DIR, $dirpath) or die $!;
      my @entries = readdir DIR;
    closedir(DIR);

    my @files;
    foreach my $entry (@entries){
      if($entry =~ /^\./){
        next;
      }elsif( -f $dirpath.'/'.$entry && $entry =~ /(.*)\.jrxml$/){
        push(@files, $1);
      }elsif( -d $dirpath.'/'.$entry){
        push(@subdirs, $dirpath.'/'.$entry);
      }
    }

    if(scalar(@files)){ #if we have files
      $rv{$dirpath} = [@files];
    }
  }

  return %rv;
}

sub get_all_rep_ids(){
  my %report_data = scan_for_reports();
  my $crop_len = length(get_jasper_home().'/reports/');
  my @rv;

  foreach my $dirpath (sort keys %report_data){
    my @files = @{$report_data{$dirpath}};
    my $report_folder = substr($dirpath, $crop_len);

    foreach my $report_name (@files){
      my $report_id = ($report_folder) ? $report_folder.'/'.$report_name : $report_folder.$report_name;
      push(@rv, $report_id);
    }
  }
  return sort @rv;
}
