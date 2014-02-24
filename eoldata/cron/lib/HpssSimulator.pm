#!/usr/bin/perl

package HpssSimulator;

sub new
{
  my $class = shift;
  my $self = {};
  
  bless( $self, $class );
  
  $self->{dbh} = shift;
  $self->{from_db} = shift;
  
  return $self;
  
}

sub fetchSatelliteList 
{

  # get a list of files and day
  # records from the db
  my $self = shift;
  my $dbh = $self->{dbh};
  my $sql = "select distinct satellite from DayTable";

  # this will automatically exit via the error handler
  # specified in common.pl
  my $satellite_ref = $dbh->selectall_arrayref($sql);

  my @satellite_list;
  for ($i=0; $i <= $#$satellite_ref; $i++) {
    push(@satellite_list, $satellite_ref->[$i][0]);
  }

  # we have some results!
  return \@satellite_list;

}
sub fetchDayId
{

  # return a list of day ids for
  # the given satellite and resolution
  my $self = shift;
  my $satellite = shift;
  my $resolution = shift;
  my $dbh = $self->{dbh};
  my $sql = "select id from DayTable where satellite = '$satellite' and resolution = '$resolution'";

  # this will automatically exit via the error handler
  # specified in common.pl
  my $day_id_ref = $dbh->selectall_arrayref($sql);

  my @day_id_list;
  for ($i=0; $i <= $#$day_id_ref; $i++) {
    push(@day_id_list, $day_id_ref->[$i][0]);
  }

  return \@day_id_list;

#  my @day_id_list;
#  my $id_ref = $dbh->selectall_hashref($sql, 'id');
#  foreach my $key (keys %$id_ref) {
#    push(@day_id_list, $id_ref->{$key}{'id'});
#  }
#
#  return \@day_id_list;

}
sub fetchFiles
{

  # return a list of files for this day
  my $self = shift;
  my $dbh = $self->{dbh};
  my $day_id = shift;
  my $sql = "select path from FileTable where day_id = $day_id";

  # this will automatically exit via the error handler
  # specified in common.pl
  my $file_path_ref = $dbh->selectall_arrayref($sql);

  my @file_list;
  for ($i=0; $i <= $#$file_path_ref; $i++) {
    push(@file_list, $file_path_ref->[$i][0]);
  }

  return \@file_list;

}
1;
