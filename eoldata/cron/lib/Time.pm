#!/usr/bin/perl

package Time;

sub new
{
	my $class = shift;
	my $time = shift;

	my $self = {};
	bless( $self, $class );
	
	$self->{hour} = undef;
	$self->{min} = undef;
	$self->{sec} = undef;

	if( defined( $time ) )
	{
		$self->setTime( $time );
	}
	return $self;
}

#setTime( "01:01:59" ) or setTime( hour, min, sec )
sub setTime
{
	my $self = shift;
	my $time = shift;
	my $hour = $time;
	my $min = shift;
	my $sec = shift;
	if( !defined( $min ) )
	{
		@tm = split( /:/, $time );
		$hour = $tm[0];
		$min = $tm[1];
		$sec = $tm[2];
	}

	$self->{hour} = $hour;
	$self->{min} = $min;
	$self->{sec} = $sec;
}

# like: time1 - time2
sub minuteDiff
{

	my $t1 = shift;	
	my $t2 = shift;

	if ( !$t1 || !$t2 ) {
	  print "t1: $t1 t2: $t2\n";
	  print "WARNING: can't calculate time difference\n";
	  my ($package, $filename, $line) = caller;
	  print STDERR "in minuteDiff: pck=$package, fname=$filename, line=$line\n";
	  return -1;
	}

	#return -1 if ( !$t1 || !$t2 ); 

#xx	my @info = caller(2);
#xx	my $package = $info[0];
#xx	my $filename = $info[1];
#xx	my $line = $info[2];
#xx	my $subroutine = $info[3];
#xx	my $log_fname = "/h/eol/snorman/git_work/sat_query/scripts/logs/time.log";
#xx	if ( !$t1 || !$t2 ) {
#xx	  open(LOG, ">>$log_fname") || die "cannot open $log_fname";
#xx	  print LOG "in minuteDiff:\n";
#xx	  print LOG "package = $package\n";
#xx	  print LOG "filename = $filename\n";
#xx	  print LOG "line = $line\n";
#xx	  print LOG "subroutine = $subroutine\n";
#xx	  print LOG "t1=$t1 and t2=$t2\n";
#xx	  close(LOG);
#xx	  exit();
#xx	}
	

	my $m1 = $t1->{hour} * 60 + $t1->{min};
	my $m2 = $t2->{hour} * 60 + $t2->{min};

	return $m1 - $m2;			
}

# returns a new time with the added time: $newtime = $time->add( $addtime )
sub add
{
	my $self = shift;
	my $add = shift;
	my $new = Time->new();

	$new->{hour} = $self->{hour} + $add->{hour};
	$new->{min} = $self->{min} + $add->{min};
	$new->{sec} = $self->{sec} + $add->{sec};

	if( $new->{sec} >= 60 )
	{
		$new->{min}++;
		$new->{sec} -= 60;
	}
	if( $new->{min} >= 60 )
	{
		$new->{hour}++;
		$new->{min} -= 60;
	}
	if( $new->{hour} >=24 )
	{
		$new->{hour} -= 24;
	}
	
	return $new;
}

sub getTime
{
	my $self = shift;
	return( sprintf( "%2.2d", $self->{hour} ) . ":" . sprintf( "%2.2d", $self->{min} ) . ":" . sprintf( "%2.2d", $self->{sec} ) );  
}
1;
