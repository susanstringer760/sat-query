#!/usr/bin/perl
#
# script to simulate file on the hpss
# used when the hpss is down...for
# testing purposes only!
#
# Susan Stringer, 09/25/2012
#
use lib "cron_lib";
use DayRecord;
use FileRecord;
use Table;
use QC;
use Schedule;
use Event;
use HpssSimulator;
use Time;
use DBI;
use Getopt::Std;
use File::Basename;
use File::Path;
use FindBin;
use lib "FindBin::Bin";
require "config.pl";
require "common.sub.pl";

my $db_name = dbName();
my $user = dbUser();
my $password = dbPassword();
my $host = dbHost();


my $dbh = connectToDB($db_name,$user,$password,$host);
my $base_dir = "/scr/ctm/snorman";

my $hpssSimulator = HpssSimulator->new($dbh, $db_name);

my $resolution_ref = satelliteResolution();

# first, get the list of satellites
my $satellite_ref = $hpssSimulator->fetchSatelliteList();

# loop through and get the available day 
my $day_list_ref;
foreach $satellite (@$satellite_ref) {
  foreach $resolution (@$resolution_ref) {
    $day_list_ref->{$satellite}->{$resolution} = $hpssSimulator->fetchDayId($satellite,$resolution);
  }
}

# loop through and the available files for each day
my $day_id, $file_ref;
foreach $satellite (@$satellite_ref) {
  foreach $resolution (@$resolution_ref) {
    # an array of day ids
    $day_ref = $day_list_ref->{$satellite}->{$resolution};
    # the list of files for this day
    print "processing satellite: $satellite resolution: $resolution\n";
    foreach $day_id (@$day_ref) {
      my $file_list_ref = $hpssSimulator->fetchFiles($day_id);
      $file_ref->{$day_id} = $file_list_ref;
      #createFiles($file_ref->{$day_id}, $base_dir);
    }
  }
}

sub createFiles {

  my $file_ref = shift;
  my $base_dir = shift;

  foreach $file (@$file_ref) {
    my $full_path = "$base_dir$file";
    my $fname = basename($full_path);
    my $dir = dirname($full_path);
    mkpath($dir) if ( !-e $dir ); 
    $cmd = "touch $full_path";
    system($cmd);
  }

}

