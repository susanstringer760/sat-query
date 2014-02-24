#!/usr/bin/perl -I./cron -I./scripts -I./

use File::Basename;
use FindBin qw($Bin);
require "config/config.pl";

# the database info
$db_name = dbName();
$user = dbUser();
$password = dbPassword();
$host = dbHost();
#
#----------------------------------------------------
# Check the main_query the user has submitted. Determines the
#  display type chosen and calls the needed subroutine.
#----------------------------------------------------
sub checkQuery
{

	my $base_cgi = shift;
	my $bottom_html = shift;
	my $dbh = shift;

	# Get the display type and show the table
	my $dis_type = $main_query->param( "dis_type" );

	if( $dis_type eq "by_day" )
	{
		showFrames($base_cgi, $bottom_html);
	}
	else
	{
		displayAllFiles($dbh);
	}
}

#----------------------------------------------------
# Show the frameset and set up the top frame to display the
#		the daily results 
#----------------------------------------------------
sub showFrames
{

  	my $base_cgi = shift;
  	my $bottom_html = shift;

	print $main_query->header();
	# Get the url for the top frame 
	my $top_src = getQueryResult( $base_cgi );

	my $html = '';

	# Print the frameset
	println( "<html><head><title>Query Result</title></head>" );

	println( "<frameset rows=\"35%,65%\" cols=\"*\" framespacing=5 border=1>" );
	println( "<frame name=top border=2 frameborder=1 src=\"$top_src\" marginwidth=0 marginheight=0>" );
	println( "<frame name=bottom border=2 frameborder=1 src=\"$bottom_html\" marginwidth=0 marginheight=0>" );
	println( "</frameset>" );
	println( "</html>" );

}

#----------------------------------------------------
# Return the url for the top frame using the values the user entered in the 
# 	for
#----------------------------------------------------
sub getQueryResult
{

	my $base_cgi = shift;
	my $script_name = basename($0);
	$base_cgi .= "/$script_name";

	# Get the start and end date
	my $start = getStartDate();
	my $end = getEndDate();

	# Get the start and end time
	my $start_tm = getStartTime();
	my $end_tm = getEndTime();

	# Get the satellite and resolution
	my $sat = $main_query->param( "satellite" );
	my $res = $main_query->param( "resolution" );

	# Get the max and min number of files to display
	my $min_files = $main_query->param( "min_files" );
	my $max_files = $main_query->param( "max_files" );

	# Form the src url for the top frame
	my $src = $base_cgi. "?Action=getdaily&jdate_frm=$start&jdate_to=$end&satellite=$sat&resolution=$res";
	$main_query->param(-name=>'jdate_frm',-value=>$start);
	$main_query->param(-name=>'jdate_to',-value=>$end);

	if( $start_tm )
	{
		$src = $src. "&time_frm=$start_tm";
	        $main_query->param(-name=>'time_frm',-value=>$start_tm);
	}
	if( $end_tm )
	{
		$src = $src. "&time_to=$end_tm";
	        $main_query->param(-name=>'time_to',-value=>$end_tm);
	}

	if( $min_files ne "0" )
	{
		$src = $src . "&min_files=$min_files";
	}
	if( $max_files ne "ALL" )
	{
		$src = $src . "&max_files=$max_files";
	}

	# Determine which missing data mode (all records, only missing data, or
	#		only no missing data)
	my $miss_data = $main_query->param( "miss_data" );

	if( $miss_data eq "missing" )
	{
		$src = $src . "&missing=1";
	}
	elsif( $miss_data eq "no_missing" )
	{
		$src = $src . "&missing=0";
	}

	# Determine which sectors to display
	my $sector_str = resolveSectors( "getQueryResult",$main_query->param('satellite_sector'));


	   
	if ( ($sector_str =~ /all/i) || (!$sector_str))
	#if( ($sectors[0] =~ /all/i)   || !@sectors )
	{
		#$src = $src . "&sector=all";
		$src = $src . "&satellite_sector=all";
	}
	else
	{
		$src = $src . "&satellite_sector=$sector_str";
	}

	return $src;

}

#-----------------------------------------------------------------
# This subroutines returns a reference to an array containing all
# the sectors numbers (routine,rapid and super rapid). It returns
# a reference to a hash where the key is the sector abrv and the value
# is a reference to an array containing the sector ids that match
# the abrv
sub resolveSectors 
{

  # the selected sector
  my $caller = shift;
  my $selected_sector = shift;

  my $sql;

  #return [$selected_sector] if ( $selected_sector =~ /ALL/i );
  return $selected_sector if ( $selected_sector =~ /ALL/i );

  my ($satellite,$abrv) = split('::', $selected_sector);

  $sql = "SELECT id,abrv FROM Sector WHERE abrv = '$abrv' AND satellite LIKE '$satellite%' order by id";
  my @sectors;
  my @rows = @{$dbh->selectall_arrayref($sql)};
  for ($i=0; $i<=$#rows;$i++) {
    my $abrv = $rows[$i]->[0];
    next if ( $abrv =~ /unknown/i );
    push(@sectors, $abrv);
  }
  my $sector_ids = join(',', @sectors);

  return $sector_ids;

  #return \@sectors;

}


#-----------------------------------------------------------------
# This subroutine returns an array containing the real sector 
#  id numbers in the database.  The user is given a choice of 
#  choosing several different sectors.  Some of these sectors
#  are scanned during the routine scanning, rapid scanning,
#  and super rapid scanning.  Each of these are stored as a 
#  seperate scan in the database.  This subroutine uses the 
#  hash table %sect_refs defined in Util.pm to relate the single
#  sector number sent by the html form to the mutltiple sector id
#  numbers that the sector is stored under in the database. 
#-----------------------------------------------------------------
sub rresolveSectors
{
	my @sects = @_;
	my @return;
	my $c = 0;

	if( $sects[0] eq "all" )
	{
		@return = @sects;
	}
	else
	{
		foreach my $s1 (@sects)
		{
			@sects2 = @{$sect_refs{$s1}};
			foreach my $s2 (@sects2)
			{
				$return[$c++] = $s2;
			}
		}
	}	
	return @return;
}

#----------------------------------------------------
# Display the daily results of the main_query. Creates the needed SQL
#		statement, queries the database and displays the results in
#		an html table.  
#----------------------------------------------------
sub displayDaily
{

	#my $main_query = shift;
	my $base_url = shift;
	my $base_cgi = shift;
	my $col1 = "#FFFFFF";
	my $col2 = "#EBEBF5";
	my $col = $col1;

	# --Read in all of the parameters-- #
	my $start = $main_query->param( "jdate_frm" );
	my $end = $main_query->param( "jdate_to" );
	#my $start = getStartDate();
	#my $end = getEndDate();

	my $sat = $main_query->param( "satellite" );
	my $res = $main_query->param( "resolution" );

	my $time_frm = $main_query->param( "time_frm" );
	my $time_to = $main_query->param( "time_to" );

	my $min_files = $main_query->param( "min_files" );
	my $max_files = $main_query->param( "max_files" );

	#my @sectors = $main_query->param( "sector" );
	#my @sectors = $main_query->param( "satellite_sector" );
	my $sector_str = $main_query->param( 'satellite_sector' );
	my $missing = $main_query->param( "missing" );
	# --------------------------------- #

	# Boolean values...
	my $show_missing = 1;		# Whether or not to show missing day(s)
	my $cnt_files = 0;		# Whether or not to count the number of files for each day in the main_query

	# Determine the sectors to display - this is used for the link to the 
	#  file table
	my $sector = "";
	#if( $sectors[0] eq "all" || !@sectors )
	#print_error("qwer: $#sectors");
	#if( $sectors[0] =! /all/ || !@sectors )
	#if( $sectors[0] !~ /all/i || !@sectors )
	#if( $sectors[0] =~ /all/i || !@sectors )
	if ( ($sector_str =~ /all/i) || !$sector_str)
	{
		#$sector = "&sector=all";
		$sector = "&satellite_sector=all";
	}
	else
	{
		$sector = "&satellite_sector=$sector_str";
		#foreach my $sec (@sectors)
		#{
			#$sector = $sector . "&sector=$sec";
			#$sector = $sector . "&satellite_sector=$sec";
		#}
		#$cnt_files = 1;
	}

	# Start building the SQL statement
	my $sql = "SELECT * FROM DayTable WHERE date >= $start and date <= $end";

	# Satellite to display
	#if( $sat ne "All" && defined( $sat ) )
	if( $sat !~ /all/i && defined( $sat ) )
	{ $sql = $sql . " and satellite = \'$sat\'"; } 

	# Resolution to display
	#if( $res ne "All" && defined( $res ) )
	if( $res !~ /all/i && defined( $res ) )
	{ $sql = $sql . " and resolution=\'$res\'";	}

	# Max/min number of files to display
	if( $min_files )
	{
		$sql = $sql . " and nfiles >= $min_files";
		$show_missing = 0;
	}
	#if( $max_files )
	if( defined($max_files) && $max_files !~ /all/i )
	{
		$sql = $sql . " and nfiles <= $max_files";
		$show_missing = 0;
	}	

	# How to display/not display days with missing files
	if( defined( $missing ) )
	{
		$sql = $sql . " and missing=$missing";
		$show_missing = 0;
	}

	# Compelete SQL statement
	$sql = $sql . " ORDER BY date ASC, satellite ASC, resolution ASC";

	# ---------------------Print the heading of the table--------------------- #
	#println( header() );
	#my $display_query = CGI->new();
	my $main_query = CGI->new();
	print $main_query->header();
	println( "<html><head><title>Query Results</title></head><body bgcolor=#FFFFFF>" );

	#println( "<center><b><font size=+2>Mass Store Query Results</b></font><br>" );
	println( "<center><b><font size=+2>HPSS Query Results</b></font><br>" );
my $xx = getCalendar($start);
	print( "<font size=+1><b>Start:</b> " . getCalendar( $start ) );

	# Show the to and from time of the main_query
	if( defined( $time_frm ) )
	{  print( " ", substr( $time_frm, 0, 2 ), ":", substr( $time_frm, 2 , 2 ) ); }
	else
	{  print( " 00:00" ); }	
  print( "&nbsp;&nbsp;<b>End:</b> ". getCalendar( $end ) ); 
	if( defined( $time_to ) )
	{  print( " ", substr( $time_to, 0, 2 ), ":", substr( $time_to, 2 , 2 ) ); }
	else
	{  print( " 23:59" ); }	

	# Show the satellite and resolution of the main_query
	println( "<b>&nbsp;&nbsp;Satellite:</b> $sat&nbsp;&nbsp;<b>Resolution:</b> $res</b><br></font>" );	

	# Show the min/max number of files of the main_query
	print( "<b>Min. Files/Day: </b>" );
	if( defined( $min_files ) )
	{ print( $min_files ); }
	else
	{ print( 0 ); }

	print( "&nbsp;&nbsp;&nbsp;&nbsp;<b>Max. Files/Day: </b>" );
	if( defined( $max_files ) )
	{ print( $max_files ); }
	else
	{ print( "ALL" ); }

	# Show how to/not to display days with missing data
	print( "&nbsp;&nbsp;&nbsp;&nbsp;<b>Display: </b>" );
	if( !defined( $missing ) )
	{ print( "All Matches" ); }
	elsif( $missing == 1 )
	{ print( "Days With Missing Data" ); }
	elsif( $missing == 0 )
	{ print( "Days Without Missing Data" ); }

	# Sectors
	my @sector_id_list = split(",", $sector_str);
	if ($sector_id_list[0] =~ /all/i ) {
	  $row = 'all';
	} else {
	  my $sector_sql = "select abrv from Sector where id = $sector_id_list[0]";
	  my $row = $dbh->selectrow_array($sector_sql);
	}
	print( "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>Sector: $row</b>" );
	#print_error("testit: $sector_id_list[0] and $row");

	# Show a link back to the main_query form page
	#print ("<a href='javascript:window.history.back();'>Back to form</a>");
	#print( "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href='$base_url/instructions.html' target='new'>Instructions</a>" );
	#print( "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href='/sat_main_query/instructions.html' target='new'>Instructions</a>" );
	#print( "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=$main_query_form target=_top>Back To Form</a>" );
	#print( "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href='/sat_main_query/instructions.html' target='new'>Instructions</a>" );
	println( "<br>" );

	# Get the header of the table
	print( DayRecord->getTableHeader() );
	# -----------------Finished printing the table heading -------------------------- #

	# Execute the main_query on the database
	my $day_ref = $dbh->selectall_hashref($sql, 'id');
#	my @day_list = keys(%$day_ref);
#        my $file_count_ref;
#        #        foreach $file_path (sort(keys %$file_ref)) {
#        #                my $path = $file_ref->{$file_path}->{'path'};
#        #                my $nfiles = $file_ref->{$file_path}->{'nfiles'};
#        #                $file_count_ref->{$path} = $nfiles;
#        #
#        #        }
#


	#my $sth = $dbh->prepare( $sql );
	#$sth->execute;

	my @row;
	my $rec;

	my $prev_day = 0;		# The previous day to determine if there are any missing days
	my $tot_size = 0;		# The total disk space for this main_query
	my $tot_files = 0;	# The total number of files for this main_query

#foreach $file_path (sort(keys %$file_ref)) {
#	my $path = $file_ref->{$file_path}->{'path'};
	# Display each row from the main_query in the table
	#while( (@row) = $sth->fetchrow )

	my @list_of_days = sort(keys %$day_ref);

	#foreach $day_path (sort(keys %$day_ref)) 
	#print_warning("before");
	foreach $day_path (@list_of_days) 
	{	
	
		# Create a new DayRecord
		$rec = DayRecord->new();
#		$rec->{id} = $row[0];
#		$rec->{date} = $row[1];
#		$rec->{satellite} = $row[2];
#		$rec->{resolution} = $row[3];
#		$rec->{nfiles} = $row[4];
#		$rec->{size} = $row[5];
#		$rec->{path} = $row[6];
#		$rec->{missing} = $row[7];

		$rec->{id} = $day_ref->{$day_path}->{id};
		$rec->{date} = $day_ref->{$day_path}->{date};
		$rec->{satellite} = $day_ref->{$day_path}->{satellite};
		$rec->{resolution} = $day_ref->{$day_path}->{resolution};
		$rec->{nfiles} = $day_ref->{$day_path}->{nfiles};
		$rec->{size} = $day_ref->{$day_path}->{size};
		$rec->{path} = $day_ref->{$day_path}->{path};
		$rec->{missing} = $day_ref->{$day_path}->{missing};

		# Add to the total size and number of files
		$tot_size += $rec->{size};
		$tot_files += $rec->{nfiles};

		# Set the color for this row
		if( $col eq $col2 ) { $col = $col1; } else { $col=$col2; }

		# Build the link to the file table for this day
		#my $link = "<a href=" . $my_url . "?Action=getfiles&day_id=$rec->{id}";
		$main_query->param(-name=>'day_id', -default=>$rec->{id});
		my $myself = basename($0);
		my $link = "<a href=$base_cgi/$myself?Action=getfiles&day_id=$rec->{id}";
		if( $rec->{date} == $start && $time_frm )
		{ $link = $link . "&time_frm=$time_frm"; }

		if( $rec->{date} == $end && $time_to )
		{ $link = $link . "&time_to=$time_to"; }

		$link = $link . $sector;
		$link = $link . "&satellite=$rec->{satellite}&resolution=$rec->{resolution}";
		$link = $link . " target=bottom>";
	
		# Determine if there are any missing days between this day and the
		#   previous day	
		if( !$prev_day )
		{
			$prev_day = $rec->{date};
		}
		else
		{
			if( $rec->{date} - $prev_day > 1 && $show_missing )
			{
				print( getMissingDay() );							# Display the yellow row that shows
			}																				#  day(s) are missing                                     
			$prev_day = $rec->{date};
		}

		# Count the number of files - only if the user did not choose 'All' for the
		#   sectors to display
		if( $cnt_files )
		{
			$rec->{nfiles} = countFiles( $rec->{id}, \@sectors, $dbh );
		}

		# Print this record to the table;
		if( $rec->{nfiles} != 0 )
		{	print( $rec->getHtmlRow( $col, $link ) ); }
	}
	#print_error("after");
	# Get the header of the table
	if ( $#list_of_days < 0 ) {
	  println( "<br><b><font size='5' color='red'>There are no files available for the requested dates</font></b><br>");
	} else {
#	  print( DayRecord->getTableHeader() );

	  # -----------Finish off the table and html code----------#
	  println( "</table>" );

	  println( "<b>Total Disk Usage: </b>" . commify( $tot_size ) . " KB&nbsp;&nbsp;" );
  	  println( "<b>Total # of Files: </b>" . commify( $tot_files ) . "<br>" );
	  print ("<center><a href='javascript:window.history.back();'>Back to form</a></center>");
	  println ("<p></p>");
	}

	println( "</body></html>" );
	# ------------------------------------------------------#

	# Disconnect from database
	#$sth->finish();
	#$dbh->disconnect();
}

#----------------------------------------------------
# Display all of the information for each file of the given day
# 	specified by the day_id.
#----------------------------------------------------
sub displayFiles
{

	#my $main_query = shift;
	my $base_url = shift;
	my $base_cgi = shift;
	my $dbh = shift;
	my $date = `date`;
	chop($date);
	my $col1_id = 1;
	my $col2_id = 2; 
	my $col_id = $col1_id; 
	my $col;
	#my $dbh = connectToDatabase();

	# ----Read in the parameters----- #
	my $day_id = $main_query->param( "day_id" );
	my $time_frm = $main_query->param( "time_frm" );
	my $time_to = $main_query->param( "time_to" );
	#my @sectors = $main_query->param( "sector" );

	#my @sectors = @{resolveSectors( "displayFiles",$main_query->param('satellite_sector'))};
	my $sectors = $main_query->param('satellite_sector');
	#my @sectors = split(/,/, $str); 

	my $satellite = $main_query->param( "satellite" );
	my $resolution = $main_query->param( "resolution" );
	# ------------------------------- #
	
	# Boolean value, whether or not to show where there is 
	#   possible missing data 
	my $show_missing = 1;
	
	# Previous time - to see if there is missing data
	my $prev_tm = 0;
#hello
	# Start building the sql statement
	my $sql = "SELECT FileTable.day_id, FileTable.date, FileTable.time, ".
						"FileTable.size, FileTable.path, Sector.abrv, FileTable.sector_qc, Sector.satellite ".
						"FROM FileTable, Sector WHERE FileTable.sector=Sector.id and day_id=$day_id";

	# Add the to and from time to the sql statement
	if( $time_frm )
	{
		$sql = $sql . " and time > $time_frm";
	}
	if( $time_to )
	{
		$sql = $sql . " and time < $time_to";
	}

	if ( $sectors !~ /all/ )
	{
		$sql = $sql . " and Sector.id in ($sectors)";
	}


	# Add which sectors to display to the sql statement
#	if( $sectors[0] ne "all" && @sectors )
#	{
#		# Do not show where missing data might be
#		$show_missing = 0;
#
#		$sql = $sql . " and (";
#		my $size = @sectors;
#
#		# Add each sector to the sql statement
#		for( my $x = 0; $x < $size; $x++ )
#		{
#			$sql = $sql . " FileTable.sector=$sectors[$x]";
#			if( $x ne ($size - 1) )
#			{ $sql = $sql . " or"; }
#			else
#			{ $sql = $sql . ")"; }
#		}
#	}
	$sql = $sql . " ORDER BY time ASC";

	my $file_ref = $dbh->selectall_arrayref($sql);
	#print_error("zxcvxv: ".$file_ref->[0]->[0]);

	# Execute the sql statement
	#my $sth = $dbh->prepare( $sql );
	#$sth->execute();

	# Fetch the first row of the main_query - this in used for the heading below
	#my $arr_ref = $dbh->selectall_arrayref($sql);
	#my @row = $sth->fetchrow();
	#my @all_rows = @$arr_ref;
	#my $first_row = @all_rows[0];

	# -------------------------Print the table heading----------------------------- #
	#println( header() );
	print $main_query->header();
	#println( "<html><head><title>Query Results</title></head><body bgcolor=#FFFFFF>" );
	#print ( start_html(-title=>'Query Results',-script=>&fetchJS) );
	#print ( start_html(-title=>'Query Results',
	print $main_query->start_html(-title=>'Query Results',
                                        -script=>[
                                           { -language => 'JavaScript',
                                             -src=> "$base_url/data_retrieval.js"
                                           },
                                           { -language => 'JavaScript',
                                             -src=> "$base_url/query.js"
                                           }]);

	println ("<p><\p>");
	#print ( "<center><font size=+1><b>Day: </b>", getCalendar($row[1]) );
	print ( "<center><font size=+1><b>Day: </b>", getCalendar($first_row->[1]) );

	if( defined( $time_frm ) )
	{  print( "&nbsp;&nbsp;", substr( $time_frm, 0, 2 ), ":", substr( $time_frm, 2 , 2 ) ); }
	else
	{  print( "&nbsp;&nbsp;00:00" ); }	
	if( defined( $time_to ) )
	{  print( "-", substr( $time_to, 0, 2 ), ":", substr( $time_to, 2 , 2 ) ); }
	else
	{  print( "-23:59" ); }	

	print( "&nbsp;&nbsp;<font size=+1><b>Satellite: </b>$satellite</font>" );
	print( "&nbsp;&nbsp;<font size=+1><b>Resolution: </b>$resolution</font>" );

#	printSectors( \@sectors, $dbh );
	pprintSectors( $sectors, $dbh );

	print( "<br><font size=-1><b>Note: </b>The sectors of the datasets marked with an <font color=red><b>*</b></font> have a high" .
					" probablity being misidentified.<br>" );
	#println ("<form name='mss_retrieval' method='post' action='test.cgi'>");
        #println( "<input type='button' value='Select All' onClick=\"select_all()\" />" );
        #println( "<input type='submit' value='Retrieve Data' onClick=\"submit_me()\" />" );
        #println( "<input type=\"reset\" value=\"Reset\" onClick=\"total_size=0;\" />" );

 	#print $main_query->start_form(-name=>'test_form', -action=>'test.cgi', -onSubmit=>'javascript:submit_me()');
 #	print $main_query->start_form(-name=>'test_form', -onSubmit=>'javascript:submit_me()', -action=>'test.cgi');
 	#print $main_query->start_multipart_form(-name=>'data_retrieval_form', -onSubmit=>'javascript:submit_me()', -action=>'data_retrieval');
	#print $main_query->button(-name=>'select_all', -value=>'Select all', -onClick=>'javascript:select_all();');
	#print $main_query->submit(-name=>'submit', -value=>'Retrieve data', -onClick=>'javascript:submit_me();');
	#print $main_query->reset(-name=>'reset', -value=>'Reset');
 	#print $main_query->start_multipart_form(-name=>'data_retrieval_form', -action=>'data_retrieval', onSubmit=>'javascript:testit();');
 	#print $main_query->start_multipart_form(-name=>'data_retrieval_form', -action=>'data_retrieval');
 	print $main_query->start_multipart_form(-name=>'data_retrieval_form', -action=>'data_retrieval');
	#print $main_query->submit(-name=>'select_all', -value=>'Select all', -onClick=>"javascript:select_all();");
	#print $main_query->submit(-name=>'submit', -value=>'Retrieve data', -onClick=>'javascript:testit();');
	#print $main_query->submit(-name=>'retrieve_data', -value=>'Retrieve data', -onClick=>"$base_cgi/data_retrieval");
	print $main_query->submit(-name=>'select_all', -value=>'Select all', -onClick=>"javascript:select_all_files();return false;");
	print $main_query->submit(-name=>'retrieve_data', -value=>'Retrieve data', -onClick=>"javascript:get_data();");
	print $main_query->reset(-name=>'reset', -value=>'Reset');

	println( FileRecord->getTableHeader() );
	# -------------------------Finished with the table heading--------------------- #

	my $rec;
	my $index=-1;
	# Display each row of the main_query in the table
	#while( @row )
	#print_error("zxcvxv: ".$file_ref->[0]->[0]);
	#while( @row )
	my @xx = @$file_ref;
	foreach $row (@$file_ref)
	{
		# Create a new FileRecord
		$rec = FileRecord->new();
#		$rec->{day_id} = $row[0];
#		$rec->{date} = $row[1];
#		$rec->{time} = sprintf( "%4.4d", $row[2] );		
#		$rec->{size} = $row[3];		
#		$rec->{path} = $row[4];		
#		#$rec->{sector} = $row[5];
#		$rec->{satellite_sector} = $row[5];
#		$rec->{sector_qc} = $row[6];
		$rec->{day_id} = $row->[0];
		$rec->{date} = $row->[1];
		$rec->{time} = sprintf( "%4.4d", $row->[2] );		
		$rec->{size} = $row->[3];		
		$rec->{path} = $row->[4];		
		$rec->{sector} = $row->[5];
		$rec->{sector_qc} = $row->[6];

		my $sat = $row[7];

		# Determine the color of the row to display
		if( $col_id eq $col2_id ) 
		{ 
			$col_id = $col1_id; 
			$col = $col1{$sat};
		} 
		else 
		{ 
			$col_id = $col2_id; 
			$col = $col2{$sat};
		}

		# Print a yellow row if there is missing data between 
		#  this file and the previous file
		if( $rec->{time} - $prev_tm > 100 && $show_missing )
		{  print( getMissingData() ); }

		$prev_tm = $rec->{time};

		# Show the row in the table
		$index++;
		print( $rec->getHtmlRow( $col, $index ) );

		#@row = $sth->fetchrow();
	}

	# Print a yellow row if data is missing at the end
	if( $prev_tm < 2300 && $show_missing )
	{  print( getMissingData() ); }

	# Disconnect from database
	#$sth->finish();
	#$dbh->disconnect();

	# Finish off the html code
	#println( "</table></body></html>" );

	println( "</table>");
        #println( "<input type='submit' value='Retrieve Data' onClick=\"submit_me()\" />" );
	#println( "<input type='button' value='Add to List' onClick=\"add_to_list();\" />" );         	
        #println( "<input type=\"reset\" value=\"Reset\" />" );
	#println( "</form>" );
	print $main_query->end_form();
	print $main_query->end_html();

}

#----------------------------------------------------
# Return a data base handle connected to the MySQL database
#----------------------------------------------------
sub connectToDatabase
{
	return DBI->connect("DBI:mysql:database=$db_name;host=$host",
			    "$user", "$password", { RaiseError=>1} ) || die( "Unable to Connecto to database" );
}

#----------------------------------------------------
# Convert the calendar date in the YYYY-MM-DD format to a Julian
#		date in the YYYYJJJ format
#----------------------------------------------------
sub getJulian
{
	my $date = shift;
	my $year = substr( $date, 0, 4 );
	my $month = substr( $date, 4, 2 );
	my $day = substr( $date, 6, 2 );
	my $off = 0;
	my $jday;

	if( $year % 4 == 0 )
	{ $off = 1; }

	if( $month == 1 )
	{ $jday = $day; }
	elsif( $month == 2 )
	{ $jday = $day + 31; }
	elsif( $month == 3 )
	{ $jday = $day + 59 + $off;	}
	elsif( $month == 4 )
	{ $jday = $day + 90 + $off;	}
	elsif( $month == 5 )
	{ $jday = $day + 120 + $off;	}
	elsif( $month == 6 )
	{ $jday = $day + 151 + $off;	}
	elsif( $month == 7 )
	{ $jday = $day + 181 + $off;	}
	elsif( $month == 8 )
	{ $jday = $day + 212 + $off;	}
	elsif( $month == 9 )
	{ $jday = $day + 243 + $off;	}
	elsif( $month == 10 )
	{ $jday = $day + 273 + $off;	}
	elsif( $month == 11 )
	{ $jday = $day + 304 + $off;	}
	elsif( $month == 12 )
	{ $jday = $day + 334 + $off;	}

	return ( $year . sprintf( "%3.3d", $jday ) );	
}

#----------------------------------------------------
# Return a table row showing possible missing days exist
#----------------------------------------------------
sub getMissingDay
{
	return "<tr><td bgcolor=#FFFFFF height=5><font size=-3>&nbsp;</td><td bgcolor=#FFFF66 colspan=7 height=5 align=center><font size=-3>??? Missing Day(s) ???</td></tr>";
}

#----------------------------------------------------
# Return a table row showing possible missing data exists
#----------------------------------------------------
sub getMissingData
{
	return "<tr><td bgcolor=#FFFF66 colspan=5 height=5 align=center><font size=-3>??? Missing Data ???</td></tr>";
}

sub displayAllFiles
{
	#my $dbh = connectToDatabase();
	my $dbh = shift;
	my $base_cgi = shift;
	#print_warning("xxxx in displayAllfiles");
	#show_params("displayAllFiles", $main_query);
#show_params("displayAllFiles", $main_query, "satellite_sector");

	my $col1_id = 1;
	my $col2_id = 2; 
	my $col_id = $col1_id; 
	my $col;

	# Get the start and end time
	my $start = $main_query->param( "jdate_frm" );
	my $end = $main_query->param( "jdate_to" );
	#my $start = getStartDate();
	#my $end = getEndDate();
	#print_warning("asdf: ".$main_query->param('year_frm'));
	#print_warning("xxxx in displayAllFiles");
        #show_params("displayAllFiles", $main_query);

	# Get the start and end time

	#my $start_tm = getStartTime();
	#my $end_tm = getEndTime();
	my $start = $main_query->param( "time_frm" );
	my $end = $main_query->param( "time_to" );

	# Get the satellite and resolution
	my $sat = $main_query->param( "satellite" );
	my $res = $main_query->param( "resolution" );

	# Determine which sectors the user wants to display
	#my @sectors = $main_query->param( "sector" );
	#@sectors = resolveSectors( @sectors );
	#my @sectors = @{resolveSectors( $main_query->param('sector'))};
	#my @sectors = @{resolveSectors( "displayAllFiles",$main_query->param('satellite_sector'))};
	#my $sector_str = resolveSectors( "displayAllFiles",$main_query->param('satellite_sector'));
	print_error("exit displayAllFiles");
	# Start building the sql statement
	my $sql = "SELECT DayTable.date, DayTable.satellite, DayTable.resolution, FileTable.time, FileTable.size, Sector.abrv, " .
						"FileTable.path, Sector.satellite FROM DayTable, FileTable, Sector WHERE ".
						"DayTable.id=FileTable.day_id and Sector.id=FileTable.sector and DayTable.date>=$start and " .
						"DayTable.date<=$end";

	if( defined( $sat ) && $sat ne "All" )
	{
		$sql = $sql . " and DayTable.satellite=\"$sat\"";
	}
	if( defined( $res ) && $res ne "All" )
	{
		$sql = $sql . " and DayTable.resolution=\"$res\"";
	}

	if( @sectors && $sectors[0] ne "all" )
	{
		my $size = @sectors;
		$sql = $sql . " and (";
		for( my $x = 0; $x < $size; $x++ )
		{
			$sql = $sql . "FileTable.sector=$sectors[$x]";
			if( $x == $size - 1 )
			{
				$sql = $sql . ")";
			}
			else
			{
				$sql = $sql . " or ";
			}
		}
	}
	$sql = $sql . " ORDER BY DayTable.satellite ASC, DayTable.date ASC, FileTable.time ASC";

	my $sth = $dbh->prepare( $sql );
	$sth->execute();

	#print( header() );
	print $main_query->header();

	println( "<html><head><title>Query Results</title></head><body bgcolor=#FFFFFF>" );
	println( "<center><b><font size=+2>Mass Store Query Results</b></font><br>" );
	print( "<font size=+1><b>Start:</b> " . getCalendar( $start ) );

	if( defined( $start_tm ) )
	{  print( " ", substr( $start_tm, 0, 2 ), ":", substr( $start_tm, 2 , 2 ) ); }
	else
	{  print( " 00:00" ); }	

  print( "&nbsp;&nbsp;<b>End:</b> ". getCalendar( $end ) ); 

	if( defined( $end_tm ) )
	{  print( " ", substr( $start_tm, 0, 2 ), ":", substr( $start_tm, 2 , 2 ) ); }
	else
	{  print( " 23:59" ); }	

	println( "<b>&nbsp;&nbsp;Satellite:</b> $sat&nbsp;&nbsp;<b>Resolution:</b> $res</b></font>" );	
	printSectors( \@sectors, $dbh );

	print( AllRecord->getTableHeader() );

	my @row;
	my $tot_size= 0;
	my $tot_files = 0;
	while( (@row = $sth->fetchrow()) )
	{
		my $rec = AllRecord->new();
		$rec->{date} = $row[0];
		$rec->{satellite} = $row[1];
		$rec->{resolution} = $row[2];
		$rec->{time} = sprintf( "%4.4d", $row[3] );		
		$rec->{size} = $row[4];
		$rec->{sector} = $row[5];
		$rec->{path} = $row[6];

		my $sat = $row[7];
		# Determine the color of the row to display
		if( $col_id eq $col2_id ) 
		{ 
			$col_id = $col1_id; 
			$col = $col1{$sat};
		} 
		else 
		{ 
			$col_id = $col2_id; 
			$col = $col2{$sat};
		}
		print( $rec->getHtmlRow( $col ) );

		$tot_size+= $rec->{size};
		$tot_files++;
	}
	$sth->finish();
	#$dbh->disconnect();

	println( "</table>" );
	println( "<b>Total Disk Usage:</b>" . commify( $tot_size ) . " KB<br>" );
	println( "<b>Total # of Files:</b>" . commify( $tot_files ) . "<br>" );
	print( "</body></html>" );

}

sub pprintSectors
{

	my $sectors = shift;
	my $dbh = shift;

	if ( $sectors =~ /all/i ) {
		print( "<br><b><font size=+1>Sector(s): </b></font>All" );
	} else { 
		print( "<br><b><font size=+1>Sector(s): </b></font><font size=-1>" );
		my $sql = "SELECT name FROM Sector WHERE id in ($sectors)";
		my $name_ref = $dbh->selectall_arrayref($sql);
		foreach $name (@$name_ref) {
		  print( ",&nbsp;&nbsp;&nbsp", $name->[0] );	
		}
	}
	print( "</font>" );


}
sub printSectors
{
	#my @sectors = @_;
	my $sector_ref = shift;
	#my $dbh = connectToDatabase();
	my $dbh = shift;
	my @sectors = @$sector_ref;
	if( $sectors[0] =~ /all/i )
	{
		print( "<br><b><font size=+1>Sector(s): </b></font>All" );
	}
	else
	{	
		print( "<br><b><font size=+1>Sector(s): </b></font><font size=-1>" );
		my $sect_look = "SELECT name FROM Sector WHERE";
		my $size = @sectors;
		for( my $x = 0; $x < $size; $x++ )
		{
			$sect_look = $sect_look . " id=$sectors[$x]";
			if( $x != $size-1 )
			{
				$sect_look = $sect_look . " or";
			}
		}
		$sect_look = $sect_look . " ORDER BY name";
		my $sth2 = $dbh->prepare( $sect_look );
		print_error("asdfadsf: $sect_look");
		$sth2->execute();
		my @r = $sth2->fetchrow();

		if( @r ){ print( $r[0] );	}

		while( (@r = $sth2->fetchrow()) )
		{
			print( ",&nbsp;&nbsp;&nbsp", $r[0] );	
		}

		$sth2->finish();
	}
	print( "</font>" );

	#$dbh->disconnect()
}

sub showError
{
	my $message = shift;

	my $full_message = '';
	$full_message .= "<h1>Script Error</h1>\n";
	$full_message .= "<p>An error has occurred due to invalid input</p>\n";
	$full_message .= "<p>Reason: $message</p>\n";
	$full_message .= "Please Notify <a href=\"mailto:gstoss\@ucar.edu\">gstoss\@ucar.edu</a>.\n";

	print_error($full_message);


	#println( header() );
	#print $main_query->header();
	#println( "<html><head><title>SCRIPT ERROR</title></head><body>" );
	#println( "<h1>Script Error</h1>" );
	#println( "<p>An error has occurred due to invalid input</p>" );
	#println( "<p>Reason: $message</p>" );
	#println( "Please Notify <a href=\"mailto:gstoss\@ucar.edu\">gstoss\@ucar.edu</a>." );

	#println( "<h1>Script Error</h1>" );
	#println( "<p>An error has occurred due to invalid input</p>" );
	#println( "<p>Reason: $message</p>" );
	#println( "Please Notify <a href=\"mailto:gstoss\@ucar.edu\">gstoss\@ucar.edu</a>." );

	#println( "</body></html>" );

	exit();	
}

sub isDefined
{
	my $def = 1;
	foreach $var (@_)
	{
		$def = defined( $var );
		if( !$def ) { last; }
	}
	return $def;
}
sub xx 
{
	my $year = shift;
	my $month = shift;
	my $day = shift;
	my $status = 0;
	$status = 1 if ( $year =~ /[0-9]{4}/);
	$status = 1 if ( $month =~ /[0-9]{2}/);
	$status = 1 if ( $dat =~ /[0-9]{2}/);
	return $status;
}

sub countFiles
{
	my $id = shift;
	my $sect_ref = shift;
	my @sectors = @$sect_ref;
	my $size = @sectors;
	my $dbh = shift;

	my $sql = "SELECT COUNT(*) FROM FileTable WHERE day_id=$id and ( ";

	for( my $x = 0; $x < $size; $x++ )
	{
		$sql = $sql . "sector=$sectors[$x]";
		if( $x == $size - 1 )
		{ $sql = $sql . ")"; }
		else
		{ $sql = $sql . " or "; }
	}	

	my $sth = $dbh->prepare( $sql );
	$sth->execute();
	my @row = $sth->fetchrow();

	$sth->finish();

	if( defined( $row[0] ) )
	{ return $row[0]; }
	else
	{ return 0; }
}

#----------------------------------------------------
# Return the start date entered by user in the html form
#----------------------------------------------------
sub getStartDate
{
	# Get the start 
	my $start_yr = $main_query->param( "jdate_frm_yr" );
	my $start_dy = $main_query->param( "jdate_frm_dy" );

	my $start = $start_yr . $start_dy;
	my $start_date;

	# Check to see if user chose julian date or calendar date
	if( $start eq "YYYYJJJ" || !defined( $start_yr ) || !defined( $start_dy ) )
	{
		#my $year = $main_query->param( "year_frm" );
		my $year_value = $main_query->param('year_frm');
		my $year= (split(/;/, $year_value))[0];
		my $month = $main_query->param('month_frm');
		my $day = $main_query->param('day_frm');

		my $date;
		my $date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
		#my $date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
		$start_date = getJulian( $date );	

		# set the jdate_frm hidden parameter
		#$main_query->param(-name=>'jdate_frm', -default=>$start_date);

	}
	return $start_date;
		#print_warning("qwer: $year and $month and $day and $start");
#		if ( $status > 0) {
#		#print_warning("here i am: $status");
#		  $date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
#		  $date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
#		  $start = getJulian( $date );	
#		} else {
#		  showError("Start ASDFDate is not defined");
#		}
#		#print_error("Start date is not defined") if ( $status eq 'false');
#		#$date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
#		#$date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
#		#$start = getJulian( $date );	
#		if( isDefined( $year, $month, $day ) ) {
#			$date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
#		} else {
#		 	showError( "Start Date is not defined" ); 
#		}
	
#		$start = getJulian( $date );	
#}

#	return $start;
}

#----------------------------------------------------
# Return the end date the user entered in the html form
#----------------------------------------------------
sub getEndDate
{
	my $end_yr = $main_query->param( "jdate_to_yr" );
	my $end_dy = $main_query->param( "jdate_to_dy" );

	my $end = $end_yr . $end_dy;

	# Check to see if the user entered a julian date
	if( $end eq "YYYYJJJ" || !defined( $end_yr ) || !defined( $end_dy ) )
	{
		#my $year = $main_query->param( "year_to" );
		my $year_value = $main_query->param("year_to");
		my $year= (split(/;/, $year_value))[0];
		my $month = $main_query->param( "month_to" );
		my $day = $main_query->param( "day_to" );

		my $date;
		showError("End Date is not defined") if (isDefined($year,$month, $day) eq false);
		$date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
		$date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
		$end = getJulian( $date );	
		# if( isDefined( $year, $month, $day ) ) {
		#	$date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); 
		# } else {
		 #	showError( "End Date is not defined" ); 
		#}
		# if( isDefined( $year, $month, $day ) )
		#{	$date = $year . sprintf( "%2.2d", $month ) . sprintf( "%2.2d", $day ); }
		#else
		#{ showError( "DDate is not defined" ); }
		#{ showError( "end date is not defined" ); }

		$end = getJulian( $date );	

		$main_query->param(-name=>'jdate_to', -default=>$end);
	}

	return $end;
}

#----------------------------------------------------
# Return the start time entered by the user - returns
#  undef if the user did not specify a time
#----------------------------------------------------
sub getStartTime
{
	my $start_tm = undef;
	my $hr_start = $main_query->param( "hour_frm" );
	my $mn_start = $main_query->param( "minute_frm" );
	if( $hr_start ne "HH" && $mn_start ne "MM" )
	{
		$start_tm = $hr_start . $mn_start;	
	}
	return $start_tm;
}

#----------------------------------------------------
# Return the end time entered by the user - returns
#  undef if the user did not specify a time
#----------------------------------------------------
sub getEndTime
{
	my $end_tm = undef;
	my $hr_end = $main_query->param( "hour_to" );
	my $mn_end = $main_query->param( "minute_to" );
	if( $hr_end ne "HH" && $mn_end ne "MM" )
	{
		$end_tm = $hr_end . $mn_end;	
	}
	return $end_tm;
}
#----------------------------------------------------
# fetch the javascript code to check the request size
#----------------------------------------------------
sub fetchJS 
{

	my $js = '';

        $js .= "var total_size = 0;\n";

	$js .= "function ttestit() {\n";
	$js .= "   var w = window.open('', 'new_window', 'width=600,height=800');\n";
	$js .= "}\n";

        $js .= "function check_size(i) {\n";
	#$js .= "  alert('in check_size');\n";
        $js .= "  var max_size = $max_size;\n";
        $js .= "  var value = document.mss_retrieval.elements[i].value;\n";
        $js .= "  var arr = value.split(';');\n";
        $js .= "  /* convert KB to GB */\n";
        $js .= "  var size = arr[0] * .000001;\n";
        $js .= "  total_size += size;\n";
        #$js .= "  alert('size=' + size + ' total_size=' + total_size);\n";

        $js .= "  if ( total_size > max_size ) {\n";
        $js .= "     alert('maximum size of ' + max_size + ' GB reached...please submit request');\n";
        $js .= "     /* uncheck the element */\n";
        $js .= "     document.mss_retrieval.elements[i].checked = false;\n";
        $js .= "     return false;\n";
        $js .= "  }\n";
        $js .= "  return true;\n";
        $js .= "}\n";

	return $js;

}

#***********************************
# subroutines for form

sub get_scrolling_list {

  # create a scrolling list
  my $main_query = shift;
  my $name = shift;
  my $option_ref = shift;
  my $size = shift;
  #my $option_ref = ['test1', 'test2', 'test3'];
  #my $label_ref = {
  #  '1'=>'test1',
  #  '2'=>'test2',
  #  '3'=>'test3',
  #};
#  foreach $key (keys(%$option_ref)) {
#    $value = $option_ref->{$key};
#    #print_warning("xx: $key = $value");
#    $value =~ s/\:$//g;
#    #print_warning("adding $key:$value");
#    #$yy->{$value} = $key;
#    $values->{"$key".";"."$value"} = $key;
#  }
#  my @labels = sort(@$option_ref);
#			     -values=>\@labels,
#			     -labels=>$values,

#			     -values=>\@labels,
#			     -labels=>$values,
#			     -onChange=>$js_callback,
#	                     -default=>$year_ref->[0]);
  unshift(@$option_ref, "ALL");
  @$option_ref = map { uc $_ } @$option_ref; 

  my @options;
  foreach $opt (@$option_ref) {
    next() if ($opt =~ /UNKNOWN/);
    push(@options, $opt);
  }
  #my @labels = sort(@$option_ref);
  my @labels = sort(@options);
  push(@labels, "UNKNOWN");
  my $value_ref = {};
  foreach $label (@labels) {
    my ($satellite,$abrv) = split(/::/, $label);
    if ( $label =~ /(ALL|UNKNOWN)/i) {
      $value_ref->{$label} = $label;
      next();
    }
    ($value_ref->{$label} = "$abrv ($satellite)"); 
  }
  #$value_ref->{'ALL'} = 'ALL';

  return $main_query->scrolling_list(-name=>$name,
                                #-values=>$option_ref,
			     -values=>\@labels,
		             -labels=>$value_ref,
                             -default=>$option_ref->[0],
	                     -size=>$size,
	                     -multiple=>'true');

}
sub get_list {

  my $begin = shift;
  my $end = shift;
  my $num_digits = shift;
  my $increment = shift;

  # get a list of values (month, day..etc);
  my @arr;
  for ($i=$begin; $i<=$end; $i+=$increment) {
    push(@arr, sprintf("%02d", $i)) if ( $num_digits == 2 );
    push(@arr, sprintf("%03d", $i)) if ( $num_digits == 3 );
  }

  return \@arr;
  
}
sub get_satellite_popup {

  my $main_query = shift;
  my $name = shift;
  my $on_change = shift;
  my $default = shift;
  my $option_ref = shift;

  my $js_callback = "javascript:$on_change(this.form);";

  my @options = @$option_ref;

  unshift(@options, $default);
  my @labels;
  my %labels;
  foreach $opt (@options) {
    my $label = $opt;
    $label=~ s/G/GOES-/;
    $labels{$opt} = $label;
    #push(@labels, $label);
  }
  $option_ref = \@options;
  $label_ref = \%labels;

  return $main_query->popup_menu(-name=>$name,
			    #-values=>$option_ref,
			    -labels =>$label_ref,
			    -values=>$option_ref,
			    -onChange=>$js_callback,
	                    -default=>$option_ref->[0]);

}

sub get_year_popup {

  my $main_query = shift;
  my $name_from = shift;
  my $name_to = shift;
  #my $other_name_to = shift;
  my $on_change = shift;
  my $default = shift;
  my $option_ref = shift;

  # return the code for the popup menu
#  my $yy= {};
#			     $yy = {'test111'=>'test1',
#			               'test222'=>'test2',
#				       'test333'=>'test3'};

  my $js_callback = "javascript:$on_change(this.form, this.form.$name_from, this.form.$name_to, '$default');return 1;";
  #my $js_callback = "javascript:$on_change(this.form.$name_from, this.form.$name_to, '$default');return 1;";
  #my $js_callback = "javascript:$on_change(this.form.$name_from, this.form.$name_to, this.form.$other_name_to, '$default');return 1;";
  my $value;
  my $values = {};
  #foreach $key (keys(%$option_ref)) {
  #  print_warning("$key = ".$option_ref->{$key});
  #}
  #print_error("end");
  foreach $key (keys(%$option_ref)) {
    $value = $option_ref->{$key};
    #print_warning("xx: $key = $value");
    $value =~ s/\:$//g;
    #print_warning("adding $key:$value");
    #$yy->{$value} = $key;
    $values->{"$key".";"."$value"} = $key;
  }
  #my @labels = sort(keys(%$values));
  my @labels = reverse(sort(keys(%$values)));
  unshift(@labels, "YYYY");


  if ( $on_change ne '') {
  $html = $main_query->popup_menu(-name=>$name_from,
  			     #-values=>$year_ref,
  			     #-values=>{'test11'=>'test1',
  			     #          'test22'=>'test2',
  			#	       'test33'=>'test3'},
  			     -values=>\@labels,
  			     -labels=>$values,
  			     -onChange=>$js_callback,
  	                     -default=>$year_ref->[0]);
  } else {
    $html = $main_query->popup_menu(-name=>$name_from,
  			     -values=>\@labels,
  			     -labels=>$values,
  	                     -default=>$year_ref->[0]);
  }
  return $html;

}


sub get_popup {

  my $main_query = shift;
  my $name_from = shift;
  my $name_to = shift;
  my $on_change = shift;
  my $default = shift;
  my $option_ref = shift;

  # return the code for the popup menu
  my @options = @$option_ref;
  unshift(@options, $default);
  $option_ref = \@options;
#  if ( grep(/:/, @$option_ref) > 0 ) {
#    # processing the year popup
#    my $label_ref = {};
#    my %satellite_hash;
#    # first, get a list of satellites
#    foreach $value (sort(@$option_ref)) {
#      my ($satellite,$year) = split(/:/, $value);
#      if ( !defined($satellite_hash{$satellite}) ) {
#        $satellite_hash{$satellite} = '';
#      } else {
#        $satellite_hash{$satellite} .= "$year:";
#      }
#    }
#    foreach $key (sort keys(%satellite_hash)) {
#      $label_ref->{uc($key)} = $satellite_hash{$key};
#    }
#    foreach $xx (keys(%$label_ref)) {
#      #print_warning("zxcv: $xx = ".$label_ref->{$xx});
#    }
#    my $js_callback = "javascript:$on_change(this.form.$name_from, this.form.$name_to, '$default');return 1;";
#    #my @xx = sort keys(%$label_ref);
#    my @list = sort keys(%$label_ref);
#    my $default = pop(@list);
#    unshift(@list,$default);
#    $html = $main_query->popup_menu(-name=>$name_from,
#    #                        -labels=>$label_ref,
#			    #-values=>$option_ref,
#			    -values=>\@list,
#			    -onChange=>$js_callback,
#	                    -default=>$option_ref->[0]);
#    return $html;
#  }


  if ( $on_change ne '' ) {
    my $js_callback = "javascript:$on_change(this.form.$name_from, this.form.$name_to, '$default');return 1;";
    $html = $main_query->popup_menu(-name=>$name_from,
			    -values=>$option_ref,
			    -onChange=>$js_callback,
	                    -default=>$option_ref->[0]);
  } else {
    $html = $main_query->popup_menu(-name=>$name_from,
			    -values=>$option_ref,
			    -onChange=>$js_callback,
	                    -default=>$option_ref->[0]);
  }

  return $html;



#  return $main_query->popup_menu(-name=>$name_from,
#			    -values=>$option_ref,
#			    -onChange=>$js_callback,
#	                    -default=>$option_ref->[0]);
#
}
sub print_error {
  local($msg) = @_;
  print "Content-Type: text/html\n\n";
  print "<HTML><HEAD><TITLE>Form Error</TITLE>\n";
  #print "<h1>ERROR: $msg</h1>\n";
  print "ERROR: $msg<br>\n";
  print "</BODY></HTML>\n";
  die;
}

sub print_warning {
  local($msg) = @_;
  print "Content-Type: text/html\n\n";
  print "<HTML><HEAD><TITLE>Form Error</TITLE>\n";
  #print "<h1>WARNING: $msg</h1>\n";
  print "WARNING: $msg<br>\n";
  print "</BODY></HTML>\n";
}

sub print_form {
  
  my $satellite_ref = shift;
  my $resolution_ref = shift;
  my $sector_ref = shift;
  my $year_ref = shift;
  my $day_ref = shift;
  my $month_ref = shift;
  my $julian_day_ref = shift;
  my $hour_ref = shift;
  my $minute_ref = shift;
  my $base_url = shift;
  my $base_cgi = shift;
  my $main_query = shift;
  # create the meta tags that store
  # the year and sector information
  my $meta_arr;
  #foreach $year (keys(%$year_ref)) {
  @sorted_year = reverse(sort(keys(%$year_ref)));
  foreach $year (@sorted_year) {
    $meta_ref->{"year::$year"} = $year_ref->{$year};
  }
  foreach $sector (@$sector_ref) {
    $meta_ref->{"sector::$sector"} = '';
  }

  my $js_url = "$base_url/query.js";
  my $data_url = "$base_url/data_retrieval.js";
  print $main_query->header("EOL Satellite Query");
  print $main_query->start_html(-title=>'EOL Satellite Query', 
                           -bgcolor=>'#FFFFFF',
                           -style=>{-src=>"$base_url/css/query.css"},
			   -script=>[{ -src=> $js_url
                                    },
                                    { -src=> $data_url
                                    }],
			   -meta=>$meta_ref,
  			   -onLoad=>'javascript:resetForm();');
  
  #print $main_query->center();
  my $method = "POST";
  my $action = "$base_cgi/".basename($0);
  my $form_name = "queryform";
  print $main_query->startform(-method=>$method,
  			  -action=>$action,
                          -name=>$form_name,);
  
  # header
  print $main_query->br();
  print "<center>\n";
  print "<table id='head'>\n";
  print "  <tr><td>\n";
  print $main_query->h2("NCAR/EOL HPSS Satellite Data Query");
  print "</td></tr>\n";
  print "</table>\n";
  print "</center>\n";
  print "<div id='margin'>\n";
  #print $main_query->br();
  print "<div id='steps'>Step 1: Choose satellite</div>\n";
  print "<table id='outside'>\n";
  print "  <tr>\n";
  print "  <td>\n";
  #print "    <table id='inside' border='1'>\n";
  print "    <table id='inside'>\n";
  print "      <tr>\n";
  print "      <td>Satellite:</td>\n";
  print "      <td>Resolution:</td>\n";
  print "      <td>Sector:</td>\n";
  print "      </tr>\n";
  print "      <tr>\n";
  print "      <td>\n";
  print get_satellite_popup($main_query,'satellite', 'setSectorAndYear', 'ALL', $satellite_ref);
  print "      </td>\n";
  #print "    </tr>\n";
  #print "    <tr>\n";
  #print "      <td><b>Resolution:</b></td>\n";
  print "      <td>\n";
  print get_popup($main_query,'resolution', '', '', 'ALL', $resolution_ref);
  print "      </td>\n";
  print "      <td>\n";
  print get_scrolling_list($main_query, 'satellite_sector', $sector_ref, 7);
  print "      </td>\n";
  print "      </tr>\n";
  print "    </table>\n";
  print "  </td>\n";
  print "  <td>\n";
  #print "    <table id='inside'>\n";
  #print "      <tr>\n";
  #print "      <td>\n";
  #<select name=sector size=7 multiple onChange="checkSelection( this.form )">
  #   print $main_query->scrolling_list(-name=>'list_name',
  #                                -values=>['eenie','meenie','minie','moe'],
  #                                -default=>['eenie','moe'],
  #	                        -size=>5,
  #	                        -multiple=>'true',
  #                                -labels=>\%labels);
  #
  #print get_scrolling_list($main_query, 'sector', $sector_ref, 7);
  #print get_scrolling_list($main_query, 'satellite_sector', $sector_ref, 7);
  #print "      </td>\n";
  #print "      </tr>\n";
  #print "    </table>\n";
  print "  </td>\n";
  print "</table>\n";
  print $main_query->br();
  #print "<hr>\n";
  #print $main_query->br();
  print "<div id='steps'>Step 2: Choose date/time or julian date)</div>\n";
  print "<table id='outside'>\n";
  print "  <tr>\n";
  print "  <td>\n";
  print "    <table id='inside'>\n";
  #print "      <tr><td colspan=4><div id='center_text'>Begin (choose date/time or julian date):</div></td></tr>\n";
  #print "      <tr><td colspan=4><div id='center_text'>Begin:</div></td></tr>\n";
  print "      <tr>\n";
  print "      <td>Begin date/time:</td>\n";
  print "      <td>\n";
  # from year
  print get_year_popup($main_query,'year_frm', 'year_to', 'resetJulianDate', 'YYYY', $year_ref);
  # from month 
  print get_popup($main_query,'month_frm', 'month_to', 'setCheckBox', 'MM', $month_ref);
  # from day 
  print get_popup($main_query,'day_frm', 'day_to', 'setCheckBox', 'DD', $day_ref);
  # from hour
  print "&nbsp;&nbsp;\n";
  print get_popup($main_query,'hour_frm', 'hour_to', 'setCheckBox', 'HH', $hour_ref);
  # from minute 
  print get_popup($main_query,'minute_frm', 'minute_to', 'setCheckBox', 'MM', $minute_ref);
  print "      </td>\n";
  print "      <td>\n";
  print "    </tr>\n";
  #print "      <td><b>&nbsp;&nbsp;or Julian Date:</b></td>\n";
  print "      <td>Begin julian date:</td>\n";
  print "      <td>\n";
  print get_year_popup($main_query,'jdate_frm_yr', 'jdate_to_yr', 'resetDate', 'YYYY', $year_ref);

  # julian from day 
  print get_popup($main_query,'jdate_frm_dy', 'jdate_to_dy', 'setCheckBox', 'JJJ', $julian_day_ref);
  print "      </td>\n";
  print "      </tr>\n";
  print "    </table>\n";
  print "  </td>\n";
  print "  <td>\n";
  print "    <table id='inside'>\n";
  print "      <tr><td colspan=4><div id='center_text'>End (choose date/time or julian date):</div></td></tr>\n";
  print "      <tr>\n";
  print "      <td>End date/time:</td>\n";
  print "      <td>\n";
  print get_year_popup($main_query,'year_to', 'year_frm', '', 'YYYY', $year_ref);
  # to month
  print get_popup($main_query,'month_to', 'month_frm', '', 'MM', $month_ref);
  # to date 
  print get_popup($main_query,'day_to', 'day_frm', '', 'DD', $day_ref);
  print get_popup($main_query,'hour_to', 'hour_frm', '', 'HH', $hour_ref);
  print "&nbsp;&nbsp;\n";
  print get_popup($main_query,'minute_to', 'minute_frm', '', 'MM', $minute_ref);
  print "      </td>\n";
  print "      </tr>\n";
  print "      <tr>\n";
  print "      <td>End julian date:</td>\n";
  print "      <td>\n";
  print get_year_popup($main_query,'jdate_to_yr', 'jdate_frm_yr', '', 'YYYY', $year_ref);
  print get_popup($main_query,'jdate_to_dy', 'jdate_frm_dy', '', 'JJJ', $julian_day_ref);
  print "      </tr>\n";
  print "    </table>\n";
  print "  </td>\n";
  print "</table>\n";
  #print "<hr>\n";
  print $main_query->br();
  print "<div id='steps'>Step 3: asdf</div>\n";
  print "<table id='outside'>\n";
  print "  <tr>\n";
  print "  <td>\n";
  print "    <table id='inside'>\n";
  print "      <tr>\n";
  print "       <td align='center'><u>Number of files</u></td>\n";
  print "      </tr>\n";
  print "      <tr>\n";
  print "        <td>Min. Files/Day:&nbsp;\n";
  print $main_query->textfield(-name=>'min_files',-size=>5, -default=>0);
  print "        </td>\n";
  print "      </tr>\n";
  print "      <tr>\n";
  print "        <td>Max. Files/Day:&nbsp;\n";
  print $main_query->textfield(-name=>'max_files',-size=>5, -default=>'ALL');
  print "        </td>\n";
  print "      </tr>\n";
  print "    </table>\n";
  print "  </td>\n";
  print "  <td>\n";
  print "    <table id='inside'>\n";
  print "      <tr>\n";
  #print "       <td align='center'><b><u>Missing data</u></b></td>\n";
  print "       <td align='center'><u>Missing data</u></td>\n";
  print "      </tr>\n";
  print "      <tr>\n";
  print "        <td>\n";
  my $labels = {'all'=>'All Matches', 
          'missing'=>'Days with missing data only', 
          'no_missing'=>'Days without missing data only'};
  #print $main_query->b();
  print $main_query->radio_group(-name=>'miss_data', -values=>['all','missing', 'no_missing'], -default=>'all', -linebreak=>'true', -labels=>$labels);
  print "        </td>\n";
  print "      </tr>\n";
  print "    </table>\n";
  print "  </td>\n";
  print "  <td>\n";
  print "    <table id='inside'>\n";
  print "      <tr>\n";
  print "        <td align='center'><u>Display type</u></td>\n";
  print "      </tr>\n";
  print "      <tr>\n";
  print "        <td>\n";
  $labels = {'by_day'=>'Show Files by Day', 
             'all'=>'Show All Files in One List'};
  #print $main_query->b();
  print $main_query->radio_group(-name=>'dis_type', -values=>['by_day','all'], -default=>'by_day', -linebreak=>'true', -labels=>$labels);
  print "        </td>\n";
  print "      </tr>\n";
  print "    </table>\n";
  print "  </td>\n";
  print "  </tr>\n";
  print "</table>\n";
  print $main_query->br();
  print "<table id='outside'>\n";
  print "  <tr>\n";
  print "    <td>\n";
  #print $main_query->hidden(-name=>'jdate_frm');
  #print $main_query->hidden(-name=>'jdate_to');
  #print $main_query->submit(-name=>'Action', -value=>'Submit Query', -onClick=>"return validateForm(this.form)");
  print $main_query->submit(-name=>'Action', -value=>'Submit', -onClick=>"return validateForm(this.form)");
  #print $main_query->reset(-name=>'Action', -value=>'Submit', -onClick=>"return resetForm(this.form)");
  print $main_query->reset(-name=>'Reset', -value=>'Reset', -onClick=>"return javascript:resetForm();");
  #print $main_query->submit(-name=>'Action', -value=>'Submit Query', -onClick=>"javascript:validateForm(this.form)");
  #print $main_query->submit(-name=>'Action', -value=>'Submit Query', -onClick=>"javascript:validateForm(this.form)");
  print "    </td>\n";
  print "  </tr>\n";

  print "</table>\n";
#<input type=submit name="Action" value="Submit Query" onClick="return validateForm( this.form )"></input>

#<input type=reset value="Reset" onClick="resetForm()"></input>
  print "<hr>\n";
  print "NOTE: You do not have to fill out all of the fields. Selecting a satellite, begin and end date (no Time needed) is enough.";
  print "<p></p>\n";
print "Comments to: <a href=\"mailto:gstoss\@ucar.edu\">gstoss\@ucar.edu</a>&nbsp;&nbsp;&nbsp;&nbsp;";
print "<a href='$base_url/notes.html'>Notes/Documentation</a>\n";

  print $main_query->end_html();
  
}

sub process_form {
  
  #--main----------------------------------------------
  # The base directory 
  $main_query = shift;
  my $base_url = shift;
  my $base_cgi = shift;
#  my $my_url = shift;
#  my $main_query_form = shift;
  my $max_size = shift;
  #my $dbh = shift;
  $dbh = shift;

  #my $bottom_html = shift;
  #my $bottom_html = shift;
  my $bottom_html  = "$base_url/bottom.html";

  # Hash table of the possible actions this script can perform.
  #   These are set by either a button value= tag in an html
  #   form or be setting Action=... in the url.
  #my %action = ( "Submit Query" => \&checkQuery,
  #								"getdaily" => \&displayDaily,
  #								"getfiles" => \&displayFiles );
  #my %action = ( "Submit Query" => \&checkQuery($base_cgi),
  #	         "getdaily" => \&displayDaily($dbh),
 #		 "getfiles" => \&displayFiles($dbh));
  #print_warning("xxxx in process_form: $main_query");
  #my %action = ( "Submit Query" => \&checkQuery($base_cgi, $bottom_html, $dbh),
  #	         "getdaily" => \&displayDaily($main_query, $base_cgi),
 #		 "getfiles" => \&displayFiles($main_query, $base_cgi));
  my %action = ( "Submit" => \&checkQuery,
  	         "getdaily" => \&displayDaily,
  	         "getfiles" => \&displayFiles);
  # Get the action to perform
  my $act = $main_query->param( "Action" );

  #$action{$act}->($base_cgi,$bottom_html, $dbh) if ($act eq 'Submit Query');

  #my $sub = $action{$act};
  #&$sub($base_cgi,$bottom_html,$dbh);

  
  # Do the requested action
  if( defined( $action{$act} ) )
  {
        $action{$act}->($base_cgi,$bottom_html, $dbh) if ($act eq 'Submit');
        #$action{$act}->($main_query, $base_cgi) if ($act eq "getdaily");
        $action{$act}->($base_url,$base_cgi) if ($act eq "getdaily");
        $action{$act}->($base_url, $base_cgi,$dbh) if ($act eq "getfiles");
	#$action{$act}->();
  }
  else
  {
  	showError( "Undefined action." );
  }
}
sub show_params() {


  my $sub = shift;
  my $query = shift;
  my $param_name = shift;
  my @param_list = $query->param();
  my $txt = '';
  if ( $param_name !~ /all/i ) {
    $txt .= "\t$param = ".$query->param($param_name)."<br>";
  } else {
    foreach $param (@param_list) {
      $txt .= "\t$param = ".$query->param($param)."<br>";
    }
  }
  print "Content-Type: text/html\n\n";
  print "<HTML><HEAD><TITLE>show params</TITLE>\n";
  print "<h3>Showing params for $sub</h3>\n";
  print "$txt";
  print "</BODY></HTML>\n";

}
1;
