#!/usr/bin/perl -I./config -I./
#
use Getopt::Std;
use CGI;
use File::Basename;
use File::Path qw(make_path);
use FindBin qw($Bin);
use FindBin qw($Bin);
require "$Bin/config/config.pl";
require "data_retrieval.include.pl";

my $hpss_exit_codes = hpssExitCodes();
my $hsi_exe = hsiExe();
my $ftp_dir = ftpDir();
my $ftp_url = ftpUrl();
my $ftp_cmd = $ftp_url;
$ftp_cmd =~ s/^ftp:\/\//ftp /g;
my $incoming_dir = incomingDir();
my $finished_dir = finishedDir();
my $error_dir = errorDir();
my $hsi_exe = hsiExe();
my $admin_email = adminEmail();
my $mail_cmd = mailCmd(); 

use Fcntl ':flock';
open my $self, '<', $0 or die "Couldn't open self: $!";
flock $self, LOCK_EX | LOCK_NB or die "$0 is already running";

# read the request(s) from incoming directory
opendir(INCOMING, $incoming_dir) or die "cannot open $incoming_dir";
my @list_of_requests = grep {/.txt$/} readdir(INCOMING);
closedir(INCOMING);

exit() if ($#list_of_requests < 0 );
#@list_of_requests = map("$incoming_dir/$_", @list_of_requests);

# process the requests in incoming directory
my (@include_files, @exclude_files, @commands,%user_status_hash, %admin_status_hash);
my $subject;

# flag to send admin error when request complete
my $admin_email_flag = false;

foreach $request (@list_of_requests) {

  my (%user_status_hash, %admin_status_hash);

  # parse the request
  my $full_path = "$incoming_dir/$request";
  my $request_hash_ref = parse_request($full_path);
  @include_files = @{$request_hash_ref->{'include_files'}};
  @exclude_files = @{$request_hash_ref->{'exclude_files'}};

  # assemble ftp dir
  my $request_id = $request;
  $request_id =~ s/.txt//g;
  my $mode = 0755;
  #$error_ref = create_dir("/xx$ftp_dir/$request_id", $mode);
  $error_ref = create_dir("$ftp_dir/$request_id", $mode);

  my ($email_body,$admin_msg, $user_msg);

  # send email if ftp directory can't be created
  if ($#$error_ref > -1 ) {

    # move request to error directory
    my $source_fname = "$incoming_dir/$request";
    my $dest_fname = "$error_dir/$request";
    #print "moving $source_fname to $dest_fname\n";exit();

    # send email to admin
    $subject = "EOL Satellite data retrieval error";
    $admin_msg = "Can't create $ftp_dir/$request_id\n\n";
    $admin_msg .= "moving $source_fname to $dest_fname\n";
    rename($source_fname,$dest_fname);
    $email_body = admin_email_body($request_id, $admin_msg, 'error');
    send_mail($mail_cmd, $admin_email, $admin_email, $subject, $email_body);

    # send email to user
    $user_msg = 'You will be notified when the error has been resolved.';
    $email_body = user_email_body($request_id, $user_msg, 'error');
    send_mail($mail_cmd, $request_hash_ref->{'email'}, $admin_email, $subject, $email_body);
    exit();

  } # end if ftp directory error

  # pull files from hpss
  my $count = 0;
  my @hpss_msg;
  push(@hpss_msg, "Error getting files from hpss");

  foreach $file (@include_files) {
    # hpss file name
    my $hpss_path = $file;

    # fname only
    my $fname = basename($hpss_path);

    # local file name
    my $local_path = "$ftp_dir/$request_id/$fname";

    # command to get the files
    my $cmd = "$hsi_exe get $local_path : $hpss_path";
    my ($results,$status) = execute_command($cmd);

    # status for user email
    #my $status = 0;
    #$status = 72 if ($count==1);
    #my $status = 72;
    if ($status != 0 ) {
      # send email to admin
      push(@hpss_msg, "$hpss_path: ".$hpss_exit_codes->{$status});
      next();
    }
    $count++;
  } # end foreach file

  if ( $#hpss_msg > 0 ) {

    # an error occurred getting files from hpss

    # send email to admin
    $subject = "EOL Satellite data retrieval error";
    my $admin_msg = join("\n", @hpss_msg);
    $email_body = admin_email_body($request_id, $admin_msg, 'error');
    send_mail($mail_cmd, $admin_email, $admin_email, $subject, $email_body);

    # move request to error directory
    my $source_fname = "$incoming_dir/$request";
    my $dest_fname = "$error_dir/$request";
    rename($source_fname,$dest_fname);

    # send email to user
    $user_msg = 'You will be notified when the error has been resolved.';
    $email_body = user_email_body($request_id, $user_msg, 'error');
    send_mail($mail_cmd, $request_hash_ref->{'email'}, $admin_email, $subject, $email_body);

  } else {

    $subject = "EOL Satellite data retrieval confirmation";
    $user_msg = "The following files have been successfully transferred:\n";
    $include_ref = $request_hash_ref->{'include_files'};
    $exclude_ref = $request_hash_ref->{'exclude_files'};
    foreach $file (@$include_ref) {
      $user_msg .= "\t$file\n";
    }
    if ( $#$exclude_ref >= 0)  {
      $user_msg .= "The following files have not been transferred because the size of the request exceeded the limit:\n";
      foreach $file (@$exclude_ref) {
        $user_msg .= "\t$file\n";
      }
    }
    $email_body = user_email_body($request_id, $user_msg, 'confirmation');
    send_mail($mail_cmd, $request_hash_ref->{'email'}, $admin_email, $subject, $email_body);

    # move request to finished directory
    my $source_fname = "$incoming_dir/$request";
    my $dest_fname = "$finished_dir/$request";
    rename($source_fname,$dest_fname);

  }

} # end foreach request 
  exit();

sub get_fname_from_hpss {

  my $results = shift;
  my @hsi_output = split(/\n/, $results);
  shift(@hsi_output);
  my ($local_fname, $hpss_fname);
  foreach $output (@hsi_output) {
    ($local_fname, $hpss_fname) = split(':', $output);
    $local_fname =~ s/get//g;
    $local_fname =~ s/\s+//g;
    $local_fname =~ s/'//g;
  }
  print localtime().": ".basename($local_fname)." successfully copied\n";
}

sub user_email_body {

  my $request_id = shift;
  my $msg = shift;
  my $status = shift;
  my $request_hash_ref = shift;
  my $local_time = localtime();

  my $full_msg = '';

  if ( $status eq 'error' ) {

    $full_msg .= "$local_time: There was an error processing request id: $request_id\n\n";
    $full_msg .= "$msg\n\n";
    $full_msg .= "Thank you for your patience.\n\n";

  } elsif ($status eq 'confirmation') {

    $full_msg .= "$msg\n";
    # success! send email to user with data retrieval instructions
    my $instructions = get_instructions($request_id, $request_hash_ref);
    $full_msg .= "$instructions\n";
    $full_msg .= "Thank you!\n";

  }


$body =  <<"EOF";

$full_msg

  
EOF

  return $body;

}

sub admin_email_body {

  my $request_id = shift;
  my $msg = shift;
  my $status = shift;
  my $local_time = localtime();

$body =  <<"EOF";

$local_time: There was an error processing request id: $request_id 

$msg
  
EOF

  return $body;

}

sub get_instructions {

  # the instructions for the confirmation email
  my $request_id = shift;
  # hash containing info from request 
  my $request_hash_ref = shift;

  @include_files = @{$request_hash_ref->{'include_files'}};
  @exclude_files = @{$request_hash_ref->{'exclude_files'}};

  my $ftp_url = ftpUrl();
  my $ftp_cmd= ftpCmd();

  my @instructions;

  push(@instructions, "Instructions to download the files (from browser):");
  push(@instructions, "\t1. $ftp_url/$request_id");
  push(@instructions, "\tSelect each file for download\n");
  push(@instructions, "Instructions to download the files from command line:");
  push(@instructions, "\t# user name = anonymous");
  push(@instructions, "\t1. $ftp_cmd\n"); 
  push(@instructions, "\t# prompt should now be: ftp>");
  push(@instructions, "\t2.ftp>cd pub/hpss/sat_query/$request_id\n");
  push(@instructions, "\t# set to binary mode");
  push(@instructions, "\t3. ftp>binary\n");
  push(@instructions, "\t# turn off prompt (optional)");
  push(@instructions, "\t4. ftp>prompt\n");
  push(@instructions, "\t# get all the files");
  push(@instructions, "\t5. ftp>mget *");

  my $instruction_str = join("\n", @instructions);

  return $instruction_str;

}

sub email_body {

  my $request_id = shift;
  my $info_ref = shift;
  my $msg_type = shift;
  my $status_ref = shift;
  my $body;
  my $ftp_url = ftpUrl();
  my $ftp_cmd= ftpCmd();
  my $max_request_size = maxRequestSize();
  my $local_time = localtime();
  my ($first_name,$last_name) = split(" ",$info_ref->{'name'}); 
  my @instructions = ();

  my $ftp_cmd = $ftp_url;


  # user email body
  if ( $msg_type eq 'user' ) {
$body =  <<"USER";
Hi $first_name,

Request id: $request_id

There was an error processing your request submitted on $local_time..

The administrator has been notified and you will recieve an email once the issue has been resolved

Thank you for your patience.
USER
  } elsif ($msg_type eq 'directory_error') {

$body =  <<"DIRECTORY";

$local_time: Error processing $request_id

DIRECTORY
  #} elsif ($msg_type eq 'user_confirmation') {
  #} elsif ($msg_type =~ /confirmation/ ) {
  } elsif ($msg_type =~ /(user|admin)_(confirmation)/) {

    my $to = $1;
print "zxcvxzv: $to\n";exit();
    my ($salutation);
    ($to eq "admin") ?
      ($salutation = 'Warning: Sat_query data request error') :
      ($salutation = "Hi $first_name,");

    if ( $to eq "user" ) {
      push(@instructions, "Instructions to download the files (from browser):");
      push(@instructions, "\t1. $ftp_url/$request_id");
      push(@instructions, "\tSelect each file for download.");
      push(@instructions, "------------------------------------------");
      push(@instructions, "Instructions to download the files from command line:");
      push(@instructions, "\t1. $ftp_cmd"); 
      push(@instructions, "\t2. $ftp_cmd"); 

    } 

    my $instruction_str = join("\n", @instructions);

    # get the file status of requested files
    my (@success_arr, @failed_arr);
    my $success_str = 'The following file transactions were successful:';
    my $failed_str = 'The following file transactions were unsuccessful:';
    foreach $key (keys(%$status_ref)) {
      my $status = $status_ref->{$key};
      push(@success_arr, "\t$key: $status") if $status eq 'success';
      push(@failed_arr, "\t$key: $status") if $status ne 'success';
    }

    # the files that couldn't be processed because
    # the request size limit was reached
    my @excluded_files = @{$info_ref->{'exclude_files'}};
    @excluded_files = map("\t$_", @excluded_files);
    my $size_str = join("\n", @excluded_files);
  
    #unshift(@success_arr, $success_str);
    #unshift(@failed_arr, $failed_str);
  
    my $success_str = '';
    my $failed_str = '';
    $success_str = join("\n", @success_arr);
    $failed_str = join("\n", @failed_arr);

$body =  <<"HPSS";

$salutation

Request id: $request_id

Here is the status of the following requested files:
$success_str
$failed_str
--------------------------------------
The following files couldn't be processed because the request size exceeded the limit of $max_request_size GB:
$size_str
--------------------------------------
$instruction_str

HPSS

  }

  return $body;

}

sub print_hpss_error {

  my $path = shift;
  my $error_num = shift;

  print "Warning: couldn't process $path\n";
  print "Error code: ".$hpss_exit_codes->{$error_num}."\n";

}

sub parse_request {

  my $request_fname = shift;
  my $request_hash_ref = {};
  #my ($include_ref, $exclude_ref);
  my $include_ref = [];
  my $exclude_ref = [];
  open(REQUEST, $request_fname) || die "cannot open $request_fname";

  while (<REQUEST>) {
    chop;
    my ($key,$value) = split(/:/, $_);
    if ( $key =~ /include/i ) {
      push(@$include_ref, $value);
      next();
    } elsif ( $key =~ /exclude/i ) {
      push(@$exclude_ref, $value);
      next();
    } 
    $key = lc($key);
    $request_hash_ref->{$key} = $value;
  }
  close(REQUEST);

  $request_hash_ref->{'include_files'} = $include_ref;
  $request_hash_ref->{'exclude_files'} = $exclude_ref;

  return $request_hash_ref;

}

sub send_mail {

  my $mail_cmd = shift;
  my $to = shift;
  my $from = shift;
  my $subject = shift;
  my $content = shift;

  open(SENDMAIL, "|$mail_cmd") or die "Cannot open $mail_cmd: $!";
  print SENDMAIL "Reply-to: $from\n";
  print SENDMAIL "From: $from\n";
  print SENDMAIL "Subject: $subject\n";
  print SENDMAIL "To: $to\n";
  print SENDMAIL "Content-type: text/plain\n\n";
  print SENDMAIL "$content\n";
  close(SENDMAIL);

}
