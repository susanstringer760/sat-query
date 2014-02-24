#!/usr/bin/perl -Tw

use strict; 

use CGI qw(:cgi);                       # Include CGI functions
use CGI::Carp qw(fatalsToBrowser);      # Send error messages to browser for
                                        # test purposes
# the getinfo url
my $url = "http://www.eol.ucar.edu/cgi-bin/mss_retrieval/getinfo.cgi?";

# the CGI object
my $query = new CGI;

# the maximum size of the request (in GB)
my $max_size = .10;

# the files
my @files = param("mss_files");

# split out the size and filename from the mss_files parameter
my (@size, @filename, $total_size);
my $i;
for ( $i=0; $i <= $#files; $i++) {
	($size[$i], $filename[$i]) = split(/;/, $files[$i]);
} # end for

my $size_ref = &check_size(\@size, $max_size);
if ( $#size > $#$size_ref ) {
   &print_error( $query, \@filename, $size_ref );
} else {
   # call the getinfo page
   &getinfo( $url, \@filename ); 
} # endif

#*********************************************
sub check_size {

   # check the total size of the request and
   # return a reference to a slice of the array
   # where the slice contains the elements where
   # the size is within the allocated size limits
   my $size_ref = shift;
   my $max_size = shift;
   my $total_size = 0;
   my @arr = @$size_ref;
   my $i;
   for ($i=0; $i <= $#arr; $i++ ) {
      $total_size += $arr[$i] * .000001; # convert to GB
      if ( $total_size > $max_size ) {
         last;
      } # endif
   } # end for

   @arr = @arr[0..$i-1];

   # return a reference to the array slice
   return \@arr;

}
#*********************************************
sub print_error() {

	my $query = shift;
	my $filename_ref = shift;
	my $size_ref = shift;

	# make the filename array the same size as the size array
	my @arr = \@$filename_ref[0..$#$size_ref];
	# now, reassign the reference
	my $filename_ref = \@arr;

	# print out the error page
	print $query->header();
	print $query->start_html();
	print "filename: $#$filename_ref<br>";
	print "size: $#$size_ref<br>";
	print "<h1>error</h1>";
	print $query->end_html();

}
#*********************************************
sub getinfo() {

   my $url = shift;
   my $filename_ref = shift;
   # call the getinfo script to copy the files
   # from the mass store
   my $list_of_files = join(",", @$filename_ref);
   $url .= "file=$list_of_files";
   print $query->redirect($url);

}
