#!/usr/bin/perl

package DayRecord;

sub new
{
	my $class = shift;
	my $self = {};
	bless( $self, $class );

	$self->{id} = undef;
	$self->{satellite} = undef;
	$self->{resolution} = undef;
	$self->{date} = undef;
	$self->{nfiles} = 0;
	$self->{size} = 0;	# kilobytes
	$self->{path} = undef;
	$self->{missing} = 0;
	$self->{nxtFile} = undef;	
	$self->{left} = undef;
	$self->{right} = undef;

	return $self;
}

sub write
{
	my $self = shift;
	*OUT = shift;

	print( OUT $self->{date}, "\t" );
	print( OUT $self->{satellite}, "\t" );
	print( OUT $self->{resolution}, "\t" );
	print( OUT $self->{nfiles}, "\t" );
	printf( OUT "%d\t", $self->{size} );
	print( OUT $self->{path}, "\n" );
}

sub updateDB
{
	my $self = shift;
	my $dbh = shift;
	my $sql_log = shift;

	my $columns = "(date,satellite,resolution,nfiles,size,path,missing)";
	my $id = $self->{'id'};
	my $date = $self->{'date'};
	my $satellite= $self->{'satellite'};
	my $resolution = $self->{'resolution'};
	my $nfiles = $self->{'nfiles'};
	my $size = $self->{'size'};
	my $path = $self->{'path'};
	my $missing = $self->{'missing'};
	my $values = "('$date','$satellite','$resolution','$nfiles','$size','$path','$missing')";

	return if ( $size <= 0);

	my $sql = "UPDATE DayTable SET date='$date',satellite='$satellite',resolution='$resolution',nfiles='$nfiles',size='$size',path='$path',missing='$missing' where id = $id";

	#print "$sql\n";
	my $t1 = time;
	$dbh->do( $sql ) || die ("doing: ", $dbh->errstr );
	my $t2 = time;

	# elapsed time to execute statement
	my $dt = $t2-$t1;
	print $sql_log $self->logMessage($sql)." elapsed time: $dt seconds\n";
	


}

sub addToDB
{

	# add this record to the db
	my $self = shift;
	my $dbh = shift;
	my $sql_log = shift;

	# first, get the next id for this table
	#my $id = $self->getNextId($dbh);

	#my $columns = "(id,date,satellite,resolution,nfiles,size,path,missing)";
	my $columns = "(date,satellite,resolution,nfiles,size,path,missing)";
	my $date = $self->{'date'};
	my $satellite= $self->{'satellite'};
	my $resolution = $self->{'resolution'};
	my $nfiles = $self->{'nfiles'};
	my $size = $self->{'size'};
	my $path = $self->{'path'};
	my $missing = $self->{'missing'};
	#my $values = "($id,'$date','$satellite','$resolution',$nfiles,$size,'$path',$missing)";
	my $values = "('$date','$satellite','$resolution',$nfiles,$size,'$path',$missing)";

	my $sql = "INSERT INTO DayTable $columns value $values";

	my $t1 = time;
	$dbh->do( $sql ) || die ("doing: ", $dbh->errstr );
	my $t2 = time;

	# elapsed time to execute statement
	my $dt = $t2-$t1;
	print $sql_log $self->logMessage($sql)." elapsed time: $dt seconds\n";

}

sub getNextId
{

  my $self = shift;
  my $dbh = shift;

  my $sql = "SELECT MAX(id) FROM DayTable";

  # get the max id from the day table 
  my @row = $dbh->selectrow_array($sql);

  return 1 if !$row[0];

  return $row[0]+1;

}
sub xxaddToDB
{
	my $self = shift;
	my $dbh = shift;
	my $sql = "INSERT INTO DayTable ( id, date, satellite, resolution, nfiles, size, path, missing ) " .
						"VALUES ( $self->{id}, $self->{date}, \'$self->{satellite}\', \'$self->{resolution}\', ".
						"$self->{nfiles}, $self->{size}, \'$self->{path}\', $self->{missing} )";

	print "$sql\n\n";
	#$dbh->do( $sql ) || die ("doing: ", $dbh->errstr );

}

sub getFilesFromHpss
{

	# return a reference to a list of files from the hpss
	# for this day
	my $self = shift;
        my $path = shift;
	my $hsi_exe = shift;

	#my $path = $self->{path};

	my $fname;

	# the command to fetch a list of files for this
	# day from the HPSS
	my $list_command = $hsi_exe." ls -l \"".$path."\" 2>&1 |";

	open(CMD, $list_command) || die("\nCannot get HPSS directory listing of $path\n\n");
	my @list_of_files = ();
	my @sorted_list_of_files = ();
	while (<CMD>) {
		chop;
  		next if !/^\-/;	# skip if not a file
		push(@list_of_files, $_);
	} # end while
	close(CMD);

	return \@list_of_files;

}

sub getID 
{

	# check to see if this day already exists
	# in the database

	my $self = shift;
	my $dbh = shift;
	my $sql_log = shift;
	my $date = $self->{date}; # Year and julian day (YYYYJJ) 
	my $satellite = $self->{satellite};
	my $resolution = $self->{resolution};
	my $path = $self->{path};

	my $t1 = time;	
	my $sql = "SELECT id from DayTable where date='$date' and satellite='$satellite' and resolution='$resolution' and path='$path'"; 
	my $t2 = time;

	# elapsed time to execute statement
	my $dt = $t2-$t1;
	print $sql_log $self->logMessage($sql)." elapsed time: $dt seconds\n";

	my @row = $dbh->selectrow_array($sql);
	return ($row[0]) if (defined($row[0]));

	return -1;

}
sub xxexists
{

	# check to see if this day already exists
	# in the database

	my $self = shift;
	my $dbh = shift;
	my $date = $self->{date}; # Year and julian day (YYYYJJ) 
	my $satellite = $self->{satellite};
	my $resolution = $self->{resolution};
	my $sql = "SELECT id from DayTable where date='$date' and satellite='$satellite' and resolution='$resolution'";
        my $sth = $dbh->prepare( $sql );
        $sth->execute;
        my @row = $sth->fetchrow();
        $sth->finish();
	if ($row[0]) {
		print "Warning: record with id=$row[0]: date=$date, satellite=$satellite, resolution=$resolution  already exists..\n"; 
		return 1;
	}
	return 0;	# new day

}
sub checkForDuplicates
{
	my $self = shift;
	my $dbh = shift;

}
sub getCurrentDateTime
{

	# return the current date/time for logging purposes
	my $current_date_time = `date '+%Y/%m/%d %H:%M:%S'`;
	chop($current_date_time);
	return $current_date_time;

}
sub logMessage
{

  my $self = shift;
  my $msg = shift;
  my $current_date_time = $self->getCurrentDateTime();
  my $location = (caller(1))[3];

  return "$current_date_time: $location: $msg";

}
1;
