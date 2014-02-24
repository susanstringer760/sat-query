#!/usr/bin/perl -w

# Script to back fill the database
# Arguments:
# 	-y = 4 digit year to process
# 	-s = satellite to process (G followed by 2 digits ie: G13) 
# Constants:
# 	$base = base directory on hpss for the satellite data
# 	@resolution: array of resolutions the satellite 
#
# Susan Stringer: April, 2012
#----------------------------------------------------

use lib "cron_lib";
use DayRecord;
use FileRecord;
use Table;
use QC;
use Schedule;
use Event;
use Time;
use DBI;
use Getopt::Std;
use File::Basename;
use File::Path;
use Cwd;
use FindBin;
use lib "FindBin::Bin";
require "common.pl";

my $db_name = dbName();
my $base = hpssBase();
my @resolution = @{satelliteResolution()};

# the constants
my $log_flag = 1;

# the year to process
if ( $#ARGV < 0 ) {
	print "Usage: backfill_db.pl\n";
	print "\t-y: year to process (YYYY)\n";
	print "\t-s: satellite (GDD ie:G13)\n";
	exit();
}

getopt('ysl');
our($opt_y, $opt_s);

# make sure all the options are present
if ( !$opt_y ) {
	print "Error: year option must be entered (-y)\n";
	exit();
}
if ( !$opt_s ) {
	print "Error: satellite option must be entered (-s)\n";
	exit();
}


my $year = $opt_y;
my $satellite = $opt_s;
if ( !validateYear($year) ) {
	print "Error: $year invalid format...must be YYYY\n";
	exit();
}
if ( !validateSatellite($satellite) ) {
	print "Error: invalid name for $satellite..\n";
	exit();
}

# assemble the log directory name
my $current_dir = cwd();
my $log_dir = "$current_dir/logs";
# fetch the name of the log file 
my $log_fname = getLogFname($log_flag,$log_dir, $year);

open(OUTPUT, ">$log_fname") || die "cannot open $log_fname";

my @hsi_cmd;
my $satellite_dir = lc($satellite);
my $hpss_base_path = "$base/$satellite_dir";

my $list_of_days_ref = {};
my (@list_of_days,@full_path, $julian_day, $year_and_julian_day);

# the database handle
my $dbh = connectToDB($db_name);

foreach $res (@resolution) {

	# loop through each resolution
	$list_of_days_ref->{$res} = getListOfDays($dbh,$hpss_base_path, $res,$year);
	# get the list of available days for the year
	my @list_of_days = @{$list_of_days_ref->{$res}};
        
	foreach $julian_day (@list_of_days) {
		$julian_day =~ s/^day//g;
		# process all the files for this day
		my $status = processDay("$year$julian_day", $satellite, $res, $hpss_base_path);
		next if (!$status);
	}
		
} # end foreach resolution
$dbh->disconnect();
#        	@list_of_days = @{$list_of_days_ref->{"$res"}->{"$yy"}};

close(OUTPUT);
exit 0;

sub processDay 
{

	# process all the files for this day

	my $year_day = shift; # the year and julian day (YYYYDDD)
	my $satellite = shift;
	my $resolution = shift;
	my $hpss_base_path = shift;

	# Pull the schedules from the database
	my $routine_sch = getSchedule( $satellite, $dbh );
	my $rso_sch = getSchedule( "$satellite/RSO", $dbh );
	my $srso_sch = getSchedule( "$satellite/SRSO", $dbh );

	my @intervals;
	my $int_count;

	$year_day =~ /(\d{4})(\d{3})/;
	my $year = $1;
	my $julian_day = $2;

	# Get the last id number of the DayTable
	$id = getLastId($dbh);

	my $prev_tm = 0;
	# increment the id since the value 
	# returned from getLastId is the last
	# id from the day table
	$id++;
	my $fileTable = Table->new();
	my $totSize = 0;

	# Establish a new DayRecord
	my $day = DayRecord->new();
	$day->{id} = $id;
	$day->{satellite} = $satellite;
	$day->{resolution} = $resolution;
	$day->{date} = $year_day;	# YYYYDDD
	$day->{path} = "$hpss_base_path/$resolution/$year/day$julian_day";
	print OUTPUT "processing path: ".$day->{path}."\n";

	# Check and make sure that the day record
	# doesn't already exist
	return 0 if (!$day->exists($dbh));

	# List the files on hpss for this day
	my $files_ref = $day->getFiles($day->{path});
       	my @files = @$files_ref;
	print OUTPUT "There are $#files files in ".$day->{path}."\n";
	my $size = @files;
	if( $size == 0 ) {
		print( "WARNING: The path does not exist, skipping $year_day $satellite $resolution\n" );
		next;
	} # endif $size==0

	# Set the number of files
	$day->{nfiles} = @files - 1;

	# Loop through each file and get the needed information	
	for( my $x = 1; $x < @files; $x++ ) {

		# the file metadata
		my $file = $files[$x];

		# Start a new file record
		$fileRec = getFileRecord( $file );
		
		# Set the day record id number this file belongs to
		$fileRec->{day_id} = $id;

		# Add the file record to the table
		$fileTable->addRecord( $fileRec );

		# Add this file's size to the total size for this day
		$totSize += $fileRec->{size};

		# Set the path
		$fileRec->{path} = $day->{path} . "/" . $fileRec->{path};
		# Flag this day has having missing data if there is a one hour
 		#  time block that contains no data
		if( $fileRec->{out_time} - $prev_tm > 100 ) {
			$day->{missing} = 1;
		}
		$prev_tm = $fileRec->{out_time};
	} # end for @files

        if( $prev_tm < 2300 ) {
        	$day->{missing} = 1;
        }

	$day->{nfiles} = $fileTable->{count};
	$day->{size} = $totSize;

	#-----------------------------------------------
	# Match the schedule to the files for this day.
	# This is performed in three phases.  
	#  First all of the files are compared to the 
	#  routine schedule.  When the sector of a file 
	# cannot be determined it is marked as 'unknown'.  
	# The second phase looks for periods where there are 
	# many unknowns and tries to match these periods to 
	# the rapid scan schedule.  This is then performed a third
	# time, looking for periods with several unknowns, 
	# using the super rapid scan schedule.

	# Match with the routine schedule
	matchRoutine( $fileTable, $routine_sch );	

	# Match with the rapid scan schedule
	matchSectors( $fileTable, $satellite, $rso_sch, $routine_sch,\&matchRSO );	

	# Match with the super rapid scan schedule
	matchSectors( $fileTable, $satellite, $srso_sch, $routine_sch,\&matchSRSO );	

	# Write a summary to the screen
	#$day->write( *STDOUT );

	# Add the DayRecord to the database
	$day->addToDB( $dbh );

	# Write a sumary to the screen
	#$fileTable->write( *STDOUT );

	# Add all of the FileRecords to the database
	$fileTable->addToDB( $dbh );

	return 1;


} # end sub processDay 

sub getLastId
{

	my $dbh = shift;
	my $sql = "SELECT MAX(id) FROM DayTable";
	my $sth = $dbh->prepare( $sql );
	$sth->execute;
	my @row = $sth->fetchrow();
	$sth->finish();
	return $row[0];
}

sub getSchedule
{
  my $sat = shift;	# the name of the satellite
  my $dbh = shift;	# the database handle
  my @row;

  my $sql = "SELECT Schedule.id, Schedule.time, Schedule.sector, Sector.abrv, Sector.duration FROM Schedule, Sector WHERE " .
            "Schedule.sector=Sector.id and Schedule.satellite=\"$sat\" ORDER BY Schedule.time";
  my $sch = Schedule->new();

  my $sth = $dbh->prepare( $sql );
  $sth->execute();

  while( (@row=$sth->fetchrow()) )
  {
    my $event = Event->new( $row[0], Time->new( roundTime( $row[1] ) ), $row[2], $row[3], Time->new( $row[4] ) );
    $sch->addEvent( $event );
  }

  $sth->finish();

  return $sch;

}




sub convertTime
{  

	# convert time (HHMM) to HH:MM:SS
  	my $time = shift;
  	my $hour = int($time / 100);
  	my $min = $time - int($hour * 100);

	return( sprintf( "%2.2d", $hour) . ":" . sprintf( "%2.2d", $min ) . ":00\n" );

}

sub roundTime
{
	my $time = shift;
	my @arr = split( /:/, $time );

	my $hr = $arr[0];
	my $mn = $arr[1];
	my $sc = $arr[2];

	if( $sc >= 30 )
	{ $mn++; }
	$sc = 0;

	if( $mn >= 60 )
	{
		$mn -= 60;
		$hr++;
	}
	if( $hr >= 24 )
	{
		$hr -= 24;
	}

	return( sprintf( "%2.2d", $hr ) . ":" . sprintf( "%2.2d", $mn ) . ":00" );
}


sub getFileRecord
{
	my $file = shift;

	my $fileRec = FileRecord->new();
	my @data = split( /\s+/, $file );
	my $fname = $data[$#data];

	my ($sat,$date,$time,$compression) = split(/\./, $fname);

	$fileRec->{date} = $date;
	$fileRec->{time} = Time->new( convertTime( $time ) );

	$fileRec->{out_time} = $time;
	$fileRec->{size} = $data[4] / 1000;
	$fileRec->{path} = $fname;	

	return $fileRec;

}


#-----------------------------------------------------------------
# Loops through all of the files in a day and determines intervals
#  where there are several 'unknown' sectors.  Then sends these
#  intervals to the appropriate matching subroutine to match the
#  files with the sectors. 
#-----------------------------------------------------------------
sub matchSectors
{
	my $day = shift;
	my $sat = shift;
	my $sch = shift;
	my $routine_sch = shift;
	my $sect_match = shift;

	my $start = -1;
	my $end = -1;
	my $prev_uk = -1;

	my $count = 0;
	my $uk = 0;

	my $c = $day->{count};

	for( my $x = 0; $x < $c; $x++ )
	{
		if( $day->{array}[$x]->{sector} == 11 )
		{
			$uk++;
			if( $prev_uk == -1 )
			{ $prev_uk = $x; }
			elsif( $start == -1 )
			{
				my $diff = Time::minuteDiff( $day->{array}[$x]->{time}, $day->{array}[$prev_uk]->{time} );
				if( abs( $diff ) < 90 )
				{
					$start = $prev_uk; 
				}
				$prev_uk = $x;
			}
			else
			{
				my $diff = Time::minuteDiff( $day->{array}[$x]->{time}, $day->{array}[$prev_uk]->{time} );
				if( abs( $diff ) > 60 )
				{
					$end = $prev_uk; 
					$count = $end - $start + 1;

					my $fac = int( $count / $uk );
					if( $fac <= 3 && ($end - $start) > 1 )
					{
						$sect_match->( $day, $sat, $sch, $routine_sch,$start, $end );
					}
					$end = -1;
					$start = -1;
					$uk = 0;
				}
				$prev_uk = $x;
			}
		}
	}

	if( $prev_uk == $start )
	{
		$end = $c-1;
	}
	else
	{
		$end = $prev_uk;
	}

	my $fac = 99;
	$count = ($end) - $start + 1;

	if( $uk != 0 )
	{ $fac = int( $count / $uk ); }

	if( $start != -1 && $fac <= 3 && ($end - $start) > 1 )
	{ $sect_match->( $day, $sat, $sch, $routine_sch,$start, $end ); }
}

#-----------------------------------------------------------------
# Matches the files with the rapid scan schedule.  Maintains the 
#  intervals chosen to match in ther @intervals array in order to
#  check later when matching for the SRSO.
#-----------------------------------------------------------------
sub matchRSO
{
	my $day = shift;
	my $sat = shift;
	my $sch = shift;
	my $routine_sch = shift;
	my $start = shift;
	my $end = shift;

	my $uk_count = 0;

	my $loc;

	# Store the interval matching
	$intervals[$int_count++] = $start;
	$intervals[$int_count++] = $end;

	for( my $x = $start; $x <= $end; $x++ )
	{
		#my $loc = 0;
		$loc = 0;
		my $file = $day->{array}[$x];
		while( $loc < $sch->{count} )
		{
			my $diff = Time::minuteDiff( $file->{time}, $sch->{events}[$loc]->{time} );

			if( abs( $diff ) <= 1 )
			{
				if( $x+1 ne $day->{count} )
				{
					$file->setSector( $sch->{events}[$loc], $day->{array}[$x+1] ); 
				}
				else
				{
					$file->{sector} = $sch->{events}[$loc]->{sector};
					$file->{qc} = $OTHER;
				}
				last;
			} 
			elsif( $diff < 0 )
			{
				# no sector found for this file, have gone past in the sch
				$file->{sector} = 11;
				$file->{qc} = $UNKNOWN;
				$uk_count++;
				last;
			}
			$loc++;
			#elsif( $diff > 0 )
			#{} continue down the schedule 		
		}
	}

	if( $uk_count != 0 && ($end - $start) / $uk_count <= 3 )
	{
		matchRoutine( $day, $routine_sch, $start, $end );
	}
}

#-----------------------------------------------------------------
# This subroutine matches the files to the super rapid scan schedule
#  in the given interval.  It first checks the @intervals array to
#  see if a similar interval was matched for the rapid scan schedule
#  if so it uses that interval to search for matches. 
#-----------------------------------------------------------------
sub matchSRSO
{
	my $day = shift;
	my $sat = shift;
	my $sch = shift;
	my $routine_sch = shift;
	my $start = shift;
	my $end = shift;

	my $uk_count = 0;

	my $loc;

	# Check to see if a similar inteval was used for the RSO.
	#  if so, use that interval 
	for( my $x = 0; $x < $int_count; $x+=2 )
	{
		if( $start > $intervals[$x] && $start < $intervals[$x+1] )
		{
			$start = $intervals[$x];
			if( $intervals[$x+1] > $end )
			{
				$end = $intervals[$x+1];
			}
			last;
		}
	}

	for( my $x = $start; $x <= $end; $x++ )
	{
		#my $loc = 0;
		$loc = 0;
		my $file = $day->{array}[$x];
		while( $loc < $sch->{count} )
		{
			my $diff = Time::minuteDiff( $file->{time}, $sch->{events}[$loc]->{time} );

			if( abs( $diff ) <= 1 )
			{
				if( $x+1 ne $day->{count} )
				{
					$file->setSector( $sch->{events}[$loc], $day->{array}[$x+1] ); 
				}
				else
				{
					$file->{sector} = $sch->{events}[$loc]->{sector};
					$file->{qc} = $OTHER;
				}
				last;
			} 
			elsif( $diff < 0 )
			{
				# no sector found for this file, have gone past in the sch
				$file->{sector} = 11;
				$file->{qc} = $UNKNOWN;
				$uk_count++;
				last;
			}
			$loc++;
			#elsif( $diff > 0 )
			#{} continue down the schedule 		
		}
	}

	# Check to see if the matching was more or less successful.
	# If 33% of the files are still unknown re-apply the routine
	#  schedule.
	if( $uk_count != 0 && ($end - $start) / $uk_count <= 3 )
	{
		matchRoutine( $day, $routine_sch, $start, $end );
	}
}

#-----------------------------------------------------------------
# Match the files passed in the Table called day to the schedule.
#  This subroutine can use any schedule but it was written with the
#  routine schedule in mind.
#-----------------------------------------------------------------
sub matchRoutine
{
	my $day = shift;
	my $sch = shift;
	my $start = shift;
	my $end = shift;

	my ($loc, $file);

	# Check to see if matching an interval or the whole day
	if( !defined( $start ) || !defined( $end ) )
	{
		$start = 0;
		$end = $day->{count} - 2;
	}

	my @files = @{$day->{array}};

	for( my $x = $start; $x <= $end; $x++ )
	{
		#my $loc = 0;
		#my $file = $files[$x];
		$loc = 0;
		$file = $files[$x];

		while( $loc < ($sch->{count}) )
		{
			my $diff = Time::minuteDiff( $file->{time}, $sch->{events}[$loc]->{time} );

			if( abs( $diff ) <= 1 )
			{
				$file->setSector( $sch->{events}[$loc], $files[$x+1] ); 
				last;
			} 
			elsif( $diff < 0 )
			{
				# no sector found for this file, have gone past in the sch
				$file->{sector} = 11;
				$file->{qc} = $UNKNOWN;
				last;
			}
			$loc++;
			#elsif( $diff > 0 )
			#{} continue down the schedule 		
		}
	}

	# Check the last file of the day - find the sector first!!!
	my $last = $day->{array}[$day->{count}-1];
	$loc = 0;
	my $sector = undef;
	while( $loc < $sch->{count} )
	{
		my $diff = Time::minuteDiff( $last->{time}, $sch->{events}[$loc]->{time} );
		if( abs( $diff ) <= 1 )
		{
			$sector = $sch->{events}[$loc]; 
			last;
		} 
		elsif( $diff < 0 )
		{
			# no sector found for this file, have gone past in the sch
			$sector = undef;
			last;
		}
		$loc++;
	}

	if( !defined( $sector ) )
	{
		$last->{sector} = 11;
		$last->{qc} = $UNKNOWN;
	}
	elsif( defined( $day->{nxtFile} ) )
	{
		my $remain = Time::minuteDiff( Time->new( "24:00:00" ), $last->{time} );
		my $between = $remain + $day->{nxtFile}->{time}->{min};
		#my $check_diff = Time::minuteDiff( $between, $sector->{duration} ); 
		my $check_diff = $between - $sector->{duration}->{min};
		my $diff = Time::minuteDiff( $last->{time}, $sector->{time} );

		if( $check_diff < 0 )
		{
			$last->{sector} = 11;
			$last->{qc} = $UNKNOWN;
		}
		elsif( $check_diff > 5 )
		{
			if( $diff == 0 )
			{ $last->{qc} = $ZERO_UK; }
			elsif( $diff > 0 )
			{ $last->{qc} = $PONE_UK; }
			elsif( $diff < 0 )
			{ $last->{qc} = $MONE_UK; }
			$last->{sector} = $sector->{sector};
		}
		else
		{
			if( $diff == 0 )
			{ $last->{qc} = $ZERO_CP; }
			elsif( $diff > 0 )
			{ $last->{qc} = $PONE_CP; }
			elsif( $diff < 0 )
			{ $last->{qc} = $MONE_CP; }
			$last->{sector} = $sector->{sector};
		}
	}
	else
	{
		$last->{sector} = $sector->{sector};
		my $diff = Time::minuteDiff( $last->{time}, $sector->{time} );
		if( $diff == 0 )
		{ $last->{qc} = $ZERO_UK; }
		elsif( $diff > 0 )
		{ $last->{qc} = $PONE_UK; }
		elsif( $diff < 0 )
		{ $last->{qc} = $MONE_UK; }
	}
}

sub IsLeapYear
{
   my $year = shift;
   return 0 if $year % 4;
   return 1 if $year % 100;
   return 0 if $year % 400;
   return 1;
}

sub validateSatellite
{
	my $satellite = shift;

	return 0 if ($satellite !~ /^G\d{2}$/);
	return 1;
}

sub getListOfDays
{
	my $dbh = shift;
	my $base_dir = shift;
	my $resolution = shift;
	my $year = shift;
	my @list;
	my $cmd = "hsi -q ls -P $base_dir/$resolution/$year 2>&1";
	my @output = `$cmd`;
	foreach $entry (@output) {
		chop($entry);
		$day = basename($entry);
		push(@list, $day);
	}

	return \@list;

}
sub getListOfYears
{
	my $base_dir = shift;
	my $resolution = shift;
	my (@list, $year, $current_year);
	# calculate the current year so we don't get
	# any directory greater than the current year
	my $cmd = "hsi -q ls -P $base_dir/$resolution 2>&1";
	my @output = `$cmd`;
	foreach $entry (@output) {
		chop($entry);
	  	$current_year = `date +%y`;
		$current_year += 2000;
		$year = basename($entry);
		next if ($year > $current_year);
	        push(@list, $year);
	}

	return \@list;

}

sub validateYear
{
	my $year = shift;

	return 0 if ($year !~ /(\d{4})/); 
	return 1;


#	# validate date
#	my $year_day = $year.$julian_day;
#	if ( length($year_day) != 7 ) {
#	 	print "Error: $date option not the correct format, must be YYYYDDD\n";
#		exit();
#	}
#	return 0 if ($year < 1900);
#	if ( length($julian_day) != 3 ) {
#		print "Error: julian day must be 3 digits\n";
#		return 0;
#	}
#	if ($julian_day > 366 || $julian_day < 1) {
#		print "Error: julian day ($julian_day) out of bounds\n";
#		return 0;
#	}
#	return 1;

}
sub getLogFname
{

  my $log_flag = shift;
  my $log_base_dir = shift;
  my $year = shift;	# year that we are processing

  # generate log filename
  if ( $log_flag ) {
    my $default_log_dir = "./log";
    my $log_dir = defined($log_base_dir) ? $log_base_dir: $default_log_dir;
    my $current_date_time = `date '+%Y%m%d%H%M%S'`;
    chop($current_date_time);
    $log_dir .= "/$year";
    # create the directory if necessary
    if ( !-e $log_dir ) {
      my $status = mkpath("$log_dir");
      if ( $status == 0 ) {
        print "Error creating $log_dir\n";
        return "/dev/null";
      }
    }
    $log_fname = basename($0);
    $log_fname =~ s/\.pl$//g;
    $log_fname .= ".$current_date_time.log";
    return "$log_dir/$log_fname";
  } else {
    return "/dev/null";
  }

}
