#!/usr/bin/perl

use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/../cron/lib";
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";

#
# create the run file
# hsi.out created by create_hsi_out

# first, create the input file
my $run_dir = "/h/eol/snorman/git_work/sat_query/scripts/run";
system("mkdir $run_dir") if ( !-e $run_dir );
my $hpss_base = "/EOL/operational/satellite/goes";
my $hsi_out_fname = "$run_dir/hsi.out";
unlink($hsi_out_fname) if ( -e $hsi_out_fname );
system("touch $hsi_out_fname");

# the hsi executable
my $hsi_exe = hsiExe();

my @satellites;
push(@satellites, "g08");
push(@satellites, "g10");
push(@satellites, "g11");
push(@satellites, "g12");
push(@satellites, "g13");
push(@satellites, "g14");
push(@satellites, "g15");
my @resolution = ("1km", "4km");

for ($i=0; $i<=$#satellites; $i++) {
  $sat = $satellites[$i];
  foreach $res (@resolution) {
    my $cmd = "hsi -P ls $hpss_base/$sat/$res >> $hsi_out_fname";
    system($cmd);
  }

}
my $in_fname = $hsi_out_fname;
my $out_fname = "$run_dir/populate_db.run";
my $csv_fname = "$run_dir/populate_db.csv";

my %args;
open(IN, $in_fname) || die "cannot open $in_fname";
open(OUT, ">$out_fname") || die "cannot open $out_fname";
open(CSV, ">$csv_fname") || die "cannot open $csv_fname";
print CSV "SCRIPT, SAT, YEAR, STATUS\n";
while ($line = <IN>) {
  chop($line);
  next() if ( $line eq '');
  $line =~ s/://g;
  if ( $line =~ /^(\/EOL)(.*)/ ) {
    my @tmp = split(/\//, $line);
    pop(@tmp);
    $satellite = pop(@tmp);
    $satellite = uc($satellite);
  }
  if ( $line =~ /^(\d{4})(.*)/ ) {
    $line =~ s/\///g;
    my @years = split(/\s+/, $line);
    $args{$satellite} = \@years;
  }

}
my $begin = "# nohup";
my $end = "2 >\&/dev/null";
my $script_full_path = "/h/eol/snorman/git_work/sat_query/scripts/populate_db.pl";
my $script_fname = basename($script_full_path);
my @cmd_arr;
foreach $key (reverse(sort(keys(%args)))) {
  my $arr_ref = $args{$key};
  my $satellite = $key;
  my @arr = sort { $a <=> $b } @$arr_ref;
  foreach $year (reverse(@arr)) {
    my $cmd = "$begin $script_full_path -y $year -s $satellite $end";
    # print the command
    print OUT "$cmd\n";
    # print csv file
    print CSV "$script_fname, $satellite, $year,,\n";
  }
}
close(OUT);
close(CSV);
close(IN);
