#!/usr/bin/perl

package FileRecord;

use Time;
use QC;

sub new
{
	my $class = shift;
	my $self = {};
	bless( $self, $class );

	$self->{day_id} = undef;
	$self->{date} = undef;
	$self->{time} = undef;
	$self->{out_time} = undef;
	$self->{size} = undef;
	$self->{path} = undef;
	$self->{sector} = undef;
	$self->{qc} = undef;
	$self->{left} = undef;
	$self->{right} = undef;

	return $self;	
}

sub write
{
	my $self = shift;	
	*OUT = shift;

	print( OUT $self->{date}, "\t" );
	print( OUT $self->{out_time}, "\t" );
	printf( OUT "%d\t", $self->{size} );
	print( OUT $self->{sector}, "\t" );
	print( OUT $self->{qc}, "\t" );
	print( OUT $self->{path}, "\n" );
}

sub addToDB
{
	my $self = shift;
	my $dbh = shift;
	my $sql_log = shift;


	my $day_id = $self->{day_id};
	my $date = $self->{date};
	#my $time = $self->{time};
	my $time = $self->{out_time};
	my $size = $self->{size};
	my $path = $self->{path};
	my $sector = $self->{sector};
	my $qc = $self->{qc};
	#my $id = 0;
	#my $columns = "day_id,date,time,size,path,sector,sector_qc, id";
	#my $values = "'$date','$time','$size','$path','$sector','$qc','$id'";
	my $columns = "day_id,date,time,size,path,sector,sector_qc";
	my $values = "'$day_id','$date','$time','$size','$path','$sector','$qc'";
	#my $sql = "INSERT INTO FileTable ($columns) VALUES ($values)";
	my $sql = "INSERT INTO FileTable ($columns) VALUES ($values)";

	#my $sql = "INSERT INTO FileTable (day_id, date, time, size, path, sector, sector_qc, id) " . 
	#					"VALUES ( $self->{day_id}, $self->{date}, $self->{out_time}, $self->{size}, \'$self->{path}\', $self->{sector}, $self->{qc}, 0 )";

	my $t1 = time;
	$dbh->do( $sql ) || die( "doing: ", $dbh->errstr );
	my $t2 = time;

	my $dt = $t2 - $t1;
	print $sql_log $self->logMessage($sql)." elapsed time: $dt seconds\n";

}

sub setSector
{
	my $self = shift;
	my $event = shift;
	my $next = shift;
	my $cp_known = 1;

	if ( !$next ) {
	my ($package, $filename, $line) = caller;
          print STDERR "in secSector: next time not defined: caller pck=$package, fname=$filename, line=$line\n";
	}

	# check to make sure this event has time to complete
	my $tm = $self->{time}->add( $event->{duration} );
	my $check_diff = Time::minuteDiff( $next->{time}, $tm );

	if( $check_diff < 0 )
	{
		$self->{sector} = 11;
		$self->{qc} = $UNKNOWN;
		return;
	}
	elsif( $check_diff > 5 )
	{
		$cp_known = 0;	
	}	

	my $diff = Time::minuteDiff( $self->{time}, $event->{time} );
	if( $diff == 0 && $cp_known )
	{ $self->{qc} = $ZERO_CP; }
	elsif( $diff == 0 && !$cp_known )
	{ $self->{qc} = $ZERO_UK; }
	elsif( $diff > 0 && $cp_known )
	{ $self->{qc} = $PONE_CP; }
	elsif( $diff > 0 && !$cp_known )
	{ $self->{qc} = $PONE_UK; }
	elsif( $diff < 0 && $cp_known )
	{ $self->{qc} = $MONE_CP; }
	elsif( $diff < 0 && !$cp_known )
	{ $self->{qc} = $MONE_UK; }
	else
	{ $self->{qc} = $OTHER; }

	$self->{sector} = $event->{sector};	
}

sub exists
{
	# check to see if a file already exists in the database
        my $self = shift;
        my $dbh = shift;
	my $sql_log = shift;
	my $path = $self->{path};

	#my $sql = "SELECT * FROM FileTable where path = '$path'";
	my $sql = "SELECT path FROM FileTable where path = '$path'";

	my @files; 
	my $t1 = time;
        my $path_ref = $dbh->selectrow_arrayref($sql);
	my $t2 = time;

	# time elapsed to complete the query
	my $dt = $t2 - $t1;
	print $sql_log $self->logMessage($sql)." elapsed time: $dt seconds\n";

	# compare the path to determine if the record is unique
	my $path_from_db;
	if ( !$path_ref->[0] ) {
	  $path_from_db = '' ;
	} else {
	  $path_from_db = $path_ref->[0] ;
	}
	my $path_from_hpss = $path;

	return 1 if ($path_from_hpss eq $path_from_db);
	return 0; # new file

}
sub getCurrentDateTime
{

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
