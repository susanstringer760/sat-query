#!/usr/bin/perl
#
# script to create the cron file 
use DBI;
use File::Basename;
use FindBin qw($Bin);
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";

# the output cron file
my $base_dir = dirname($Bin);
my $cron_fname = "$base_dir/cron/sat_query_cron";

# number of days from current to process
my $num_days = 3;

# cron time begin
my $cron_time = 20;

# name of script that is run in the cron tab
my $script_name = "$Bin/populate_db.pl";

open(CRON, ">$cron_fname") or die "cannot open $cron_fname";

# the database info
my $db_name = dbName();
my $user = dbUser();
my $password = dbPassword();
my $host = dbHost();
my $hpssBase = hpssBase();
#my $db_name = "sat_query";
#my $user = "snorman";
#my $password = "emdac";
#my $host = "localhost";
my $dbh = connectToDB($db_name,$user,$password,$host);

# get a list of years for each satellite on the hpss
my $year_ref = getYearListFromHpss($hpssBase);

# get the current year
my $current_year = `date +%Y`;
chop($current_year);

foreach $satellite (keys(%$year_ref)) {
  my $year_list = $year_ref->{$satellite};
  my @list_of_years = sort { $a <=> $b } keys(%$year_list); 
  # the last year for this satellite
  my $latest_year = pop(@list_of_years);
  next if ( $latest_year != $current_year);
  #my @list_of_years = keys(%$year_list); 

  #print "$satellite = @list_of_years\n";
  $satellite = uc($satellite);
  my $cron_entry = "0 $cron_time * * * $script_name -y $latest_year -s $satellite -n $num_days > /dev/null 2>&1";
  print CRON "$cron_entry\n";
  $cron_time++;
}
close(CRON);
