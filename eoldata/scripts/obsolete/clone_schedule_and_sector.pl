#!/usr/bin/perl
#
use Getopt::Std;
use DBI;
use FindBin;
use lib "FindBin::Bin";
require "common.pl";

# script to clone the Schedule and Sector tables
# for the situation where two different satellites
# have the same Schedule and Sectors
if ( $#ARGV < 0 ) 
{
   print "Usage: clone_schedule_and_sector\n";
   print "\t-f: from satellite (GDD ie: G11)\n";
   print "\t-t: to satellite (GDD)\n";
   exit();
}

getopt('ft');

if ( $opt_f =~ /^G\d{2}$/ )
{
   $from_satellite = $opt_f;
} else
{
   print "Error: $opt_f in incorrect format...must be G followed by 2 numbers (ie: G11)\n";
   exit();
}

if ( $opt_t =~ /^G\d{2}$/ )
{
   $to_satellite = $opt_t;
} else
{
   print "Error: $opt_t in incorrect format...must be G followed by 2 numbers (ie: G11)\n";
   exit();
}


my $dbh = connectToDB("dmg_sat_query", "localhost", "dts-full", "l\@micbc");

fetchSchedule($dbh, $from_satellite, $to_satellite);

$dbh->disconnect();

sub connectToDB
{
   my $db_name = shift;
   my $host = shift;
   my $user = shift;
   my $password = shift;
   return DBI->connect( "DBI:mysql:database=$db_name;host=localhost", 
                        "$user", "$password", {RaiseError=>1} ) || 
                        die( "Unable to Connect to database" );
}
sub fetchSchedule 
{
   my $dbh = shift;
   my $from_satellite = shift;
   my $to_satellite = shift;
   my $sql = "select * from Schedule where satellite = '$from_satellite'";
   $schedule = $dbh->selectall_hashref($sql, 'id');
   $num_schedules = 0;
   my ($time, $sector, $satellite, $schedule_id, $sector_id);
   foreach $sch_id(keys %$schedule) {
     $time = $schedule->{$sch_id}->{time};
     $sector_id = $schedule->{$sch_id}->{sector};
     $satellite = $schedule->{$sch_id}->{satellite};
     $sql = "select * from Sector where id = '$sector_id'";
     $sector = $dbh->selectall_hashref($sql, 'id');
     foreach $sec_id(keys %$sector) {
     }
     print "time: $time\n";
     print "sector_id: $sector_id\n";
     print "satellite: $satellite\n";
     $num_schedules++;
   }
   print "asdf: $num_schedules\n";
}
