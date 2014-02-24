#!/usr/bin/perl
#
# simple script to verfiy that all the files were entered into the db
# output is db files which can be visually compared to files on hpss 

use DBI;
use Getopt::Std;
use FindBin;
use lib "FindBin::Bin";
require "common.pl";

if ( $#ARGV < 0 ) {
  print "$0:\n";
  print "\t-s: satellite\n";
  print "\t-y: year\n";
  exit();
}

getopt('sy');

if ( !$opt_s ) {
  print "ERROR: satellite must be specified (-s)\n";
  exit();
}
if ( !$opt_y ) {
  print "ERROR: year must be specified (-y)\n";
  exit();
}

my $hsi_exe = hsiExe();

my $dbh = connectToDB();

my $satellite = $opt_s;
my $year = $opt_y;

my @resolutions = ("1km", "4km");

foreach $resolution (@resolutions) {
  my $db_hash_ref = get_file_from_db($dbh,$satellite,$resolution, $year);
  my $begin = $db_hash_ref->{'begin'};
  my $end = $db_hash_ref->{'end'};
  print "$satellite $year $resolution\n";
  print "\tbegin: $begin\n";
  print "\tend: $end\n";
}

sub get_file_from_db {

  my $dbh = shift;
  my $satellite = shift;
  my $resolution = shift;
  my $year = shift;
  my $sql;
  $sql = "select distinct id,date from DayTable where satellite = '$satellite' and path like '%$resolution%$year%' order by date";
  $hash_ref = $dbh->selectall_hashref($sql, 'id');
  my ($id,$date);
  foreach $key (keys(%$hash_ref)) {
    $id = $key;
    $date = $hash_ref->{$id}->{'date'};
    print "processing $id and $date\n";
    $begin_sql = "select ft.path from FileTable ft, DayTable dt where ft.day_id = dt.id and dt.satellite = '$satellite' and dt.date = '$date' and dt.resolution = '$resolution' order by ft.path limit 1;";
    $end_sql = "select ft.path from FileTable ft, DayTable dt where ft.day_id = dt.id and dt.satellite = '$satellite' and dt.date = '$date' and dt.resolution = '$resolution' order by ft.path desc limit 1;";
    
    my @begin = $dbh->selectrow_array($begin_sql);
    my @end = $dbh->selectrow_array($end_sql);
    my $db_hash_ref;
    $db_hash_ref->{$date}{'begin'} = $begin[0];
    $db_hash_ref->{$date}{'end'} = $end[0];


    #print "$satellite: $resolution\n";
    #print "\tbegin: @begin\n";
    #print "\tend: @end\n";
  }
    return $db_hash_ref;

}
