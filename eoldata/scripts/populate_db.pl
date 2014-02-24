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

$ENV{'PATH'} = "/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:.";

use DBI;
use Getopt::Std;
use File::Basename;
use File::Path;
use Cwd;
use IO::Handle;
use FindBin qw($Bin);
use lib "$Bin/../cron/lib";
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";
#require "$Bin/config.pl";
use DayRecord;
use FileRecord;
use Table;
use QC;
use Schedule;
use Event;
use Time;

# get configurable variables (from config.pl)
my $db_name = dbName();
my $user = dbUser();
my $password = dbPassword();
#my $host = hostname;
my $db_host = dbHost();
#my $base = hpssBase();
my $hpss_base_path = hpssBase();
my @resolution = @{satelliteResolution()};
my $hsi_exe = hsiExe();
#my $hsi_exe = "/opt/local/hpss/bin/hsi";
my $host = host();
my @tmp = split(/\./, $host);
$host = shift(@tmp);

# the constants
my $log_flag = 1;
my $sql_log_flag = 0;
use Fcntl qw(:flock);
print "start of program\n";
unless (flock(DATA, LOCK_EX|LOCK_NB)) {
    print "$0 is already running. Exiting.\n";
    exit(1);
}

# the year to process
if ( $#ARGV < 0 ) {
	print "Usage: $0\n";
	print "\t-y: year to process (YYYY)\n";
	print "\t-s: satellite (GDD ie:G13)\n";
	print "\t-n: number of days to process (from most recent)\n";
	exit();
}

our($opt_y, $opt_s, $opt_n);
getopt('ysn');

# make sure all the options are present
#if ( !$opt_y ) {
#	print "Error: year option must be entered (-y)\n";
#	exit();
#}
if ( !$opt_s ) {
	print "Error: satellite option must be entered (-s)\n";
	exit();
}
my $num_days = $opt_n;
$num_days = 'all' if ( !$opt_n );

# default to current year
my $year = (localtime)[5] + 1900;
$year = $opt_y if ($opt_y);

#my $year = $opt_y;
#my $satellite = lc($opt_s);
my $satellite = $opt_s;
if ( !validateYear($year) ) {
	print "Error: $year invalid format...must be YYYY\n";
	exit();
}
if ( !validateSatellite($satellite) ) {
	print "Error: invalid name for $satellite..\n";
	exit();
}

# name of this script
my $script_name = basename($0);
$script_name =~ s/.pl$//g;

# assemble the log directory name
my $log_dir = logDir();
# fetch the name of the log file 
my $log_fname = getLogFname($log_flag,$log_dir, $script_name, $year, $satellite, "general", $host, $db_name);
my $sql_log_fname = getLogFname($sql_log_flag,$log_dir, $script_name, $year, $satellite, "sql", $host, $db_name);

open(LOG, ">$log_fname") || die "cannot open $log_fname";
open(SQL, ">$sql_log_fname") || die "cannot open $sql_log_fname";

my $begin_date_time = `date`;
chop($begin_date_time);

# capture stderr
my $stderr_fname = $log_fname;
$stderr_fname =~ s/.log$/.stderr/g;
initStderr($stderr_fname);

print LOG "BEGIN DATE TIME: $begin_date_time\n";
print LOG "HOST: $host\n";

my @hsi_cmd;

my $hpss_list_of_days_ref = {};
my (@full_path, $julian_day, $year_and_julian_day);

# the database handle
my $dbh = connectToDB($db_name, $user, $password, $db_host);

my $dir_to_list;

# first, get the satellite schedules
my $routine_sch = getSchedule( $satellite, $dbh );
my $rso_sch = getSchedule( "$satellite/RSO", $dbh );
my $srso_sch = getSchedule( "$satellite/SRSO", $dbh );
my $schedule_ref = {
  'routine' => $routine_sch,
  'rso' => $rso_sch,
  'srso' => $srso_sch,
};
foreach $res (@resolution) {

	#next if ( $res =~ /1km/i );
	# loop through each resolution
	my $lower_res = lc($res);
	#
	# a reference to a list of days from hpss
	#$dir_to_list = "$hpss_base_path/$satellite/$lower_res/$year";

	#my $list_of_days_ref->{$satellite}->{$res} = getDayListFromHpss($satellite, $res, $year, $hpss_base_path, $hsi_exe);
	my $list_of_days_ref = getDayListFromHpss($satellite, $lower_res, $year, $hpss_base_path, $hsi_exe);


	#my $list_of_days_ref->{$res} = getListOfDays($dbh,$dir_to_list, $hsi_exe, $num_days);
	# get the list of available days for the year
	my @hpss_list_of_days = @{$list_of_days_ref->{lc($satellite)}->{$lower_res}};
	@hpss_list_of_days = map(basename($_), @hpss_list_of_days);
	if ( $num_days ne 'all' ) {
	  my $count = $#hpss_list_of_days;
	  @hpss_list_of_days = @hpss_list_of_days[$count-$num_days+1 .. $count];
	}

	# exit if there are not any days for this satellite and year
	if ( $#hpss_list_of_days < 0 ) {
	  print LOG "WARNING: there are no days listed for satelitte: $satellite year: $year resolution: $res\n";
	  print "WARNING: there are no days listed for satelitte: $satellite year: $year resolution: $res\n";
	  next();
	}
        
	foreach $julian_day (@hpss_list_of_days) {

	        #exit if ( $julian_day eq "day010");

 		#next if ( $julian_day ne "day003");

		print LOG "processing $julian_day where year=$year and satellite=$satellite\n";
		$julian_day =~ s/^day//g;
		# process all the files for this day
		#my $status = processDay("$year$julian_day", $satellite, $res, $hpss_base_path, $schedule_ref);
		my $status = processDay("$year$julian_day", $satellite, $lower_res, $hpss_base_path, $schedule_ref);
		next if (!$status);
	}
		
} # end foreach resolution
$dbh->disconnect();

my $end_date_time = `date`;
chop($end_date_time);

print LOG "END DATE TIME: $end_date_time\n";


close(LOG);
close(SQL);
close(STDERR);
exit 0;

sub processDay 
{

	# process all the files for this day

	my $year_day = shift; # the year and julian day (YYYYDDD)
	my $satellite = shift;
	my $resolution = shift;
	my $hpss_base_path = shift;
	my $schedule_ref = shift;

	# Pull the schedules from the database

	my $routine_sch = $schedule_ref->{'routine'};
	my $rso_sch = $schedule_ref->{'rso'};
	my $srso_sch = $schedule_ref->{'srso'};
	#my $routine_sch = getSchedule( $satellite, $dbh );
	#my $rso_sch = getSchedule( "$satellite/RSO", $dbh );
	#my $srso_sch = getSchedule( "$satellite/SRSO", $dbh );

	my @intervals = ();
	my $int_count = 0;

	$year_day =~ /(\d{4})(\d{3})/;
	my $year = $1;
	my $julian_day = $2;

	# Get the last id number of the DayTable
	#$id = getLastId($dbh);

	# increment the id since the value 
	# returned from getLastId is the last
	# id from the day table
	#my $next_id = id+1;

	my $prev_tm = 0;
	my $fileTable = Table->new();
	my $totSize = 0;

	# Establish a new DayRecord
	my $day = DayRecord->new();
	#$day->{id} = $next_id;
	$day->{satellite} = $satellite;
	$day->{resolution} = $resolution;
	$day->{date} = $year_day;	# YYYYDDD
	#$day->{path} = "$hpss_base_path/$resolution/$year/day$julian_day";
	$day->{path} = "$hpss_base_path/".lc($satellite)."/$resolution/$year/day$julian_day";

	#$day->{id} = $day->getID($dbh);

	print LOG "processing path: ".$day->{path}."\n";
	print "populate_db.pl: path =  ".$day->{path}."\n";

	# List the files on hpss for this day
	#my $files_ref = $day->getFilesFromHpss($day->{path}, $hsi_exe);
	my $files_ref = getFileListFromHpss($hsi_exe,$day->{path});
       	my @files = @$files_ref;
       	#my @files = @$files_ref[1..10];
	print LOG "There are $#files files in ".$day->{path}."\n";
	#print STDERR "There are $#files files in ".$day->{path}."\n";
	my $size = @files;
	if( $size == 0 ) {
		#print "WARNING: The path does not exist, skipping $year_day $satellite $resolution\n";
		print LOG "WARNING: The path does not exist, skipping $year_day $satellite $resolution\n";
		next;
	} # endif $size==0

	# Set the number of files
	$day->{nfiles} = @files - 1;

	# Add (or update) the DayRecord in the database
	#my $day_id = $day->getID($dbh);
	my $day_id = $day->getID($dbh, *SQL);
	if ( $day_id < 0 ) {
	  #$day->addToDB($dbh);
	  $day->addToDB($dbh, *SQL);
	  $day->{id} = $day->getID($dbh,*SQL);
	} else {
	  if ( $day->{nfiles} > 0 ) {
	    $day->{id} = $day_id;
	    #$day->updateDB($dbh);
	    $day->updateDB($dbh, *SQL);
	  }
	}
	#-----------------------------------------------

	# Loop through each file and get the needed information	
	#for( my $x = 1; $x < @files; $x++ ) {
	for( my $x = 0; $x < @files; $x++ ) {

		# the file metadata
		my $file = $files[$x];

		# Start a new file record
		my $fileRec = getFileRecord( $file );

		# Set the day record id number this file belongs to
		$fileRec->{day_id} = $day->{id};

		# Set the path
		$fileRec->{path} = $day->{path} . "/" . $fileRec->{path};

		# don't enter this record again if it
		# already exists
		if ( $fileRec->exists($dbh, *SQL) ) {
		  print LOG "WARNING: file record for: ".$fileRec->{path}." already exists..skipping..\n";
		  #print "WARNING: file record for: ".$fileRec->{path}." already exists..skipping..\n";
		  next();
		}

		# Add the file record to the table

		$fileTable->addRecord( $fileRec );

		# Add this file's size to the total size for this day
		$totSize += $fileRec->{size};

		# Flag this day has having missing data if there is a one hour
 		#  time block that contains no data
		if( $fileRec->{out_time} - $prev_tm > 100 ) {
			$day->{missing} = 1;
		}
		$prev_tm = $fileRec->{out_time};
	} # end for @files

	# no need for further processing
	return 0 if ($fileTable->{count} <= 0);

        if( $prev_tm < 2300 ) {
        	$day->{missing} = 1;
        }

	# get the number of files and size
	$day->{nfiles} = $fileTable->{count};
	$day->{size} = $totSize;
	#$day->updateDB($dbh);
	print SQL $day->updateDB($dbh,*SQL);
	
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
#my ($p,$s);
#my @xx = @{$fileTable->{array}};
#$p = $fileTable->{array}[$#xx-1]->{path};
#$s = $fileTable->{array}[$#xx-1]->{sector};
#print "before matchRoutine: $p and $s\n";
	matchRoutine( $fileTable, $routine_sch);
#my @yy = @{$fileTable->{array}};
#$p = $fileTable->{array}[$#xx-1]->{path};
#$s = $fileTable->{array}[$#xx-1]->{sector};
#print "after matchRoutine: $p and $s\n";
#
#	# Match with the rapid scan schedule
#@xx = @{$fileTable->{array}};
#$p = $fileTable->{array}[$#xx-1]->{path};
#$s = $fileTable->{array}[$#xx-1]->{sector};
#print "before matchRoutine RSO: $p and $s\n";
	matchSectors( $fileTable, $satellite, $rso_sch, $routine_sch,\&matchRSO );	
#@yy = @{$fileTable->{array}};
#$p = $fileTable->{array}[$#xx-1]->{path};
#$s = $fileTable->{array}[$#xx-1]->{sector};
#print "after matchRoutine RSO: $p and $s\n";
#
## Match with the super rapid scan schedule
#@xx = @{$fileTable->{array}};
#$p = $fileTable->{array}[$#xx-1]->{path};
#$s = $fileTable->{array}[$#xx-1]->{sector};
#print "before matchRoutine SRSO: $p and $s\n";
	matchSectors( $fileTable, $satellite, $srso_sch, $routine_sch,\&matchSRSO );	
#@yy = @{$fileTable->{array}};
#$p = $fileTable->{array}[$#xx-1]->{path};
#$s = $fileTable->{array}[$#xx-1]->{sector};
#print "after matchRoutine SRSO: $p and $s\n";
#exit();

	# Write a summary to the screen
	#$day->write( *STDOUT );


	# Write a sumary to the screen
	#$fileTable->write( *STDOUT );

	# Add all of the FileRecords to the database
	#$fileTable->addToDB($dbh);
	$fileTable->addToDB($dbh, *SQL);

	# finally, update the day record to reflect the
	# file numbers and sizes from the db
	$day->{nfiles}  = getTotalNumFiles($day, $dbh);
	$day->{size} = getTotalSize($day, $dbh);
	$day->updateDB($dbh, *SQL);

	return 1;


} # end sub processDay 

sub getTotalNumFiles {

  # get the total number of all the files for this day

  my $day = shift;
  my $dbh = shift;

  my $day_id = $day->{id};

  my $sql = "select count(*) from FileTable where day_id = $day_id";

  my @row = $dbh->selectrow_array($sql);

  return $row[0];

}

sub getTotalSize {

  # get the total size for all the files for this day

  my $day = shift;
  my $dbh = shift;

  my $day_id = $day->{id};

  my $sql = "select sum(size) from FileTable where day_id = $day_id";

  my @row = $dbh->selectrow_array($sql);

  return $row[0];

}

sub xxgetNextDayId
{

  # get the next id from the day table
  my $dbh = shift;
  my $sql = "SELECT MAX(id) FROM DayTable";

  my @row = $dbh->selectrow_array($sql);
  print "asdf: $row[0]\n";exit();

  
}
sub xxgetLastId
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
sub getDayRecord
{
	my $dbh = shift;
	my $id = shift;
	my $day_record = shift;
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

	# parse out the information returned from the
	# hpss and populate the file attributes
	my $file = shift;

	my $fileRec = FileRecord->new();
	my @data = split( /\s+/, $file );
	my $fname = $data[$#data];

	my ($sat,$date,$time,$compression) = split(/\./, $fname);

	$fileRec->{date} = $date;

	$fileRec->{time} = Time->new( convertTime( $time ) );

	$fileRec->{out_time} = $time;

	my $size = ($data[4]/1000)+.5;
	$fileRec->{size} = sprintf("%d",$size);
	#$fileRec->{size} = $data[4] / 1000;
	$fileRec->{path} = "$fname";	

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


	#XXXXXXXX
	my $xx = 0;
	my $yy = $c-1;
	#print STDERR "in matchSectors: $xx to $yy\n";
	for( my $x = 0; $x < $c; $x++ )
	{

		if ( !$day->{array}[$x] ) {
		  print STDERR "in matchSectors: file undefined at index = $x..skipping\n";
		  next();
		}

		#if (!$day->{array}[$x]->{sector}) {
		if (!defined($day->{array}[$x]->{sector})) {
		  my ($package, $filename, $line) = caller;
		  print STDERR "in matchSectors: pck=$package, fname=$filename, line=$line...sector undefined setting ".$day->{array}[$x]->{path}." to unknown\n";
		  $day->{array}[$x]->{sector} = 11;
		  $day->{array}[$x]->{qc} = $UNKNOWN;
		}


		if( $day->{array}[$x]->{sector} == 11 )
		{
			$uk++;
			if( $prev_uk == -1 )
			{ $prev_uk = $x; }
			elsif( $start == -1 )
			{
				my $diff = Time::minuteDiff( $day->{array}[$x]->{time}, $day->{array}[$prev_uk]->{time});
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
	{ 
		$sect_match->( $day, $sat, $sch, $routine_sch,$start, $end ); 
	}
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

	#print STDERR "in matchRSO: $start to $end\n";
	for( my $x = $start; $x <= $end; $x++ )
	{
		#my $loc = 0;
		$loc = 0;
		my $file = $day->{array}[$x];
		if ( !$file ) {
		  print STDERR "in matchRSO: file undefined at index = $x..skipping\n";
		  next();
		}

		while( $loc < $sch->{count} )
		{
			my $diff = Time::minuteDiff( $file->{time}, $sch->{events}[$loc]->{time} );

			if( abs( $diff ) <= 1 )
			{
				if( $x+1 ne $day->{count} )
				{
					#my $xx = $day->{array}[$x+1]->{path};
					#print STDERR "in matchRSO: test1 calling setSector for $xx\n";
					$file->setSector( $sch->{events}[$loc], $day->{array}[$x+1] ); 
				}
				else
				{
					#print STDERR "in matchRSO: setting sector for ".$file->{path}."\n";
					$file->{sector} = $sch->{events}[$loc]->{sector};
					$file->{qc} = $OTHER;
				}
				last;
			} 
			#elsif( $diff < 0 )
			elsif( $diff <= 0 )
			{
				# no sector found for this file, have gone past in the sch
				#print STDERR "in matchRSO: setting sector for ".$file->{path}." to unknown\n";
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

	#xxprint "begin: day in matchSRSO: $day\n";

	my $uk_count = 0;

	my $loc;

	# Check to see if a similar inteval was used for the RSO.
	#  if so, use that interval 
	#xxprint "in matchSRSO day count: ".$day->{count}."\n";
	#print STDERR "in matchSRSO intervals: $int_count and $#intervals\n";
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

	$end = $day->{count}-1 if ( $end > $day->{count} );
	#for( my $x = $start; $x < $end; $x++ )
	for( my $x = $start; $x <= $end; $x++ )
	{
		#my $loc = 0;
		$loc = 0;
		my $file = $day->{array}[$x];
		if ( !$file ) {
		  print STDERR "in matchSRSO: file undefined at index = $x..skipping\n";
		  next();
		}
		#if ( !defined $file ) {
	        #  print STDERR "in matchSRSO: test2: $x\n" ;
		#  next();
		#}
		#next() if ( !$file );
		while( $loc < $sch->{count} )
		{	
			my $diff = Time::minuteDiff( $file->{time}, $sch->{events}[$loc]->{time} );
			my ($package, $filename, $line) = caller;
			#print STDERR "in matchSRSO: ".$file->{path}." diff = $diff\n";

			if( abs( $diff ) <= 1 )
			{
				if( $x+1 ne $day->{count} )
				{
					#my $xx = $day->{array}[$x+1]->{path};
					#print STDERR "in matchSRSO: test2 calling setSector for $xx\n";
					$file->setSector( $sch->{events}[$loc], $day->{array}[$x+1] ); 
				}
				else
				{
					#print STDERR "in matchSRSO: setting sector for ".$file->{path}."\n";
					$file->{sector} = $sch->{events}[$loc]->{sector};
					$file->{qc} = $OTHER;
				}
				last;
			} 
			#elsif( $diff < 0 )
			elsif( $diff <= 0 )
			{
				# no sector found for this file, have gone past in the sch
				#print STDERR "in matchSRSO: setting sector for ".$file->{path}." to unknown\n";
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
	#xxprint "end: day in matchSRSO: $day\n";
	if( $uk_count != 0 && ($end - $start) / $uk_count <= 3 )
	{
		#xxprint "asdf start: $start\n";
		#xxprint "asdf end: $end\n";
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
		#$end = $day->{count} - 2;
		$end = $day->{count} - 1;
	}

	my @files = @{$day->{array}};
	#xxprint "at start..\n";
	#xxprint "in matchRoutine start: $start\n";
	#xxprint "in matchRoutine end: $end\n";
	#xxprint "in matchRoutine num files: ".$day->{count}."\n";
	#XXXXXXXX
	my $xx = $start;
	my $yy = $end;
	#print STDERR "in matchRoutine: $xx to $yy\n";
	#for( my $x = $start; $x <= $end; $x++ )
	for( my $x = $start; $x < $end; $x++ )
	{
		#my $loc = 0;
		#my $file = $files[$x];
		$loc = 0;
		$file = $files[$x];
		my $hour = $file->{time}->{hour};
		my $min = $file->{time}->{min};
		my $sec = $file->{time}->{sec};
		#print STDERR "in matchRoutine $x: ".$file->{path}." $hour:$min:$sec\n";

		while( $loc < ($sch->{count}) )
		{

			my $diff = Time::minuteDiff( $file->{time}, $sch->{events}[$loc]->{time} );

			if( abs( $diff ) <= 1 )
			{
				#print STDERR "in matchRoutine: test2 calling setSector for x=$x and diff = $diff and ".$file->{path}."\n";
				$file->setSector( $sch->{events}[$loc], $files[$x+1] ); 
				last;
			} 
			#elsif( $diff < 0 )
			elsif( $diff <= 0 )
			{
				#print STDERR "in matchRoutine: test3 calling setSector for x=$x and diff = $diff and ".$file->{path}."\n";
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
	#xxprint "in matchRoutine: last: ".$last->{path}." = ".$last->{time}."\n";
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
		#elsif( $diff < 0 )
		elsif( $diff <= 0 )
		{
			# no sector found for this file, have gone past in the sch
			print STDERR "in matchRoutine: can't find sector for ".$last->{path}."\n";
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
		my $check_diff = $between - $sector->{duration}->{min};
		my $diff = Time::minuteDiff( $last->{time}, $sector->{time} );
		#print STDERR "in matchRoutine: check diff: $check_diff\n";

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
		my @info = caller(0);
        	my $package = $info[0];
        	my $filename = $info[1];
        	my $line = $info[2];
        	my $subroutine = $info[3];
		my $diff = Time::minuteDiff( $last->{time}, $sector->{time} );
		if( $diff == 0 )
		{ $last->{qc} = $ZERO_UK; }
		elsif( $diff > 0 )
		{ $last->{qc} = $PONE_UK; }
		elsif( $diff < 0 )
		{ $last->{qc} = $MONE_UK; }
	}
	#xxprint "end: day in matchRoutine: $day\n";
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

	return 0 if ($satellite !~ /^G\d{2}$/i);
	return 1;
}

sub getListOfDays
{

	# get a list of days from the hpss for
	# this year and resolution
	my $dbh = shift;
	my $base_dir = shift;
	#my $resolution = shift;
	#my $year = shift;
	my $hsi_exe = shift;
	my $num_days = shift;
	#my $list_command= "hsi -q ls -P $base_dir/$resolution/$year 2>&1 |";
	#my $list_command= "hsi -q ls -P \"$base_dir\" 2>&1 |";
	my $list_command= "$hsi_exe -q ls -P \"$base_dir\" 2>&1 |";

	open(CMD, $list_command) || die("\nCannot get HPSS directory listing of $base_dir\n\n");
        my @list_of_days = ();
        while (<CMD>) {
                chop;
		next if !/DIRECTORY/;
		my ($dir,$full_path) = split(/\s+/, $_);
		push (@list_of_days, basename($full_path)); 
	}
	close(CMD);

	return [] if ($#list_of_days < 0);

	my $sorted_list_ref = sortByDay(\@list_of_days);
	@list_of_days = @$sorted_list_ref;
	if ( $num_days ne 'all' ) {
	    	my $count = $#list_of_days;
	        @list_of_days = @list_of_days[$count-$num_days+1 .. $count];
	}

	return \@list_of_days;






#	my @list;
#	my $cmd = "hsi -q ls -P $base_dir/$resolution/$year 2>&1";
#	my @output = `$cmd`;
#	foreach $entry (@output) {
#		chop($entry);
#		$day = basename($entry);
#		push(@list, $day);
#	}
#
#	return \@list;

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

}
sub getLogFname
{

  my $log_flag = shift;
  my $log_base_dir = shift;
  my $script_name = shift;
  my $year = shift;
  my $satellite = shift;  
  my $log_type = shift;
  my $host = shift;
  my $db_name = shift;


  # generate log filename

  # if the log flag is not set, the everything goes to /dev/null
  if ( $log_flag ) {
    my $default_log_dir = "./logs";
    my $log_dir = defined($log_base_dir) ? $log_base_dir: $default_log_dir;
    #my $current_date_time = `date '+%Y%m%d%H%M%S'`;
    my $current_date_time = `date '+%Y%m%d_%H%M%S'`;
    chop($current_date_time);
    #$current_date_time =~ s/://g;
    #$log_dir .= "/$script_name/$satellite/$year";
    $log_dir .= "/$script_name";
    #$log_dir .= "/$script_name.$current_date_time/$satellite/$year";
    # create the directory if necessary
    if ( !-e $log_dir ) {
      my $status = mkpath("$log_dir");
      if ( $status == 0 ) {
        print "Error creating $log_dir\n";
        return "/dev/null";
      }
    }
    my $script_name = basename($0);
    $script_name =~ s/\.pl$//g;
    #return "$log_dir/$current_date_time.$log_fname.log" if ($log_type eq "general");
    #return "$log_dir/$script_name.$host.$db_name.$current_date_time.$script_name.log" if ($log_type eq "general");
    #return "$log_dir/$host.$db_name.$current_date_time.$script_name.sql.log" if ($log_type eq "sql");
    return "$log_dir/$script_name.$host.$db_name.".uc($satellite).".$year.$current_date_time.log" if ($log_type eq "general");
    return "$log_dir/$script_name.$host.$db_name.".uc($satellite).".$year.$current_date_time.sql.log" if ($log_type eq "sql");

  } else {

    return "/dev/null";

  }

}
sub sortByDay {

	# sort list of days numberically
	my $list_of_days_ref = shift;

	my (%hash, $day);

	# stuff into a hash so we can sort the keys
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
print "end of program\n";
__DATA__
This exists so flock() code above works.
DO NOT REMOVE THIS DATA SECTION.

