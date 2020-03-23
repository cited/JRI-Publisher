#!/usr/bin/perl

require './jru-lib.pl';
require '../webmin/webmin-lib.pl';	#for OS detection

sub jru_add_entry{

	open(my $fh, '>>', get_prop_file()) or die "open:$!";
	print $fh "\n";
	print $fh '[datasource:'.$in{'name'}."]\n";
	foreach my $key (@ds_keys){
		print $fh $key.'='.$in{$key}."\n";
	}
	close $fh;
}

sub jru_update_entry{
	my $name = $in{'dsname'};
	my $prop_file = get_prop_file();

	$lref = &read_file_lines($prop_file);
	my $ln=0;
	my $ds_line = -1;
	foreach $line (@$lref){
    if($line =~ /^\[datasource:$name\]/){
			$ds_line = $ln;
      last; #don't add the line twice
		}
		$ln=$ln+1;
	}

	if($ds_line > 0){
		@{$lref}[$ds_line] = '[datasource:'.$in{'name'}."]";
		$ln = $ds_line;
		foreach my $key (@ds_keys){
			$ln=$ln+1;
			my $line = @{$lref}[$ln];
			if($line =~ /^$key=/){
				@{$lref}[$ln] = $key.'='.$in{$key};
			}
		}
	}

  &flush_file_lines($prop_file);
}

sub jru_rm_entry{
	my $name = $in{'datasource'};
	my $prop_file = get_prop_file();

	$lref = &read_file_lines($prop_file);
	my $ln=0;
	my $ds_line = -1;
	foreach $line (@$lref){
    if($line =~ /^\[datasource:$name\]/){
			$ds_line = $ln;
      last; #don't add the line twice
		}
		$ln=$ln+1;
	}

	if($ds_line > 0){
		@{$lref}[$ds_line] = '#'.@{$lref}[$ds_line];
		$ln = $ds_line;
		foreach my $key (@ds_keys){
			$ln=$ln+1;
			my $line = @{$lref}[$ln];
			if($line =~ /^$key=/){
				@{$lref}[$ln] = '#'.$line;
			}
		}
	}

  &flush_file_lines($prop_file);
}

&ReadParse();
&ui_print_header(undef, $text{'jru_title'}, "");

#Make options for type field
my @jru_types = ('jdbc', 'jndi');
@opt_jru_types = map { [$_, $_]} sort @jru_types;

%datasources = get_jru_datasources();
@opt_datasources = map { [$_, $_]} sort keys %datasources;

if($in{'post_flag'} == 3){	#update
	if(!$datasources{$in{'dsname'}}){
		print("<b>datasource:".$in{'dsname'}."</b> doesn't exists!");
		&ui_print_footer("", $text{'index_return'});
		exit;
	}else{
		#check if all keys exists
		foreach my $key (@ds_keys){
			if(!$in{$key}){
				print("Datasource $key is empty!");
				&ui_print_footer("", $text{'index_return'});
				exit;
			}
		}
		jru_update_entry();
	}

}elsif($in{'post_flag'} == 1){	#add
	if($datasources{$in{'name'}}){
		print("<b>datasource:".$in{'name'}."</b> already exists!");
		&ui_print_footer("", $text{'index_return'});
		exit;
	}else{
		#check if all keys exists
		foreach my $key (@ds_keys){
			if(!$in{$key}){
				print("Datasource $key is empty!");
				&ui_print_footer("", $text{'index_return'});
				exit;
			}
		}
		jru_add_entry();
	}

}elsif($in{'post_flag'} == 2){	#remove
	if(!$datasources{$in{'datasource'}}){
		print("<b>datasource:".$in{'datasource'}."</b> doesn't exists!");
		&ui_print_footer("", $text{'index_return'});
		exit;
	}
	jru_rm_entry();
}

if($in{'post_flag'}){
	#re-read the file, after we have added/removed a user
	%datasources = get_jru_datasources();
	@opt_datasources = map { [$_, $_]} sort keys %datasources;
}

# Show tabs
@tabs = ( [ "add",$text{'jru_tabadd'}, 		"edit_datasource.cgi?mode=add" ],
				  [ "remove", $text{'jru_tabremove'}, "edit_datasource.cgi?mode=remove" ],
					[ "list",   $text{'jru_tablist'},		"edit_datasource.cgi?mode=list" ]
				);

print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "list", 1);

my @cols = ('', '', '', '', '');
if($in{'dsname'}){
	my %ds_entries = %{$datasources{$in{'dsname'}}};
	@cols = map { $ds_entries{$_} } @ds_keys;
}

#Add tab
print &ui_tabs_start_tab("mode", "add");
print "$text{'jru_desc1'}<p>\n";

print &ui_form_start("edit_datasource.cgi", "post");
if($in{'dsname'}){
	print &ui_hidden("post_flag", 3);	#update
	print &ui_hidden("dsname", $in{'dsname'});		#name of the datasource to be edited
}else{
	print &ui_hidden("post_flag", 1);		#add
}
print &ui_table_start($text{'jru_add'}, undef, 2);
	print &ui_table_row($text{'jru_type'}, 			&ui_select("type", $cols[0], \@opt_jru_types, 1, 0), 2);
	print &ui_table_row($text{'jru_name'}, 			&ui_textbox("name", $cols[1], 40), 2);
	print &ui_table_row($text{'jru_url'}, 			&ui_textbox("url", $cols[2], 40), 2);
	print &ui_table_row($text{'jru_username'}, 	&ui_textbox("username", $cols[3], 40), 2);
	print &ui_table_row($text{'jru_password'}, 	&ui_textbox("password", $cols[4], 40), 2);
print &ui_table_end();
if($in{'dsname'}){
	print &ui_form_end([ [ "but_update", $text{'jru_update'} ] ]);
}else{
	print &ui_form_end([ [ "but_add", $text{'jru_addok'} ] ]);
}
print &ui_tabs_end_tab();
#End Add tab

#remove tab
print &ui_tabs_start_tab("mode", "remove");
print "$text{'jru_desc2'}<p>\n";

print &ui_form_start("edit_datasource.cgi", "post");
print &ui_hidden("post_flag", 2);
print &ui_table_start($text{'jru_remove'}, undef, 2);
	print &ui_table_row($text{'jru_datasource'}, &ui_select("datasource", undef, \@opt_datasources, 1, 0), 2);
print &ui_table_end();
print &ui_form_end([ [ "", $text{'jru_rmok'} ] ]);
print &ui_tabs_end_tab();
#End remove tab

#list tab
print &ui_tabs_start_tab("mode", "list");
print "$text{'jru_desc3'}<p>\n";

	local @tds = ( "width=5" );
	print &ui_columns_start([ 'Datasource', 'Type', 'Name', 'URL', 'Username', 'Password' ], 100, 0, \@tds);
		foreach my $ds_name (sort keys %datasources){
			local %ds_entries = %{$datasources{$ds_name}};

			my @cols = ($ds_name);
			$cols[0] = '<a href="/jri_publisher/edit_datasource.cgi?mode=add&dsname='.&urlize($ds_name).'">'.$ds_name."</a>";
			foreach my $key (@ds_keys){
				push(@cols, $ds_entries{$key});
			}
			print &ui_columns_row(\@cols, \@tds);
		}
	print &ui_columns_end();

print &ui_tabs_end_tab();
#End list tab

print &ui_tabs_end(1);
&ui_print_footer("", $text{'index_return'});
