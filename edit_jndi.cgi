#!/usr/bin/perl

require './jru-lib.pl';

%jndi_defaults = ('name'=>'', 'username'=>'', 'password'=>'', 'driverClassName'=>'MySQL', 'url'=>'',
                  'maxWait'=>'30000', 'maxActive'=>'32', 'maxIdle'=>'8', 'initialSize'=>'4',
                  'timeBetweenEvictionRunsMillis'=>'300000', 'minEvictableIdleTimeMillis'=>'30000');
@field_order=('name', 'username', 'password', 'driverClassName', 'url', 'maxWait', 'maxActive', 'maxIdle', 'initialSize', 'timeBetweenEvictionRunsMillis', 'minEvictableIdleTimeMillis');

sub build_server_line{
  my $line = '<Resource';
  foreach my $key (@field_order){
    $line .= ' '.$key.'="'.$in{$key}.'"';
  }
  $line .= ' auth="Container"';
  $line .= ' type="javax.sql.DataSource"';
  $line .= ' factory="org.apache.tomcat.dbcp.dbcp.BasicDataSourceFactory"';
  $line .= '/>';
  return $line;
}

sub file_pattern_op{
  my $mode = $_[0];
  my $name = $_[1];
  my $pattern = $_[2];
  my $new_line = $_[3];

  my $filename = get_catalina_home().'/conf/'.$name.'.xml';
  my $ln=0;
  my $lref = &read_file_lines($filename);
  foreach my $line (@$lref){
    if($line =~ /[ \t]*$pattern/){
      if($mode eq 'append'){
        @{$lref}[$ln] = $line."\n\t".$new_line;
      }elsif($mode eq 'update'){
        @{$lref}[$ln] = "\t".$new_line;
      }elsif($mode eq 'delete'){
        delete @{$lref}[$ln];
      }
      last;
    }
    $ln=$ln+1;
  }
  flush_file_lines($filename);
}

&ReadParse();

$show_extended = $in{'show_extended'} || 0;

if($in{'submit_flag'} == 2){

  #patterns to match the old line
  my $server_pattern = '<Resource name="'.$in{'jndi_name'}.'" username="';
  my $context_pattern = '<ResourceLink global="'.$in{'jndi_name'}.'" name="'.$in{'jndi_name'}.'" type="javax.sql.DataSource"/>';

  if($in{'but_delete'}){
    file_pattern_op('delete', 'server',  $server_pattern, '');
    file_pattern_op('delete', 'context', $context_pattern, '');
  }else{
    file_pattern_op('update', 'server',  $server_pattern, build_server_line());
    file_pattern_op('update', 'context', $context_pattern, '<ResourceLink global="'.$in{'name'}.'" name="'.$in{'name'}.'" type="javax.sql.DataSource"/>');
  }
  $in{'submit_flag'} = 0;
  $in{'jndi_name'} = '';

}elsif($in{'submit_flag'} == 1){

  file_pattern_op('append', 'server',  '<GlobalNamingResources>$', build_server_line());
  file_pattern_op('append', 'context', '<Context>$', '<ResourceLink global="'.$in{'name'}.'" name="'.$in{'name'}.'" type="javax.sql.DataSource"/>');

  $in{'submit_flag'} = 0;
}

&ui_print_header(undef, $text{'jru_jndi'}, "");

# Show tabs
@tabs = ( [ "add",  $text{'schedule_tab_add'},  "edit_jndi.cgi?mode=add" ],
          [ "view", $text{'schedule_tab_view'}, "edit_jndi.cgi?mode=view" ]);

%jndi_drivers = ('MySQL'=>'com.mysql.jdbc.Driver',
                  'Oracle'=>'oracle.jdbc.OracleDriver',
                  'Postgre'=>'org.postgresql.Driver');
@opt_drivers = map { [$jndi_drivers{$_}, $_] } sort keys %jndi_drivers;

%datasources = get_jndi_datasources();

print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "view", 1);

print <<EOF;
<script type="text/javascript">
function update_extended(){
	var Chk = document.getElementsByName('show_extended')[0];
  var show_extended = 0;
	if(Chk.checked){
    show_extended = 1;
  }
  get_pjax_content('/jri_publisher/edit_jndi.cgi?mode=view&show_extended='+show_extended);
}
</script>
EOF

# START add tab
print &ui_tabs_start_tab("mode", "add");
print "$text{'jndi_desc1'}<p>\n";
print &ui_form_start("edit_jndi.cgi", "post");
print &ui_table_start($text{'jndi_params'}, undef, 2);


if($in{'jndi_name'}){
  #update default keys with values from existing datasource
  my %jndi_ds = %{$datasources{$in{'jndi_name'}}};
  foreach my $key (keys %jndi_defaults){
    $jndi_defaults{$key} = $jndi_ds{$key};
  }
  print &ui_hidden('jndi_name', $in{'jndi_name'});
  print &ui_hidden('submit_flag', 2); #edit
}else{
  print &ui_hidden('submit_flag', 1); #add
}

foreach my $key (@field_order[0..4]){
    if($key eq 'driverClassName'){
      print &ui_table_row($text{'jndi_'.$key}, &ui_select($key,  $jndi_defaults{$key}, \@opt_drivers, 1, 0));
    }else{
      print &ui_table_row($text{'jndi_'.$key}, &ui_textbox($key, $jndi_defaults{$key}, 20));
    }
}

print &ui_table_end();

print &ui_hidden_table_start($text{'jndi_params_optional'}, undef, 2, 'optional_args', 0);
foreach my $key (@field_order[5..10]){
    if($key eq 'driverClassName'){
      print &ui_table_row($text{'jndi_'.$key}, &ui_select($key,  $jndi_defaults{$key}, \@opt_drivers, 1, 0));
    }else{
      print &ui_table_row($text{'jndi_'.$key}, &ui_textbox($key, $jndi_defaults{$key}, 20));
    }
}
print &ui_hidden_table_end('optional_args');

if($in{'jndi_name'}){ #if we have and id, its edit mode
  print &ui_form_end([ [ "but_update", $text{'jru_update'} ], ["but_delete", $text{'jru_delete'}] ]);
}else{
  print &ui_form_end([ [ "", $text{'jru_addok'} ] ]);
}
print &ui_tabs_end_tab();
#END add tab



# START view tab
print &ui_tabs_start_tab("mode", "view");
print "$text{'schedule_desc2'}<p>\n";

  print &ui_checkbox("show_extended", 1, '<i>'.$text{'jndi_params_optional'}."</i>", $show_extended, 'onclick="update_extended()"');

	my @tds = ( "width=5" );
  my @col_labels;
  if($show_extended){
    @col_labels = map { $text{'jndi_'.$_} } @field_order;
  }else{
    @col_labels = map { $text{'jndi_'.$_} } @field_order[0..4];
  }

	print &ui_columns_start([@col_labels], 100, 0, \@tds);
    foreach my $name (sort keys %datasources){
      my %jndi_ds = %{$datasources{$name}};
      my @cols;
      if($show_extended){
        @cols = map { $jndi_ds{$_} } @field_order;
      }else{
        @cols = map { $jndi_ds{$_} } @field_order[0..4];
      }

      $cols[0] = '<a href="/jri_publisher/edit_jndi.cgi?mode=add&jndi_name='.&urlize($name).'">'.$name."</a>";
      print &ui_columns_row(\@cols, \@tds);
    }
	print &ui_columns_end();

print &ui_tabs_end_tab();
#END list tab

print &ui_tabs_end(1);

&ui_print_footer("", $text{'index_return'});
