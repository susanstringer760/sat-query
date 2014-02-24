#!/usr/bin/perl
#

use File::Basename;
use FindBin qw($Bin);
use Getopt::Std;
use DBI;
use lib "$Bin/../cron/lib";
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";

# get configurable variables (from config.pl)
my $log_dir = logDir();
my $script_name = basename($0);
$script_name =~ s/.pl//g;
my $dir = "$log_dir/$script_name";
system("mkdir $dir") if ( !-e $dir );
my $current_date_time = `date '+%Y%m%d%H%M%S'`;
chop($current_date_time);

# script that runs the comparisons
my $comparison_script = "$Bin/compare_file_count.pl";

my $out_fname = "$dir/warnings.$current_date_time.out";
open(OUT, ">$out_fname") or die "cannot open $out_fname";
close(OUT);
open(OUT, ">>$out_fname") or die "cannot open $out_fname";

opendir(DIR, $dir) or die "cannot open $dir";

my @list_of_satellites = grep (/G\d{2}/, readdir(DIR));
closedir(DIR);
@list_of_satellites = map("$dir/$_", @list_of_satellites);
foreach $satellite_dir (@list_of_satellites) {
  opendir(SAT, $satellite_dir) or die "cannot open $satellite_dir";
  my @dates = grep (/\d{4}/, readdir(SAT));
  @dates = map("$satellite_dir/$_", @dates);
  foreach $date_dir (@dates) {
    my $cmd = "grep WARNING $date_dir/*.log";
    my $results = `$cmd`;
    if ( $results ne '' ) {

      # find the script that was executed
      my $grep_cmd = "grep running $date_dir/*.log";
      my $running_results = `$grep_cmd`;
      chop($running_results);
      $running_results =~ s/running\s+//g;
      print OUT "#$running_results\n";
      #print "# $running_results\n";

      # get satellite and year
      my @tmp = split(/\//, $date_dir);
      my $year = $tmp[-1];
      my $satellite = $tmp[-2];
      print OUT "#$comparison_script -y $year -s $satellite\n";
      #print "# $comparison_script -y $year -s $satellite\n";
      print OUT "#********************\n";

    }
  }
  closedir(SAT);
}
close(OUT);
