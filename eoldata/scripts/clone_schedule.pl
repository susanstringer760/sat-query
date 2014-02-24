#!/usr/bin/perl
#
use DBI;
use Getopt::Std;
use FindBin;
use lib "FindBin::Bin";
require "common.sub.pl";
require "config.pl";

if ( $#ARGV < 0 )
{
   print "Usage: $0\n";
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

# assemble the output filename
my $host = host();
$host =~ /([\w\-]+)[\w\.]+/;
$host = $1;

# name of database
my $dbName = dbName();
my $date = `date '+%Y%m%d_%T'`;
chop($date);
$date =~ s/://g;

# name of script
my $script_name = $0;
$script_name =~ s/^(\.\/)//g;
$script_name =~ s/.pl$//g;

# make the output directory if necessary
my $log_dir = logDir()."/$script_name";
system("mkdir $log_dir") if (!-e $log_dir);

# name of log file
my $out_fname = "$log_dir/$script_name.$host.$dbName.$date.log";

open(OUT, ">$out_fname") || die "cannot open $out_fname";

print OUT "OUTPUT FROM SCRIPT: $0\n";
print OUT "FROM SATELLITE: $from_satellite\n";
print OUT "TO SATELLITE: $to_satellite\n";

# the database info
my $db_name = dbName();
my $user = dbUser();
my $password = dbPassword();
my $host = dbHost();
my $dbh = connectToDB($db_name,$user,$password,$host);

# get a list of satellites from that match the original satellite ($from_satellite) 
my $sql = "select distinct satellite from Schedule where satellite like '$from_satellite\%' order by satellite;";
my @satellites;
my @rows = @{$dbh->selectall_arrayref($sql)};
if ( $#rows >= 0 ) {
  for ($i=0; $i<=$#rows;$i++) {
    my $satellite = $rows[$i]->[0];
    #$satellite =~ s/$from_satellite/$to_satellite/;
    push(@satellites, $satellite);
  }
}
my $id_map_ref;
$id_map_ref = clone_sectors($dbh, $from_satellite, $to_satellite);
clone_schedules($dbh,$from_satellite, $to_satellite, $id_map_ref);

close(OUT);

sub clone_sectors {

  # clone the sectors

  my $dbh = shift;
  my $from_satellite = shift;
  my $to_satellite = shift;

  my $sql = "select * from Sector where satellite like '$from_satellite%';";

  my %id_map;

  my $sector_ref = $dbh->selectall_hashref($sql, 'id');
  foreach my $id (keys %$sector_ref) {
    my $name = $sector_ref->{$id}{name};
    $name =~ s/$from_satellite/$to_satellite/g;
    my $abrv = $sector_ref->{$id}{abrv};
    my $duration = $sector_ref->{$id}{duration};
    my $satellite = $sector_ref->{$id}{satellite};
    $satellite =~ s/$from_satellite/$to_satellite/g;

    # first make sure the new sector doesn't exist
    $sql = "select * from Sector where name='$name' and abrv='$abrv' and duration='$duration' and satellite='$satellite'";
    my $exists_ref = $dbh->selectall_hashref($sql, 'id');
    my @results = keys(%$exists_ref);
    if ( $#results >= 0 ) {
      print OUT "WARNING: Sector record already exists where:";
      print OUT "name=$name abrv=$abrv duration=$duration satellite=$to_satellite\n";
      my $new_id = $results[0];
      $id_map{$id} = $new_id;
      next();
    }
    # create the new sector
    my $sql = "INSERT INTO Sector (name,abrv,duration,satellite) values ('$name', '$abrv', '$duration', '$satellite')";
    print OUT "$sql\n";
    $sql =~ s/$from_satellite/$to_satellite/g;
    $dbh->do($sql);
    # get the new sector id
    my $sql = "select last_insert_id()";
    my $result = $dbh->selectall_arrayref($sql);
    my $new_sector_id = $result->[0][0];
    $id_map{$id} = $new_sector_id;
  }

  # return the sector id map
  return \%id_map;

}
sub clone_schedules {

  my $dbh = shift;
  my $from_satellite = shift;
  my $to_satellite = shift;
  my $sector_id_map = shift;

  my $sql = "SELECT * FROM Schedule WHERE satellite like '$from_satellite%'";
  my $schedule_ref = $dbh->selectall_hashref($sql, 'id');
  foreach my $id (keys %$schedule_ref) {
    #my $id = $schedule_ref->{$id}{id};
    my $time = $schedule_ref->{$id}{time};
    my $sector = $schedule_ref->{$id}{sector};
    my $satellite = $schedule_ref->{$id}{satellite};
    $satellite =~ s/$from_satellite/$to_satellite/g;

    # first make sure the new schedule doesn't exist
    $sql = "select * from Schedule where time='$time' and satellite='$satellite'";
    my $exists_ref = $dbh->selectall_hashref($sql, 'id');
    my @results = keys(%$exists_ref);
    if ( $#results >= 0 ) {
      print OUT "WARNING: Schedule record already exists where:";
      print OUT "time=$time and satellite=$satellite\n";
      next();
    }
    # insert new schedule record
    my $new_sector = $sector_id_map->{$sector};
    my $insert_sql = "INSERT INTO Schedule (time,sector,satellite) VALUES ('$time',$new_sector,'$satellite')";
    print OUT "$insert_sql\n";
    $dbh->do($insert_sql);

  } 

}
