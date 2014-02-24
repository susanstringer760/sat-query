#!/usr/bin/perl

use File::Basename;
use FindBin qw($Bin);
use Getopt::Std;
use DBI;
use lib "$Bin/../cron/lib";
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";

if ( $#ARGV < 0 ) {
        print "Usage: $0\n";
        print "\t-y: year to process (YYYY)\n";
        print "\t-s: satellite (GDD ie:G13)\n";
        exit();
}

our($opt_y, $opt_s);
getopt('ysn');

my $satellite = lc($opt_s);
my $year = $opt_y;

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

# current date 
my $date = `date '+%Y%m%d_%T'`;
chop($date);
$date =~ s/://g;
#
# name of script
my $script_name = $0;
$script_name =~ s/^(\.\/)//g;
$script_name =~ s/.pl$//g;
$script_name = basename($script_name);
#
# make the output directory if necessary
my $current_date_time = `date '+%Y%m%d_%H%M%S'`;
chop($current_date_time);
my $log_dir = logDir()."/$script_name";
system("mkdir -p $log_dir") if (!-e $log_dir);
#
# make the output directory if necessary

# connect to the database
my $dbh = connectToDB($db_name,$user,$password,$db_host);

# command begin and end
#my $begin = "nohup";
#my $end = "2 >\&/dev/null";
#my $end = "\&";
#my $script_full_path = "/h/eol/snorman/git_work/sat_query/scripts/populate_db.pl";

# list of resolutions (from config.pl)
my $resolution_ref = satelliteResolution();

my $satellite_ref;
$satellite_ref->[0] = $satellite;

my $hpss_days_ref;

my $warning_count = 0;

# the log file
my $log_fname = "$log_dir/$script_name.$host.$db_name.$date.log";

# the stderr output file
my $stderr_fname = $log_fname;
$stderr_fname =~ s/log$/stderr/g;
#my $stderr_fname = "$base_log_dir/$host.$db_name.$date.$script_name.stderr";
initStderr($stderr_fname);

open(LOG, ">$log_fname") or die "cannot open $log_fname";

my $date = `date`;
chop($date);

print LOG "BEGIN: $date\n";

foreach $resolution (@resolution) {
  $resolution = lc($resolution);
  # list of days for hpss
  $hpss_days_ref = getDayListFromHpss($satellite, $resolution, $year, $hpss_base_dir, $hsi_exe);
  my $day_ref = $hpss_days_ref->{$satellite};
  foreach $path (@{$day_ref->{$resolution}}) {
    print LOG "processing $path\n";
    print "processing $path\n";

    my $num_hpss_files = getHPSSNumFiles($path, $hsi_exe);
    my $num_db_files = getDBNumFiles($dbh, $path);
    if ( $num_hpss_files != $num_db_files ) {
      print LOG "$path: WARNING # hpss files: $num_hpss_files doesn't match # db files: $num_db_files\n";
      $warning_count++;
    } else {
      print LOG "$path: SUCCESS # hpss files: $num_hpss_files matches # db files: $num_db_files\n";
    }# end if $num
  } # end foreach $path
} # end foreach resolution
if ( $warning_count == 0 ) {
  print LOG "There are no warnings for $satellite $year\n";
} 
$date = `date`;
chop($date);
print LOG "END: $date\n";
close(LOG);

close(STDERR);
