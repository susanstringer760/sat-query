#!/usr/bin/perl
#
use DBI;

# script to dump the Sector and Schedule tables

# Schedule
my $dbh = connectToDB();
my $schedule_sql = "select time, sector, satellite from Schedule order by satellite";
my $sth = $dbh->prepare( $schedule_sql);
$sth->execute;
my $schedule = $sth->fetchall_hashref('satellite');
$sth->finish();

my $sector_sql = "select name, abrv, duration, satellite from Sector where id = 'INSERT ID'";
my ($sql, $sector_id);

print "sector,time, and satellite from Schedule table\n";
foreach $satellite (sort keys(%$schedule)) {
  #print $schedule->{$satellite}->{sector}."  ";
  print "Time: ".$schedule->{$satellite}->{time}."  ";
  print "Satellite: ".$schedule->{$satellite}->{satellite}."\n";
  $sql = $sector_sql;
  $sector_id = $schedule->{$satellite}->{sector};
  $sql =~ s/INSERT ID/$sector_id/;
  $sector = $dbh->selectrow_hashref($sql);
  print "\tsector name:".$sector->{name}."\n";
  print "\tsector abrv:".$sector->{abrv}."\n";
  print "\tsector duration:".$sector->{duration}."\n";
  print "\tsector satellite:".$sector->{satellite}."\n";
}

$dbh->disconnect();


sub connectToDB
{

   my $db_name = shift;
   my $db_user = shift;
   my $db_password = shift;
   return DBI->connect( "DBI:mysql:database=$db_name;host=localhost", 
                        "$db_name", "$db_password", {RaiseError=>1} ) || 
                        die( "Unable to Connect to database" );
}

