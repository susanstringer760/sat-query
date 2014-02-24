#!/usr/bin/perl
#
# script to verfiy that populate_db.pl is correctly assigning sectors
use DBI;
use File::Basename;
use FindBin qw($Bin);
use Time::Local;
use lib "$Bin/../cron/lib";
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";

# get configurable variables (from config.pl)
my $db_name = dbName();
my $user = dbUser();
my $password = dbPassword();
my $db_host = dbHost();

my $satellite_filter = "G12%";
my $path_filter = "%g12%2008/day007%";

# assemble output file name
my $current_date_time = `date '+%Y%m%d_%H%M%S'`;
chop($current_date_time);
my $script = basename($0);
$script =~ s/.pl//g;
my $files_fname = "output/$script.$current_date_time.files.out";
my $schedule_fname = "output/$script.$current_date_time.schedules.out";
my $out_fname = "output/$script.$current_date_time.out";

open(OUT, ">$out_fname") or die "cannot open $out_fname";
open(FILES, ">$files_fname") or die "cannot open $files_fname";
open(SCHEDULE, ">$schedule_fname") or die "cannot open $schedule_fname";

# connect to the database
my $dbh = connectToDB($db_name,$user,$password,$db_host);
#

# schedule and sector table
my $sch_sector_table_sql = "create temporary table tmp1 as (select sch.id, sch.satellite, sch.time, sch.sector, sec.abrv, sec.duration from Schedule sch, Sector sec where sch.sector=sec.id and sch.satellite like '$satellite_filter')";
print "$sch_sector_table_sql;\n";
#
$dbh->do($sch_sector_table_sql);

# change column time to begin_time 
my $rename_col_sql = "ALTER TABLE tmp1 CHANGE time begin_time time";
$dbh->do($rename_col_sql);
print "$rename_col_sql;\n";

# add end time (begin_time+duration);
my $add_col_sql = "alter table tmp1 add end_time time";
$dbh->do($add_col_sql);
print "$add_col_sql;\n";

# now, calculate end time
my $update_end_time = "update tmp1 set end_time = addtime(begin_time,duration)";
$dbh->do($update_end_time);
print "$update_end_time;\n";

# file and sector table
my $ft_sector_table_sql = "create temporary table tmp2 as (select ft.path, ft.time, ft.sector, sec.id, sec.abrv, sec.duration from FileTable ft, Sector sec where ft.sector=sec.id and ft.path like '$path_filter')";
$dbh->do($ft_sector_table_sql);
print "$ft_sector_table_sql;\n";

#$rename_col_sql = "ALTER TABLE tmp2 CHANGE time file_time time";
# change name and type of time column
my $update_col_sql = "ALTER TABLE tmp2 CHANGE time file_time varchar(11)";
$dbh->do($update_col_sql);
print "$update_col_sql;\n";

$update_col_sql = "update tmp2 set file_time=concat(file_time,'00') where length(file_time)=4";
$dbh->do($update_col_sql);
print "$update_col_sql;\n";

$update_col_sql = "update tmp2 set file_time=concat('0',file_time,'00') where length(file_time)=3";
$dbh->do($update_col_sql);
print "$update_col_sql;\n";

$update_col_sql = "update tmp2 set file_time=concat('00',file_time,'00') where length(file_time)=2";
$dbh->do($update_col_sql);
print "$update_col_sql;\n";


$update_col_sql = "alter table tmp2 change file_time file_time time";
$dbh->do($update_col_sql);
print "$update_col_sql;\n";

exit();

# schedule info
my $schedule_sql = "select satellite,begin_time, end_time,abrv from tmp1 order by begin_time";
my $schedule_ref = $dbh->selectall_arrayref($schedule_sql);
my @schedules = @$schedule_ref;
foreach $schedule (@schedules) {
  my $satellite = sprintf("%8s",$schedule->[0]);
  my $begin_time = sprintf("%8s",$schedule->[1]);
  my $end_time = sprintf("%8s",$schedule->[2]);
  my $abrv = sprintf("%10s",$schedule->[3]);
  print SCHEDULE "$satellite $begin_time to $end_time = $abrv\n";
}

# file info
my $file_sql = "select path,file_time,abrv from tmp2 where path like '%1km%' order by path";
my $file_ref = $dbh->selectall_arrayref($file_sql);
my @files = @$file_ref;
foreach $file (@files) {
  my $fname = basename($file->[0]);
  $fname = sprintf("%15s",$fname);
  my $file_time = sprintf("%8s",$file->[1]);
  my $abrv = sprintf("%10s",$file->[2]);
  print FILES "$fname $file_time $abrv\n";
}

my $join_sql = "select t1.satellite,t1.abrv,t1.begin_time,t1.end_time,t2.file_time,t2.path,t2.abrv from tmp1 t1, tmp2 t2 where (t1.sector=t2.sector) and (t2.file_time between t1.begin_time and t1.end_time)";
$join_ref = $dbh->selectall_arrayref($join_sql);
@files = @$join_ref;
foreach $file (@files) {
  my $satellite = sprintf("%8s",$file->[0]);
  my $abrv = sprintf("%8s",$file->[1]);
  my $begin_time = sprintf("%8s",$file->[2]);
  my $end_time = sprintf("%8s",$file->[3]);
  my $file_time = sprintf("%8s",$file->[4]);
  my $fname = basename($file->[5]);
  my $fname = sprintf("%8s",$fname);
  my $file_abrv = sprintf("%8s",$file->[6]);
  print OUT "$satellite $abrv $begin_time $end_time $file_time $fname $file_abrv\n";
}

close(OUT);
close(SCHEDULE);
close(FILES);
#
