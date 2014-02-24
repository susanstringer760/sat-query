#!/usr/bin/perl

use IO::Handle;

sub connectToDB()
{

  my $db_name = shift;
  my $user = shift;
  my $password = shift;
  my $host = shift;

  return DBI->connect( "DBI:mysql:database=$db_name;
                       host=$host",
                       "$user",
                       "$password",
		       { PrintError => 0,
		         PrintWarn => 1,
			 RaiseError => 1,
			 HandleError => \&dbiErrorHandler,
		       } ) || die( "Unable to Connect to database" );

}

sub dbiErrorHandler {

  $error = shift;
  print "ERROR: $error\n";
  exit();

  return 1;

}

sub getYearListFromHpss  
{
        my $hpss_base_dir = shift;
        #my $resolution = shift;
	my $hsi_exe = shift;
	my $satellite_ref = shift;
	my $resolution_ref = shift;
#	my $stderr_fname = shift;

#	my $hsi_exe = hsiExe();
#	my $satellite_ref = getSatelliteListFromHpss($hpss_base_dir);  
#	my $resolution_ref = satelliteResolution();

	# the current year
	my $current_year = `date +%Y`;
	chop($current_year);

	my @hsi_output;
	my $year_hash_ref;
	foreach $satellite (@$satellite_ref) {
	  foreach $resolution (@$resolution_ref) {
	    $resolution = lc($resolution);
	    my $full_path = "$hpss_base_dir/$satellite/$resolution";
	    #my $cmd = "$hsi_exe -q ls -P $full_path 2>&1";
	    my $cmd = "$hsi_exe -q ls -P $full_path";
	    my ($results,$status) = executeCommand($cmd);
	    if ($status != 0 ) {
	      #printError($cmd, $stderr_fname, $results);
	      printError($cmd, $results);
	      next();
	    }
	    my @hsi_output = split(/\n/, $results);
            #@hsi_output = `$cmd`;
	    foreach $output (@hsi_output) {
	      #chop($output);
	      $output =~ s/^\s+//g;
	      my ($type,$full_path) = split(/\s+/, $output);
	      my $year = basename($full_path);
	      next if ( $year !~ /(\d{4})/);
	      next if ( $year > $current_year );

	      $year_hash_ref->{$satellite}->{$year} = '';
	    }
	  }
	}

	return $year_hash_ref;

}

sub getFileListFromHpss
{

  # get a list of files from the hpss (long listing)

  my $hsi_exe = shift;
  my $day_path = shift;

  my $cmd = "$hsi_exe ls -l $day_path";

  my ($results,$status) = executeCommand($cmd);
  if ($status != 0 ) {
    #printError($cmd, $stderr_fname, $results);
    printError($cmd, $results);
    return -1;
  }
  my @hsi_output = split(/\n/, $results);
  my @list_of_files;
  my %file_hash;
  # stuff each file into a hash so we can sort
  foreach $output (@hsi_output) {
    next if ( $output !~ /^[rwx\-]/ ); 
    my @tmp = split(/\s+/, $output);
    my $fname = pop(@tmp);
    $file_hash{$fname} = $output;
    #push(@list_of_files, $fname);
    #push(@list_of_files, $output);
  }
  foreach $fname (sort(keys(%file_hash))) {
    push(@list_of_files, $file_hash{$fname});
  }
  return \@list_of_files;

#  foreach $output (@hsi_output) {
#    next if ( $output !~ /^[rwx\-]/ ); 
#    #my @tmp = split(/\s+/, $output);
#    #my $fname = pop(@tmp);
#    #push(@list_of_files, $fname);
#    push(@list_of_files, $output);
#  }
#  @list_of_files = sort(@list_of_files);

  return \@list_of_files;

}


sub getSatelliteListFromHpss  
{
        my $hpss_base_dir = shift;
	my $hsi_exe = shift;
	#my $stderr_fname = shift;

        #my $cmd = "$hsi_exe -q ls -P $hpss_base_dir 2>&1";
        my $cmd = "$hsi_exe -q ls -P $hpss_base_dir";
	my ($results,$status) = executeCommand($cmd);
	if ($status != 0 ) {
	 # printError($cmd, $stderr_fname, $results);
          printError($cmd, $results);
	  return -1;
	}
	my @hsi_output = split(/\n/, $results);

        #my @output = `$cmd`;

	my @satellite_list;
        #foreach $entry (@output) {
        #        chop($entry);
        foreach $entry (@hsi_output) {
		my $satellite = basename($entry);
		push(@satellite_list, $satellite) if ($satellite =~ /g(\d{2})/);
        }

        return \@satellite_list;

}

sub ggetDayListFromHpss {

	my $satellite = shift;
	$satellite = lc($satellite);
	my $resolution_ref = shift;
	my $year = shift;
	my $hpss_base_dir = shift;
	my $hsi_exe = shift;
	#my $stderr_fname = shift;

	my $day_ref = {};

	foreach $resolution (@$resolution_ref) {

	  $resolution = lc($resolution);
	  my $year_dir = "$hpss_base_dir/$satellite/$resolution/$year";

          my $cmd = "$hsi_exe -q ls -P $year_dir";
	  my ($results,$status) = executeCommand($cmd);
	  if ($status != 0 ) {
	    #printError($cmd, $stderr_fname, $results);
	    printError($cmd, $results);
	    next();
	  }
	  my @hsi_output = split(/\n/, $results);
	  foreach $output (@hsi_output) {
            next if ($output !~ /DIRECTORY/);
            my ($dir,$full_path) = split(/\s+/, $output);
            push (@list_of_days, $full_path);
          } # end foreach $output
          my $sorted_list_ref = sortFilesByDay(\@list_of_days);

	  #$day_ref->{$satellite}->{$resolution} = \@list_of_days;
	  $day_ref->{$satellite}->{$resolution} = $sorted_list_ref;

        } # end foreach $resolution

	return $day_ref;

#          my $list_command= "$hsi_exe -q ls -P \"$year_dir\" 2>&1 |";
#  
#          open(CMD, $list_command) || die("\nCannot get HPSS directory listing of $base_dir\n\n");
#          my @list_of_days = ();
#          while (<CMD>) {
#                  chop;
#                  next if !/DIRECTORY/;
#                  my ($dir,$full_path) = split(/\s+/, $_);
#                  push (@list_of_days, $full_path);
#          }
#          close(CMD);
#	  $day_ref->{$satellite}->{$resolution} = \@list_of_days;
#
#	}
#
#        return $day_ref;

}

sub getDayListFromHpss {

	my $satellite = shift;
	$satellite = lc($satellite);
	my $resolution = shift;
	my $year = shift;
	my $hpss_base_dir = shift;
	my $hsi_exe = shift;
	#my $stderr_fname = shift;

	my $day_ref = {};

	$resolution = lc($resolution);
	my $year_dir = "$hpss_base_dir/$satellite/$resolution/$year";

        my $cmd = "$hsi_exe -q ls -P $year_dir";
	my ($results,$status) = executeCommand($cmd);
	if ($status != 0 ) {
	  printError($cmd, $results);
	  return "ERROR: unable to execute $cmd\n";
	  exit();
	  #next();
	}
	my @hsi_output = split(/\n/, $results);
	foreach $output (@hsi_output) {
          next if ($output !~ /DIRECTORY/);
          my ($dir,$full_path) = split(/\s+/, $output);
          push (@list_of_days, $full_path);
        } # end foreach $output
        my $sorted_list_ref = sortFilesByDay(\@list_of_days);

	$day_ref->{$satellite}->{$resolution} = $sorted_list_ref;

	return $day_ref;

}

sub sortFilesByDay {

        my $list_of_days_ref = shift;

        my (%hash, $day);

        foreach $day (@$list_of_days_ref) {
                $day =~ /day(\d{1,3})/;
                my $num = $1;
                $num =~ s/^[0]{1,2}//g;
                $hash{$num} = $day;
        }
        my @sorted_arr = sort { $a <=> $b } keys(%hash);
        my @list_of_days;
        foreach $day (@sorted_arr) {
          push(@list_of_days, $hash{$day});
        }

        return \@list_of_days;

}


sub getSectorListFromDB {

  # get a list of sectors 
  # from db

  my $dbh = shift;

  #my $sql = "select distinct name,abrv,satellite from Sector order by abrv";
  #my $sql = "select distinct name,abrv,satellite from Sector order by satellite";
  my $sql = "select distinct id,abrv,satellite from Sector order by satellite";
  my @sectors;
  my @rows = @{$dbh->selectall_arrayref($sql)};
  my %sector_hash;
  if ( $#rows >= 0 ) {
    for ($i=0; $i<=$#rows;$i++) {
      #my $sector = $rows[$i]->[0];
      #my $name = $rows[$i]->[0];
      my $sector_id = $rows[$i]->[0];
      my $abrv = $rows[$i]->[1];
      my $sector_satellite = $rows[$i]->[2];
      $sector_satellite =~ /(G\d{2})(.*)/;
      my $satellite = $1;
      #my $key = "$abrv"."::"."$satellite";
      my $key = "$satellite"."::"."$abrv";
      $sector_hash{$key} = '';
      #$sector_hash{"$abrv ($satellite)"} = '';
      #push(@sectors, "$name,$abrv,$satellite");
    }
  }
  @sectors = sort(keys(%sector_hash));

  return \@sectors;
  
}

sub ggetSectorListFromDB {

  # get a list of sectors 
  # from db

  my $dbh = shift;

  my $sql = "select distinct abrv from Sector order by abrv";
  my @sectors;
  my @rows = @{$dbh->selectall_arrayref($sql)};
  if ( $#rows >= 0 ) {
    for ($i=0; $i<=$#rows;$i++) {
      my $sector = $rows[$i]->[0];
      push(@sectors, $sector);
    }
  }

  return \@sectors;
  
}


sub getSatelliteListFromDB {

  # get a list of satellites
  # from db

  my $dbh = shift;

  my $sql = "select distinct satellite from DayTable order by satellite";
  my @satellites;
  my @rows = @{$dbh->selectall_arrayref($sql)};
  if ( $#rows >= 0 ) {
    for ($i=0; $i<=$#rows;$i++) {
      my $satellite = $rows[$i]->[0];
      push(@satellites, $satellite);
    }
  }
  # reverse sort
  @satellites = reverse(sort(@satellites));

  return \@satellites;

}

sub getYearListFromDB {

  # get a list of years 
  # from db
  my $dbh = shift;
  my $satellite_to_find = shift;

  my $sql = "select distinct date,satellite from DayTable order by date";
  my @years;
  my @rows = @{$dbh->selectall_arrayref($sql)};
  my $year_hash;
  if ( $#rows >= 0 ) {
    # initialize year hash
    for ($i=0; $i<=$#rows;$i++) {
      my $jdate = $rows[$i]->[0];
      $jdate =~ /(\d{4})(.*)/;
      my $year = $1;
      my $satellite = $rows[$i]->[1];
      $satellite = uc($satellite);

      #$year_hash{"$satellite:$year"} = '';
      if ( !defined($year_hash->{$year})) {
        $year_hash->{$year} = '';
      } else {
        if ( $year_hash->{$year} !~ /$satellite/ ) {
          $year_hash->{$year} .= "$satellite:";
        }
      }

#      if ( $satellite_to_find =~ /all/i ) {
#        $year_hash{$year} = '';
#      } else {
#        next if ( $satellite !~ /$satellite_to_find/i );
#        $year_hash{$year} = '';
#      } 
    }
  }
  #foreach $year(keys(%$year_hash)) {
  #  $year_hash->{$year} = "$year"."::".$year_hash->{$year};
  #}
return $year_hash;

  @years = sort(keys(%year_hash));
  #@years = sort { $a <=> $b } keys(%year_hash); # numerical sort

  return \@years;

}



sub ggetYearListFromDB {

  # get a list of years 
  # from db
  my $dbh = shift;

  my $sql = "select distinct date from DayTable order by date";
  my @years;
  my @rows = @{$dbh->selectall_arrayref($sql)};
  my $year_hash;
  if ( $#rows >= 0 ) {
    for ($i=0; $i<=$#rows;$i++) {
      my $jdate = $rows[$i]->[0];
      $jdate =~ /(\d{4})(.*)/;
      my $year = $1;
      $year_hash{$year} = '';
    }
  }
  @years = sort { $a <=> $b } keys(%year_hash); # numerical sort

  return \@years;

}




#sub getSectorFromDB {
#
#  my $dbh = shift;
#
#  # get a list of satellites
#  my $satellite_ref_arr = [];
#  my $satellite_ref = getSatelliteListFromDB($dbh);
#
#  my $sql = "select distinct abrv, satellite from Sector order by satellite";
#  my @sectors;
#  my @rows = @{$dbh->selectall_arrayref($sql)};
#  my ($abrv, $satellite);
#  my $sector_hash_ref = {};
#  # initialize the hash
#  foreach $satellite (@$satellite_ref) {
#    $satellite =~ s/(G\d{2})(.*)/$1/g;
#    $satellite =~ s/^G/GOES-/g;
#    $sector_hash_ref->{$satellite} = [];
#  }
#
#  if ( $#rows >= 0 ) {
#    for ($i=0; $i<=$#rows;$i++) {
#      my $abrv = $rows[$i]->[0];
#      my $satellite = $rows[$i]->[1];
#      next if ( $satellite =~ /none/i );
#      $satellite =~ s/(G\d{2})(.*)/$1/g;
#      my $full_satellite_name = $1;
#      $full_satellite_name =~ s/^G/GOES-/g;
#      #my $value = "$abrv ($satellite)";
#      my $value = "$abrv:$satellite";
#      my $arr_ref = $sector_hash_ref->{$full_satellite_name};
#      #print "$value: $#$arr_ref\n";
#      my $arr_length = $#{$sector_hash_ref->{$full_satellite_name}}+1;
#      $sector_hash_ref->{$full_satellite_name}->[$arr_length] = $value;
#    }
#  }
#
#  # remove duplicate entries
#  foreach $satellite (keys(%$sector_hash_ref)) {
#    my $arr_ref = $sector_hash_ref->{$satellite};
#    my %tmp_hash;
#    foreach $sector (@$arr_ref) {
#      $tmp_hash{$sector} = '';
#    }
#    $sector_hash_ref->{$satellite} = [];
#    my @keys = sort(keys(%tmp_hash));
#    $sector_hash_ref->{$satellite} = \@keys;
#  }
#
#  return $sector_hash_ref;
#
#}
sub getDBNumFiles {

  # get the number of files for a given day
  my $dbh = shift;
  my $day_path = shift;

  #my $sql = "select id from FileTable where day_id = (select id from DayTable where path = '$day_path')";
  #my $file_count = $dbh->selectall_hashref($sql, 'id');
  #my @results = keys(%$file_count);
  #my $num_files = $#results + 1;
  #my $sql = "select count(*) from FileTable where day_id = (select id from DayTable where path = '$day_path')";
  my $sql = "select count(*) from FileTable where path like '$day_path\%'";
  #print STDERR "in getDBNumFiles: $sql\n";
  my $arr_ref = $dbh->selectall_arrayref($sql);
  my $num_files = $arr_ref->[0]->[0];
  return $num_files;

#        my $sql = "select path,nfiles from DayTable where satellite = '$satellite'";
#        my $file_ref = $dbh->selectall_hashref($sql, 'path');
#        my $file_count_ref;
#        foreach $file_path (sort(keys %$file_ref)) {
#                my $path = $file_ref->{$file_path}->{'path'};
#                my $nfiles = $file_ref->{$file_path}->{'nfiles'};
#                $file_count_ref->{$path} = $nfiles;
#
#        }
#
#        return $file_count_ref;

}

sub getHPSSNumFiles {

        my $hpss_dir = shift;
	my $hsi_exe = shift;
	#my $stderr_fname = shift;

        #my $cmd = "$hsi_exe du $hpss_dir 2>&1";
        my $cmd = "$hsi_exe du $hpss_dir";
	my ($results,$status) = executeCommand($cmd);
	#print "$cmd: $status\n";
	if ($status != 0 ) {
	  #printError($cmd, $stderr_fname, $results);
          printError($cmd, $results);
	  next();
	}
	my @hsi_output = split(/\n/, $results);
        my $line = pop(@hsi_output);
        chop($line);
        my $num_files = (split(/\s+/, $line))[4];
        return $num_files;

#        my @output = `$cmd`;
#        my $line = pop(@output);
#        chop($line);
#        my $num_files = (split(/\s+/, $line))[4];
#        return $num_files;

}

sub executeCommand {

  my $command = join ' ', @_;
  ($_ = qx{$command 2>&1}, $? >> 8);

}

sub printError {

  # print out error message

  my $cmd = shift;
  #my $stderr_fname = shift;
  my $results = shift;

  my @hsi_output = split(/\n/, $results);
  #open(STDERR, ">>$stderr_fname") || die "cannot open $stderr_fname";
  print STDERR "Error executing: $cmd\n";
  foreach $error (@hsi_output) {
    $error =~ s/^\s+//g;
    print STDERR "\t$error\n";
  } # end foreach
  #print STDERR "*****************\n";
  #close(STDERR);

}
sub initStderr {

  my $stderr_fname = shift;
  #my $script_name = shift;
  #my $satellite = shift;
  #my $year = shift;
#sferic-dev.20130525143825.populate_db.test.log

  # capture stderr
  #system("mkdir -p $stderr_dir") if ( !-e $stderr_dir );
  #my $current_date_time = `date '+%Y%m%d%H%M%S'`;
  #chop($current_date_time);
  #my $stderr_fname = "$stderr_dir/$script_name.$satellite.$year.$current_date_time.stderr";
  open ERROR,  '>', "$stderr_fname"  or die $!;
  STDERR->fdopen( \*ERROR,  'w' ) or die $!;

}

sub isRunning {

  # figure out if the program is already running
  my $program = shift;
  my $uid = $<;         # user id
  my $pid = $$;         # process id
  print STDERR "looking for $program\n";
  #
  my $command = "/usr/bin/pgrep -f -l -u $uid $program";
  my @procs = `$command`;       # a list of currently running processes
  my $i;
  my @procs_only = ();
  for ($i=0; $i <= $#procs; $i++) {
    # get rid of the new line
    $procs[$i] =~ s/\n//g;
    push (@procs_only, $procs[$i]) if ( $procs[$i] =~ /\/usr\/bin\/perl/ );
  } # end for

  return 1 if ( $#procs_only >= 0 );
  return 0;
  
}


1;
