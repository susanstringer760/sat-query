#!/usr/bin/perl -I./config

use File::Basename;
use FindBin qw($Bin);
use CGI;
use DBI;
use File::Basename;
#use Time::Local;
use File::Path qw(make_path);
use FindBin qw($Bin);
require "config.pl";

sub get_request_info
{

  my $data_query = shift;
  my $cssFname = shift;
  my $retrieval_js = shift;
  my $base_cgi = shift;

  # the request form

  my @list_of_files = keys(%size_hash);

  print $data_query->header(-title=>'EOL Satellite Query');
  print $data_query->start_html(-title=>'EOL Satellite Query Data Request',
                           -bgcolor=>'#FFFFFF',
			   -script => { -language=>'javascript',
			                -src=>$retrieval_js },
                           -style=>{-src=>"$cssFname"});
  print "<p></p><p></p>\n";
  print $data_query->start_form(-name =>'form_input', 
                                -method=>'post',
				-onsubmit=>"return validate_input(this);"); 
  print "<table border='1' id ='user_data', align='center'>\n";
  print "<tr><td colspan='2' align='center'>".$data_query->h3("Please enter request information");
  print "<tr>\n";
  print "  <td><span class='required'>&nbsp;*&nbsp;</span><b>".$data_query->label("First name")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'first_name')."</td>\n";
  print "</tr>\n";
  print "<tr>\n";
  print "  <td><span class='required'>&nbsp;*&nbsp;</span><b>".$data_query->label("Last name")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'last_name')."</td>\n";
  print "</tr>\n";

  # organiztion
  print "<tr>\n";
  print "  <td>&nbsp;&nbsp;<b>".$data_query->label("Organization")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'organization')."</td>\n";
  print "</tr>\n";


  # affiliation
  my $value_ref = [];
  push(@$value_ref, 'ncar_ucar');
  push(@$value_ref, 'us_univ');
  push(@$value_ref, 'us_gov');
  push(@$value_ref, 'us_comm');
  push(@$value_ref, 'foreign_univ');
  push(@$value_ref, 'foreign_gov');
  push(@$value_ref, 'foreign_comm');
  push(@$value_ref, 'other');

  my $label_ref = {
    'ncar_ucar'=>'NCAR/UCAR',
    'us_univ'=>'US University',
    'us_gov'=>'US Government Agency (eg: NOAA, NASA, etc.)',
    'us_comm'=>'US Commercial Company',
    'foreign_comm'=>'Foreign Commercial Company',
    'foreign_gov'=>'Foreign Government Agency',
    'foreign_univ'=>'Foreign University',
    'other'=>'Other',
    };

  print "<tr>\n";
  print "  <td valign='top'><span class='required'>&nbsp;*&nbsp;</span><b>".$data_query->label("Affiliation")."</b></td>\n";
  print "  <td>\n";
  print $data_query->radio_group(-name=>'affiliation',
                            -values=>$value_ref,
			    -default=>'',
			    -linebreak=>true,
			    -labels=>$label_ref);
  print "  </td>\n";
  print "</tr>\n";

  print "<tr>\n";
  print "  <td><span class='required'>&nbsp;*&nbsp;</span><b>".$data_query->label("Email")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'email')."</td>\n";
  print "</tr>\n";

  print "<tr>\n";
  print "  <td>&nbsp;&nbsp;<b>".$data_query->label("Phone")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'phone')."</td>\n";
  print "</tr>\n";

  print "<tr>\n";
  print "  <td>&nbsp;&nbsp;<b>".$data_query->label("Address")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'address')."</td>\n";
  print "</tr>\n";

  print "<tr>\n";
  print "  <td>&nbsp;&nbsp;<b>".$data_query->label("City")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'city')."</td>\n";
  print "</tr>\n";

  print "<tr>\n";
  print "  <td>&nbsp;&nbsp;<b>".$data_query->label("State")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'state')."</td>\n";
  print "</tr>\n";
  print "<tr>\n";
  print "  <td>&nbsp;&nbsp;<b>".$data_query->label("Zip")."</b></td>\n";
  print "  <td>".$data_query->textfield(-name=>'zip')."</td>\n";
  print "</tr>\n";
  print "<tr>\n";
  print "  <td valign='top'>&nbsp;&nbsp;<b>".$data_query->label("Files")."</b></td>\n";
  print "  <td>\n";
  # create an array of data files where each value is
  # a hash containing file information (name,dir,size)
  my @file_list = $data_query->param('data_files');
  my @data_file_arr;
  my @fname_only;
  foreach $file (@file_list) {
    my ($full_path,$size)  = split(';', $file);
    my $fname = basename($full_path);
    my $dir = dirname($full_path);
    my $hash_ref = {'fname'=>$fname, 'dir'=>$dir, 'size'=>$size};
    push(@fname_only, $fname);
    push(@data_file_arr, $hash_ref);
  }
  my $default_value = join("\n",@fname_only);
  print $data_query->textarea(-name=>'files',
			     # $-default=>[$#list_of_files],
			      -default=>$default_value,
			      -rows=>5,
			      -columns=>50,
			      -readonly=>'readonly');


  print "  </td>\n";
  print "</tr>\n";

  # compression 
  $value_ref = [];
  push(@$value_ref, 'none');
  push(@$value_ref, 'gzip');

  $label_ref = {
    'gzip'=>'GZIP',
    'none'=>'NONE',
  };
  print "<tr>\n";
  print "  <td valign='top'><b>".$data_query->label("Compression")."<b></td>\n";
  print "  <td>\n";
  print $data_query->radio_group(-name=>'compression',
                            -values=>$value_ref,
			    -default=>'gzip',
			    -linebreak=>true,
			    -labels=>$label_ref);
  print "  </td>\n";
  print "</tr>\n";
  print "<tr><td colspan=2 align=center>\n";
  print $data_query->submit(-name=>"submit_request", -value=>"Submit");
  print "</td></tr>\n";
  print "</table>\n";

  # the hidden fields containing the size and directory information
  # the list of selected data files
  foreach $file (@data_file_arr) {
    my $name = $file->{'fname'};
    my $dir = $file->{'dir'};
    my $size = $file->{'size'};
    my $value = "$dir/$name;$size";
    print $data_query->hidden(-name=>$name, -value=>$value);
    print "<br>\n";
  }

  print $data_query->end_form();
  print $data_query->end_html();
  print "</table>\n";

}

#sub xxprocess_request_form {
#
#  my $data_query = shift;
#  my $cssFname = shift;
#  my $hsi_exe = shift;
#  my $max_request_size = shift;
#
#  # first, validate entries
#  validate_request_form($data_query, $cssFname);
#
#  #get_files_from_hpss(\@list_of_files, $hsi_exe);
#  get_files_from_hpss($data_query, $hsi_exe, $max_request_size);
#
##  foreach my $p ($data_query->param()) {
##    $form{$p} = $data_query->param($p);
##    print_warning("$p = $form{$p}");
##  } 
##  print_error("testit");
##
##  my $test_dir = "/scr/ctm/snorman/testit";
##  my $cmd = "mkdir $test_dir";
##  system($cmd);
#
#}

sub get_requested_filenames {

  my $data_query = shift;
  my $max_request_size = shift; # in gb

  my $kb_to_gb = .000001;

  my @list_of_files = split(/\s+/, $data_query->param('files'));

}

#sub get_files_from_hpss {
sub check_request_size {

  # Subroutine to make sure request size
  # isn't too large.  Returns a list of files
  # that can be processed and errors if max
  # size exceeded
  my $data_query = shift;
  my $max_request_size = shift; # in gb

  my $kb_to_gb = .000001;

  my @list_of_files = split(/\s+/, $data_query->param('files'));

  # make sure the request size doesn't exceed limit
  my $full_path;
  my (@files_to_copy, @files_to_exclude);
  my $total_request_size_gb = 0;
  my $timestamp = localtime();
  my $warning = "$timestamp: WARNING: request file size exceeded. Must be less than $max_request_size GB. Unable to process the following files:"; 

  #push(@warning_arr, $warning);

  foreach $file (@list_of_files) {
    my ($full_path,$size_kb) = split(/;/, $data_query->param($file));
    # convert file size to gb
    $size_gb = $size_kb * $kb_to_gb;
    $total_request_size += $size_gb;
    if ( $total_request_size > $max_request_size ) {
      #push(@$status_ref, "\t$file");
      #push(@warning_arr, $full_path);
      push(@files_to_exclude, $full_path);
    } else {
      push(@files_to_copy, $full_path);
    }

  }

  return [\@files_to_copy, \@files_to_exclude];

}

#sub create_archive_dir
sub get_request_id
{

  # create the archive directory
  my $data_query = shift;
  my @errors;

  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time); 
  $year += 1900;
  $mon += 1;
  my $date_time = sprintf("%4d%02d%02d%s%02d%02d%02d",
                           $year,$mon,$mday,"_",$hour,$min,$sec);
  #my $date_time = "$year$mon$mday"."_"."$hour$min$sec";

  # now assemble the path
  my $first_name = lc($data_query->param('first_name'));
  my $last_name = lc($data_query->param('last_name'));
  my $dir_name = "$first_name"."_"."$last_name.$date_time";

  return $dir_name;
#  # finally create the directory
#  umask(0);
#  make_path($dir_name, {mode=>0775});
#
#  # no errors
#  return[$dir_name, [] ] if ( $#$err < 0 );
#
#  # put errors in array
#  my @error_list;
#  push(@error_list, "Error creating $dir_name\n");
#  foreach $error(@$err) {
#    foreach $key (keys(%$error)) {
#      push(@error_list, "\t".$error->{$key}."\n");
#    }
#  }
#
#  return[$dir_name, \@error_list];
  
}

sub fetch_files_from_hpss
{

  my $request_id = shift;
  my $data_query = shift;
  my $file_and_warning_arr_ref = shift;
  my $constants_ref = shift;

  my (@admin_warning, @admin_error,@user_warning, @user_error);
  my $admin_warning = [];
  my $admin_error = [];
  my $user_confirmation = [];
  my $user_error = [];

  # constants
  my $retrieval_script = $constants_ref->{'retrieval_script'};
  my $log_dir = $constants_ref->{'log_dir'};
  my $mail_cmd = $constants_ref->{'mail_cmd'};
  my $request_dir = $constants_ref->{'request_dir'};
  my $data_retrieval_script = $constants_ref->{'data_retrieval_script'};
  my $hpss_exit_codes = $constants_ref->{'hpss_exit_codes'};
  #my $css_fname = $constants_ref->{'css_fname'};

  # list of files to process
  my @files_to_include = @{$file_and_warning_arr_ref->[0]};
  my @files_to_exclude = @{$file_and_warning_arr_ref->[1]};

  # put the request info in a file
  my $request_fname = "$request_dir/$request_id.txt";
#open(ASDF, ">$request_fname");
#close(ASDF);
#print_error("testit: $request_fname");
  if ( !open(REQUEST, ">$request_fname") ) {
    # admin
    $msg = get_email_content($data_query, 'admin_error', $request_id);
    push(@{$admin_error}, $msg);
    push(@{$admin_error}, "ERROR: couldn't create request: $request_fname");

    # user
    $flag = 'failed_request';
    $msg = get_email_content($data_query, $flag, $request_id);
    push(@{$user_error}, $msg);
  } else {
    create_request($data_query, *REQUEST, \@files_to_include, \@files_to_exclude);
    # request confirmation
    $flag = 'user_confirmation';
    $msg = get_email_content($data_query, $flag, $request_id);
    push(@{$user_confirmation}, $msg);
  }


#  if ( $status != 0 ) {
#    my $error = $hpss_exit_codes->{$status};
#
#    print_warning("sending email to admin: $cmd = $error");
#    print_warning("sending email to user: $cmd = $error");
#    exit();
#  }

  my $status_ref = {'admin_error' => $admin_error,
                    'admin_warning' => $admin_warning,
                    'user_error' => $user_error,
                    'user_confirmation' => $user_confirmation,
                   };

  return $status_ref;

}
#sub ffetch_files_from_hpss
#{
#
#  my $data_query = shift;
#  my $arr_ref = shift;
#  my $constants_ref = shift;
#
#  # constants
#  my $retrieval_script = $constants_ref->{'retrieval_script'};
#  my $log_dir = $constants_ref->{'log_dir'};
#  my $mail_cmd = $constants_ref->{'mail_cmd'};
#  my $admin_email= $constants_ref->{'admin_email'};
#  my $css_fname = $constants_ref->{'css_fname'};
#
#  my $timestamp;
#
#  # reference to array that contains
#  # errors
#  my @admin_error;
#  my @user_error;
#  my @user_confirmation;
#
#  # list of files to process
#  my @list_of_files = @{$arr_ref->[0]};
#  # list of files that cannot be processed
#  my @request_size_error = @{$arr_ref->[1]};
#
#  # get archive id 
#  my $archive_id = get_archive_id($data_query);
#
#  # create the request info file 
#  my $request_info_dir = "$log_dir/data_retrieval/$archive_id";
#  my $request_info_fname = "$request_info_dir/request_info.txt";
#  my $err = create_dir($request_info_dir);
#  # populate admin error array
#  if ( $#$err >= 0) {
#    $timestamp = localtime();
#    push(@admin_error, "$timestamp: ERROR: couldn't create $request_info_dir");
#  }
#
#  # put the request info in a file
#  my $info_fname = "$request_info_dir/request_information";
#  if ( !open(INFO, ">$info_fname") ) {
#    $timestamp = localtime();
#    push(@admin_error, "$timestamp: ERROR: couldn't create status file: $info_fname");
#    # email content for user 
#    my $content_ref = get_email_content($data_query, "failed_request", []);
#    foreach $line (@$content_ref) {
#      push(@user_error, $line);
#    }
#  } else {
#    create_request($data_query, *INFO, \@list_of_files);
#  }
#  close(INFO);
#
#  if ($#user_error < 0 ) { 
#    # no errors so far
#    foreach $file  (@list_of_files) {
#      #system("$retrieval_script -i $archive_id -f $file");
#      #print_warning("$retrieval_script -i $archive_id -f $file");
#      $retrieval_script = "/h/eol/snorman/git_work/sat_query/cgi-bin/hpss_tmp/test1.pl";
#      system($retrieval_script);
#      print_error("done!");
#      print_error("$retrieval_script -i $archive_id -f $file");
#    }
#    foreach $error (@size_err_arr) {
#      print_warning("error: $error");
#    }
#    print_error("asdf");
#  }
#
#  my $status_ref = {
#                   'admin_error'=>\@admin_error,
#                   'user_error'=>\@user_error,
#                   'user_confirmation'=>\@user_confirmation,
#		   };
#
#  return $status_ref;
#
#  
#}
#sub ffetch_files_from_hpss
#{
#
#  my $arr_ref = shift; # a reference to an array containing file list and errors
#  my $archive_dir = shift; # where the archived files go
#  my $hsi_exe = shift;
#  my $hpss_exit_codes = shift;
#
#  my $error_ref = $arr_ref->[1];
#  my $hpss_ref = $arr_ref->[0];
#
#  # hash where the key is the hpss path and the
#  # value is the local path
#  my %file_hash;
#  foreach $hpss_path(@$hpss_ref) {
#    my $local_path = "$archive_dir/".basename($hpss_path);
#    my $cmd = "$hsi_exe get $local_path : $hpss_path";
#    print_warning("cmd: $cmd");
#    #my $cmd = "hsi get $local_path : $hpss_path";
#    #my ($results,$status) = execute_command($cmd);
#    #print_warning("results: $results");
#    #print_error("status: $status");
#  }
#print_error("qwer");
#
#  foreach $error(@$error_ref) {
#    my $local_fname = basename($error);
#    print_warning("not processing $error");
#  }
#  print_error("xx");
#
#
#}

sub validate_request_form {

  my $data_query = shift;
  my $css_fname = shift;

  # validate form entries (and untaint them)

  # first initialize to true
  my %is_valid;
  foreach my $p ($data_query->param()) {
    $form{$p} = $data_query->param($p);
    $is_valid{$p} = true;
  } 

  my $valid_flag;
  my $form_value_ref = {};
  my @errors;
  my $error_ref = [];

  my $value;
  foreach $param (keys(%is_valid)) {
     next if ($param eq 'files');
     next if ($param eq 'submit_request');
     next if ( $param =~ /^([gG]\d{2})/ );
     $value = $data_query->param($param);
     ($param eq 'email' ) ?
       ($value =  untaint_email($param, $data_query)) :
       ($value = untaint_text($param, $data_query));

     $form_value_ref->{$param} = $value;
     push(@errors, "ERROR: invalid entry for $param!") if ( $value eq 'failed' );

  } # end foreach

  display_errors($data_query,$css_fname,\@errors) if ( $#errors >= 0);

  my @files = split('\s+', $data_query->param('files'));

  # return reference to a list of files
  return \@files;

  #return $status;
  #return \@files if ( $#errors < 0 );

  #display_errors($data_query,$css_fname,\@errors);

#  foreach $file (@files) {
#    $form_value_ref->{$file} = $data_query->param($file);
#    print_warning("xx: ".$form_value_ref->{$file});
#  }
#
#  return $form_value_ref if ( $#errors < 0 );
#
#  display_errors($data_query,$css_fname,\@errors);

#  # validation failed...print out error message
#  print $data_query->header("EOL Satellite Query Data Retrieval");;
#  print $data_query->start_html(-title=>'EOL Satellite Query Data Retrieval',
#                                -style=>{-src=>"$base_url/css/query.css"},
#                                -bgcolor=>'#FFFFFF');
#  if ( $#error_msg >= 0 ) {
#    foreach $msg (@error_msg) {
#      print $data_query->p({-class=>'error'},$msg);
#    }
#  }
#  print "<p></p>\n";
#  print "<center><a href='javascript:window.history.back();'>Back to request form</a></center><p></p>\n";
#  print $data_query->end_html();
#  exit();
 
}
sub untaint_email {

  my $param = shift;
  my $data_query = shift;

  my $value = $data_query->param($param);

  if ($value =~ /^([\w\-\_\.)]+)\@([\w\-\_\.]+)\.([a-zA-Z]{2,})$/ ) {
    $value = "$1\@$2.$3";
    return $value;
  } 
  return 'failed';

}

sub untaint_text {

  my $param = shift;
  my $data_query = shift;

  my $value = $data_query->param($param);

  return $value if ($value eq '');

  if ( $value =~ /([a-zA-Z]+[\-\_]*[a-zA-Z]*)/ ) {
    $value = $1;
    return $value;
  } 
  return 'failed';

}

sub xxprocess_info
{
  my $data_query = shift;

}
sub xxprint_data_form
{

print_error("in print_data_form");
  my $data_query = shift;

}
sub xxprocess_data_form
{

print_error("in process_data_form");
  my $data_query = shift;
  my $param_ref = $data_query->param_fetch('mss_files');
  print_warning("in process_data_form");
  foreach $xx (@$param_ref) {
    print_warning("testit: $xx");
  }
}
sub no_files_selected
{

  my $data_query = shift;
  my $cssFname = shift;
  my $msg_ref = shift;

  display_errors($data_query, $cssFname, $msg_ref);
  
}
sub xxno_files_selected
{

  my $data_query = shift;
  my $base_url = shift;

  # print out error message if there aren't any files selected
  
  print $data_query->header("EOL Satellite Query Data Retrieval");;
  print $data_query->start_html(-title=>'EOL Satellite Query Data Retrieval',
                           -bgcolor=>'#FFFFFF',
                           -style=>{-src=>"$base_url/css/query.css"});

  print $data_query->h3({-class=>'error'},'ERROR: No data files selected');
  my $from_url = $ENV{'HTTP_REFERER'}; 
  print $data_query->h3({-class=>'error'},$data_query->a({-href=>"$from_url"},"Back to file list"));
  print $data_query->end_html();
  exit();

}
sub display_confirmation
{

  # display confirmation 
  my $data_query = shift; 
  my $css_fname = shift;
  my $request_id = shift;

  # print out error message
  print $data_query->header("EOL Satellite Query Data Retrieval");;
  print $data_query->start_html(-title=>'EOL Satellite Query Data Retrieval',
                                -style=>{-src=>"$css_fname"},
                                -bgcolor=>'#FFFFFF');
  my @msg;
  push(@msg, localtime()." Request id: $request_id has been submitted");
  push(@msg, "You will receive and email with the status of this request.\n");
  push(@msg, "Thank you.");

  my $content = join("<br>", @msg);

  print $data_query->p({-class=>'confirmation'}, $content);
  print $data_query->end_html();

}
sub display_errors
{

  my $data_query = shift;
  my $css_fname = shift;
  my $error_ref = shift;
  my $error_type = shift;
  my @errors = @$error_ref;

  # print out error message
  print $data_query->header("EOL Satellite Query Data Retrieval");;
  print $data_query->start_html(-title=>'EOL Satellite Query Data Retrieval',
                                -style=>{-src=>"$css_fname"},
                                -bgcolor=>'#FFFFFF');
  if ( $#$error_ref >= 0 ) {
    foreach $msg (@$error_ref) {
      print $data_query->p({-class=>'error'},$msg);
    }
  } 
  print "<p></p><center><a href='javascript:window.history.back();'>Back</a></center><p></p>\n";
  print $data_query->end_html();

  exit();

}
sub send_email 
{

  my $data_query = shift;
  my $mail_cmd = shift;
  my $to = shift;
  my $from = shift;
  my $subject = shift;
  my $css_fname = shift;
  my $content_arr_ref = shift;
  my $email_type = shift;
  my $content_str;
  $content_str = $content_arr_ref->[0] if ( $#$content_arr_ref == 0 );
  $content_str = join("",@$content_arr_ref) if ( $#$content_arr_ref > 0); 

  open(SENDMAIL, "|$mail_cmd") or die "Cannot open $mail_cmd: $!"; 
  print SENDMAIL "Reply-to: $from\n";
  print SENDMAIL "From: $from\n";
  print SENDMAIL "Subject: $subject\n";
  print SENDMAIL "To: $to\n";
  print SENDMAIL "Content-type: text/plain\n\n";
  print SENDMAIL "$content_str\n";
  close(SENDMAIL);

  # print error message to display
  if ( $email_type eq 'failed_request') {
    print $data_query->header();
    print $data_query->start_html(-title=>'EOL Satellite Query Error',
                               -bgcolor=>'#FFFFFF',
                               -style=>{-src=>"$css_fname"});
    print $data_query->p();
    print $data_query->p();
    print $data_query->p();
    print $data_query->p();
    my $error_msg = "WARNING: there was an error processing this request.<br>Please contact the ";
    $error_msg .= $data_query->a({-href=>"mailto:$from"},"administrator");
    $error_msg .= " for questions regarding this request";
    print "<table border='0' id='warning'>\n<tr><td>$error_msg</td></tr>\n</table>\n";
    print $data_query->end_html();
  }


#  $mail = "To: $to\n".
#          "From:$from\n".
#          "Reply-To:$from".
#          "Subject:$subject\n\n".
#	  $content_str;
#       #open(MAIL, "$mail_cmd") || die "cannot open mail command!";
#       open(MAIL, "|$xx") || die "cannot open mail command!";
#       #print MAIL "$content";
#       print MAIL "$mail";
#       close(MAIL);
#       #system($mail_cmd);
#       exit();

}
sub get_admin_content
{

  my $content_ref = shift;
  my $source = $content_ref->[0];
  my $errors = $content_ref->[1];

  my @content;

  push(@content, "The following errors have been detected for $source:\n");
  foreach $error (@$errors) {
    push(@content, "\t$error");
  }

  return \@content;

}
sub execute_command {

  my $command = join ' ', @_;
  ($_ = qx{$command 2>&1}, $? >> 8);

}
sub create_dir {

  my $dir = shift;
  my $mode = shift;

  return if ( -e $dir ); # directory already exists!

  # create the directory
  #umask('0007');
  umask(0);
  #umask($mask);
  #make_path( $dir, { error => \my $err } );
  make_path( $dir, { error => \my $err, mode=>$mode} );
  return $err if ( @$err );
  return [];

}
sub create_request {

  my $data_query = shift;
  my $file_handle = shift;
  my $include_file_ref = shift;
  my $exclude_file_ref = shift;
  my @files;

  $timestamp = localtime();
  my $first_name = $data_query->param('first_name');
  my $last_name = $data_query->param('last_name');
  my $email = $data_query->param('email');
  my $affiliation= $data_query->param('affiliation');
  my $total_size = 0;
  foreach $file (@$include_file_ref) {
    my $fname = basename($file);
    push(@files, $fname);
    my $value = $data_query->param($fname);
    # file size
    my $fsize = (split(/;/, $value))[1];
    $total_size += $fsize;
  }
  # set total size to mb from kb
  $total_size *= .001;
  print $file_handle "Date: $timestamp: data request information\n";
  print $file_handle "Name: $first_name $last_name\n";
  print $file_handle "Email: $email\n";
  print $file_handle "Affiliation: $affiliation\n";
  #foreach $file (@files) {
  foreach $file (@$include_file_ref) {
    print $file_handle ("Include: $file\n");
  }
  print $file_handle ("Size: $total_size MB\n");
  foreach $file (@$exclude_file_ref) {
    print $file_handle ("Exclude: $file\n");
  }

}
sub get_email_content {

    my $data_query = shift;
    my $error_type = shift;
    my $request_id = shift;

    my @content_arr;
    if ( $error_type eq 'failed_request' ) {
      push(@content_arr, "Hi ".$data_query->param('first_name').",\n");
      push(@content_arr, "Request id: $request_id\n");
      push(@content_arr, "There was an error processing your request submitted on ".localtime().".\n");
      push(@content_arr, "The administrator has been notified and you will recieve an email once the issue has been resolved.\n");
      push(@content_arr, "Thank you for your patience.\n");
    } elsif ( $error_type eq 'admin_error') {
      push(@content_arr, localtime().": Error processing $request_id\n\n");
    } elsif ( $error_type eq 'user_confirmation') {
      push(@content_arr, "Hi ".$data_query->param('first_name').",\n");
      push(@content_arr, "Request id: $request_id\n");
      push(@content_arr, "Your request has been submitted.  You will receive an email with further instructions when the request is complete");
    }

    return $content_arr[0] if ( $#content_arr== 0);
    return join("\n", @content_arr);

}
1;
