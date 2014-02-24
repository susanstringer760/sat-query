#!/usr/bin/perl
#
# script to create the javascript
# include file
use DBI;
use File::Basename;
use FindBin qw($Bin);
require "$Bin/common.sub.pl";
require "$Bin/config/config.pl";

# the output js file
my $base_dir = dirname($Bin);
my $js_fname = "$base_dir/html/index2.js";

open(JS, ">$js_fname") or die "cannot open $js_fname";


# the database info
my $db_name = dbName();
$db_name = "sat_query_test";
my $user = dbUser();
my $password = dbPassword();
my $host = dbHost();
my $resolution_ref = satelliteResolution();

my $dbh = connectToDB($db_name,$user,$password,$host);

#my $satellite_ref = getSatelliteList($dbh);
#my $year_ref = getYearList($dbh);
my $satellite_ref = getSatelliteListFromDB($dbh);
my $year_ref = getYearListFromDB($dbh, 'all');
my $sector_hash_ref = getSectorFromDB($dbh);
my $js = createJS($satellite_ref, $sector_hash_ref, $resolution_ref,$year_ref);
print JS "$js\n";

close(JS);
exit();

sub createJS {

  my $satellite_ref = shift;
  my $sector_ref = shift;
  my $resolution_ref = shift;
  my $year_ref = shift;

  # create the js satellite array
  my $satellite_js = "satArray = new Array;\n";
  foreach $satellite (reverse(@$satellite_ref)) {
    $satellite =~ s/G/GOES-/g;
    $satellite_js .= "satArray.push('$satellite');\n";
  }

  # create the js sector array
  #my $sector_js = "sectorArray = new Array;\n";
  #foreach $sector (reverse(@$sector_ref)) {
  #  $sector_js .= "sectorArray.push('$sector');\n";
  #}

  # create the js sector hash 
#  sectorHash = {};
#  sectorHash['GOES-13'] = [];
#  sectorHash['GOES-13'].push('test1 (G13)');
#  sectorHash['GOES-13'].push('test2 (G13)');
#  sectorHash['GOES-13'].push('test3 (G13)');
#  sectorHash['GOES-12'] = [];
#  sectorHash['GOES-12'].push('test1 (G12)');
#  sectorHash['GOES-12'].push('test2 (G12)');
#  sectorHash['GOES-12'].push('test3 (G12)');

   my $sector_js = "sectorHash = {};\n";
   foreach $satellite (keys(%$sector_hash_ref)) {
     my $sector_arr_ref = $sector_hash_ref->{$satellite};
     $sector_js .= "sectorHash['$satellite'] = [];\n";
     foreach $sector (@$sector_arr_ref) {
       $sector_js .= "sectorHash['$satellite'].push('$sector');\n";
     }
   }

  # create the js resolution array
  my $resolution_js = "resolutionArray = new Array;\n";
  foreach $resolution (@$resolution_ref) {
    $resolution_js .= "resolutionArray.push('$resolution');\n";
  }

  # create the js year array
  my $year_js = "yearArray = new Array;\n";
  foreach $year (reverse(@$year_ref)) {
    $year_js .= "yearArray.push('$year');\n";
  }

  # create the month array
  my $month_js = "monthArray = new Array;\n";
  for ($i=1; $i<=12; $i++) {
    $month_js .= "monthArray.push('".sprintf("%02d", $i)."');\n";
  }
  # create the day array
  my $day_js = "dayArray = new Array;\n";
  for ($i=1; $i<=31; $i++) {
    $day_js .= "dayArray.push('".sprintf("%02d", $i)."');\n";
  }

  # create the hour array
  my $hour_js = "hourArray = new Array;\n";
  for ($i=0; $i<=23; $i++) {
    $hour_js .= "hourArray.push('".sprintf("%02d", $i)."');\n";
  }

  # create the minute array
  my $minute_js = "minuteArray = new Array;\n";
  for (my $i=0; $i<=45; $i+=15) {
    my $value = sprintf("%02d", $i);
    $minute_js .= "minuteArray.push('".sprintf("%02d", $i)."');\n";
  }

  # create the julian day array
  my $jday_js = "jdayArray = new Array;\n";
  for ($i=1; $i<=366; $i++) {
    $jday_js .= "jdayArray.push('".sprintf("%03d", $i)."');\n";
  }
return $js,<<EOJS
// output file generated from create_js.pl
//
// values from db
// list of satellites
$satellite_js
// list of sectors 
$sector_js
// list ofresolutions 
$resolution_js
// list of years 
$year_js
// list of months 
$month_js
// list of days 
$day_js
// list of hours 
$hour_js
// list of minutes 
$minute_js
// list of julian days 
$jday_js

function getOptions(element, arr, default_value)
{

  // create the options for the element (select)
  var option = document.createElement("option");
  if ( default_value != null) {
    option.text = default_value;
    option.value = default_value;
    element.appendChild(option);
  }
  for (var i = 0; i < arr.length; i++) {
    var value = arr[i];
    option = document.createElement("option");
    option.text = value;
    option.value = value;
    element.appendChild(option);
  }

}

1;

EOJS


#function ggetOptions(element, arr, default_value)
#{
#
#  // create the options for the element (select)
#  var option = document.createElement("option");
#  option.text = default_value;
#  option.value = default_value;
#  element.appendChild(option);
#  for (var i = 0; i <= arr.length-1; i++) {
#    var value = arr[i];
#    option = document.createElement("option");
#    option.text = value;
#    option.value = value;
#    element.appendChild(option);
#  }
#
#}
#
#
#function getYearOptions(element)
#{
#
#  // get the year options
#  // the default
#  var option = document.createElement("option");
#  option.text = 'YYYY';
#  option.value = 'YYYY';
#  element.appendChild(option);
#  for (var i = 0; i <= yearArray.length-1; i++) {
#    var value = yearArray[i];
#    var option = document.createElement("option");
#    option.text = value;
#    option.value = value;
#    element.appendChild(option);
#  }
#
#
#}


}
