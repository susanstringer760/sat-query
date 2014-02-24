#!/usr/bin/perl
#
use Getopt::Std;
use DBI;

# Script to read the schedule information and insert
# it into the database.  Schedule information obtained from:
# http://www.ssd.noaa.gov/PS/SATS/
# SJS 04/12/2012

if ( $#ARGV < 0 ) {
   print "USAGE: insert_schedule_into_db.pl\n"; 
   print "\t-f: name of file containing schedule information\n";
   print "\t-s: name of satellite\n";
   exit();
}

getopt('fs');

if (!-e $opt_f ) {
   print "Error: $opt_f doesn't exist..\n";
   exit();
}

if ( !$opt_s ) {
   print "Error: -s flag (satellite name)  doesn't exist..\n";
   exit();
}

my $schedule_fname = $opt_f;
my $satellite_name = $opt_s;
if ( $satellite_name !~ /^G\d{2}(\/*[RSO]*)$/ ) {
   print "Error: $satellite_name is not valid\n";
   exit();
}

print "processing $opt_f\n";

# the database handle
my $dbh = connectToDB();

# a reference to a list of sector names and abbreviations
my $sector_abrv_ref = getSectorInformation($dbh);

# add Southern Hemisphere Short if it's not in the db
# as it's new for G15
my @sohem_short = grep(/SOUTHERN_HEMISPHERE_SHORT/, (keys(%$sector_abrv_ref)));
$sector_abrv_ref->{SOUTHERN_HEMISPHERE_SHORT} = "SOHEM-SHORT" if ($#xx < 0);

#foreach $key (keys(%$sector_abrv_ref)) {
#  $value = $sector_abrv_ref->{$key};
#  print "$key = $value\n";
#}
#exit();

my ($sector,$duration, @tmp);
my ($duration_hour,$duration_min, $duration_sec, $schedule_time);

# a reference to a hash of sector names and abbreviations
# where the key is the abbreviation and the value is the full name
open(SCHEDULE, "$schedule_fname") || die "cannot open $schedule_fname";
while ( $line = <SCHEDULE> ) {
   chop($line);
   next if ($line =~ /^#/); # don't process the comments
   $line =~ s/^\s+//g;	# get rid of leading spaces
   print "line from schedule is: $line\n";

   @tmp = split(/\s+/, $line);

   # Schedule time
   $schedule_time = shift(@tmp);

   # Sector duration
   $duration = pop(@tmp);

   # format the min, sec
   $duration =~ /(\d{1,2}):(\d{1,2})/;
   $formatted_duration = sprintf("%2s:%02d:%02d", "00",$1, $2);

   # Schedule sector 
   $sector_name = join(" ", @tmp);
   $sector_name =~ s/\s+$//; #remove trailing spaces
   $sector_name = uc($sector_name);
   $key = $sector_name;
   $key =~ s/\s/\_/g;
   $abrv = $sector_abrv_ref->{$key};
   if ( !$abrv ) {
      print "Error: can't find abbreviation for $key\n";exit();
   }
   my $sector_id = insertSector($dbh,$sector_name, $abrv ,$formatted_duration,$satellite_name);
   print "id for inserted Sector is: $sector_id\n";
   # now link the sector to the schedule
   my $schedule_id = insertSchedule($schedule_time,$sector_id, $satellite_name);
   print "id for inserted Schedule is: $schedule_id\n";
   print "********************\n";
}
close(SCHEDULE);

exit();

sub insertSchedule
{
   my $time = shift;
   my $sector_id = shift;
   my $satellite = shift;

   my $schedule_id = getScheduleID($dbh, $time,$sector_id, $satellite);
   if ( !$schedule_id) {
      my $sql="insert into Schedule (time,sector,satellite) values ('$time',$sector_id,'$satellite')";
      print "$sql\n";
      $rows = $dbh->do($sql) or die $dbh->errstr;
      return getScheduleID($dbh,$time,$sector_id,$satellite);
   } 
   return $schedule_id;
}

sub insertSector
{
   my $dbh = shift;
   my $name = shift;
   my $abrv = shift;
   my $duration = shift;
   my $satellite = shift;
   $name .= " ($satellite)";
   my $sector_id = getSectorID($dbh, $abrv, $duration, $satellite);
   if ( !$sector_id ) {
      my $sql = "insert into Sector (name,abrv,duration,satellite) values ('$name','$abrv','$duration','$satellite')";
      print "$sql\n";
      $rows = $dbh->do($sql) or die $dbh->errstr;
      # return the id for the new sector
      return getSectorID($dbh,$abrv,$duration,$satellite);
   }
   return $sector_id;

}

sub getSectorID
{

   my $dbh = shift;
   my $abrv = shift;
   my $duration = shift;
   my $satellite = shift;

   my $sql = "select id from Sector where abrv='$abrv' and duration='$duration' and satellite='$satellite'";
   print "$sql\n";

   $sector_ref = $dbh->selectall_hashref($sql, 'id');

   # id is the first element
   my $sector_id = (keys(%$sector_ref))[0];

   return $sector_id;

}

sub getScheduleID
{

   my $dbh = shift;
   my $time = shift;
   my $sector_id = shift;
   my $satellite = shift;

   my $sql = "select id from Schedule where time = '$time' and sector = $sector_id  and satellite='$satellite'";

   $schedule_ref = $dbh->selectall_hashref($sql, 'id');

   # id is the first element
   my $schedule_id = (keys(%$schedule_ref))[0];

   return $schedule_id;

}

sub connectToDB
{
   my $db_name = "dmg_sat_query";
   my $host = "localhost";
   my $user = "dts-full";
   my $password = "l\@micbc";
   return DBI->connect( "DBI:mysql:database=$db_name;host=$host",
                        "$user", "$password", {RaiseError=>1} ) ||
			die( "Unable to Connect to database" );
}

sub getSectorInformation
{

   # get the sector name and abbreviation from the db
   # and put into a hash where the key is the name 
   # and the value is the abbreviation 
   my $dbh = shift;
   my ($name,$abrv, $satellite,$hash_ref);
   my $sql = "select distinct id,name,abrv from Sector order by name";
   $sector_ref = $dbh->selectall_hashref($sql, 'id');
   foreach $sector_id(keys %$sector_ref) {
      # strip off the satellite name from the sector name
      # so we have a unique name
      $name = $sector_ref->{$sector_id}->{name};
      @tmp = split(/\s+/, $name);
      # strip of the satellite because we want
      # a unique name (not one for every satellite)
      $satellite = pop(@tmp) if ($tmp[$#tmp] =~ /(\(G\d{2}\/*\w*\)+)/);
      $satellite =~ s/[\(\)]//g;	# strip off the '(' and ')'
      ($satellite,$scanning_strategy) = split(/\//, $satellite) if ($satellite =~ /\//);
      #print "testit: $satellite and $scanning_strategy\n";
      $name = join(" ", @tmp);
      $abrv = $sector_ref->{$sector_id}->{abrv};
      # join the name with _ since it's the key
      $name =~ s/\s/\_/g;
      $hash_ref->{$name} = $abrv;
   }

   return $hash_ref;

}

