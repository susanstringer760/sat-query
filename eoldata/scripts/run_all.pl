#!/usr/bin/perl

use File::Basename;
use FindBin qw($Bin);
use DBI;
use lib "$Bin/../cron/lib";
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";

# get configurable variables (from config.pl)
my $db_name = dbName();
my $user = dbUser();
my $password = dbPassword();
my $host = hostname;
my $db_host = dbHost();
my $hpss_base_dir = hpssBase();
my @resolution = @{satelliteResolution()};
my $hsi_exe = hsiExe();
#my $hsi_exe = "/opt/local/hpss/bin/hsi";
my $host = host();
my $logDir = logDir();
my @tmp = split(/\./, $host);
$host = shift(@tmp);


# name of database
my $date = `date '+%Y%m%d_%T'`;
chop($date);
$date =~ s/://g;
#
# name of script
my $script_name = $0;
$script_name =~ s/^(\.\/)//g;
$script_name =~ s/.pl$//g;
#
# make the output directory if necessary
my $log_dir = logDir()."/$script_name";
system("mkdir -p $log_dir") if (!-e $log_dir);
#
# the base output director
my $current_date_time = `date '+%Y%m%d_%H%M%S'`;
chop($current_date_time);

# log file
my $log_fname = "$log_dir/$script_name.$current_date_time.log";

# stderr
my $stderr_fname = $log_fname;
$stderr_fname =~ s/log$/stderr/g;
initStderr($stderr_fname);

open(LOG, ">$log_fname") or die "cannot open $log_fname";
my $begin_date_time = `date`;
chop($begin_date_time);
print LOG "BEGIN DATE TIME: $begin_date_time\n";
print LOG "HOST: $host DB: $db_name\n";

# connect to the database
my $dbh = connectToDB($db_name,$user,$password,$db_host);

# command begin and end
my $begin = "nohup";
my $end = "2 >\&/dev/null";
my $script_full_path = "$Bin/populate_db.pl";
my $script_fname = basename($script_full_path);

my $satellite_ref = getSatelliteListFromHpss($hpss_base_dir, $hsi_exe);
my $resolution_ref = satelliteResolution();
my $hpss_year_ref = getYearListFromHpss($hpss_base_dir, $hsi_exe, $satellite_ref, $resolution_ref);
my $hpss_days_ref;

foreach $satellite (reverse(sort(keys(%$hpss_year_ref)))) {

  my $satellite_year_ref = $hpss_year_ref->{$satellite};
  my @list_of_years = keys(%$satellite_year_ref);
  my @list_of_years = sort { $a <=> $b } @list_of_years;
  foreach $year (@list_of_years) {

    #my $cmd = "$begin $script_full_path -y $year -s ".uc($satellite)." $end";
    my $date = `date`;
    chop($date);
    my $cmd = "$script_full_path -y $year -s ".uc($satellite);
    print LOG "$date: running $cmd\n";
    print STDERR "$date: running $cmd\n";
    system($cmd);

    my $base = basename($script_full_path);
    my $status = isRunning($base);

    if ( $status == 0 ) {
      $date = `date`;
      chop($date);
      my $compare_cmd = "$Bin/compare_file_count.pl -y $year -s $satellite";
      print LOG "$date: running $compare_cmd\n";
      print STDERR "$date: running $compare_cmd\n";
      system($compare_cmd);
      print LOG "***********************\n";
    }

  } # end foreach $year
} # end foreach $satellite

my $end_date_time = `date`;
chop($end_date_time);
print LOG "END DATE TIME: $end_date_time\n";

close(LOG);
