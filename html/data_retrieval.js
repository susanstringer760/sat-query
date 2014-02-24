/* create a window to list the requested files */

// the maximum request size in GB;
max_size = 3.0;
//max_size = .1;

// the total request size
total_size = 0.0;

// the list of filename
list_of_fnames = '';

// the getinfo cgi base command
//cgi_cmd = "http://www.eol.ucar.edu/cgi-bin/mss_retrieval/getinfo.cgi?file=";
//cgi_cmd = "/cgi-bin/sat_query/data_retrieval?data_files=";
cgi_cmd = "/cgi-bin/sat_query/data_retrieval";

function vvalidate_input() {

  return true;
}
// print out an object for testing purposes
function validate_input() {

  var valid = true;

  // make sure the required fields are filled out
  var form = document.form_input;

  // array with all invalid form element names 
  var invalid_arr = new Array();

  // name
  if ( !form.first_name.value ) { invalid_arr.push('first name') }
  if ( !form.last_name.value ) { invalid_arr.push('last name') }
  // email
  if ( !form.email.value ) {
    invalid_arr.push('email');
  } else {
    // validate email
    email_is_valid = validate_email(form.email.value);
    if ( !email_is_valid ) { invalid_arr.push('email') }
  }
  // affiliation
  if ( !is_selected('affiliation')) { invalid_arr.push('affiliation') }

  if ( invalid_arr.length == 0 ) {
    return true;
  } else {
    invalid_str = invalid_arr.join('\n');
    alert('Error: the following fields are mandatory or invalid:\n' + invalid_str);
    return false;
  }

  //document.location = submit_url




}

function is_selected(element) 
{

  var affiliation_arr = document.getElementsByName(element)
  for (var i = 0; i < affiliation_arr.length; i++) {
    if (affiliation_arr[i].checked) { return true; }
  }
  return false;

}

function validate_email(email)
{
  var mailformat = /^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/;  

  if(email.match(mailformat))  {  
    return true;
  }

  return false;

}
function ttestit(item) {

   var count = 0;
   var str = '';
   for (var i in item) {
      if ( count < 10 ) {
         str += i + ' ';
	 count++;
      } else {
         str += i + "\n";
	 count = 0;
      } 
   } 
   alert(str);
   return;
}

function is_toplevel(w) {return (w.parent == w); }

function get_data() {

  data_files = document.data_retrieval_form.elements.data_files;
  var file_arr = new Array();
  for (i=0; i < data_files.length; i++) {
    if ( data_files[i].checked ) {
      // add selected files to an array
      file_arr.push(data_files[i].value);
    }
  }
  file_str = file_arr.join(',');
  cgi_cmd = cgi_cmd + '?data_files=' + file_str

  document.location = cgi_cmd

  return
  

}

function add_file(value) {

   // add a file to the request
   var arr = new Array();
   
   // fetch the filename and size
   arr = value.split(";");
   fname=arr[0];
   fsize=arr[1];

   // calculate the total size of the request (in GB)
   total_size += fsize * .000001;

   // add the filename to the list of files
   list_of_fnames += fname + ',';

   if ( total_size > max_size ) {
      var error_msg = "Warning!  Size of request exceeds " + max_size + 
                      " GB..please submit request";
      alert(error_msg);
      return false;
   } // endif

   return true;

}

//function xxselect_all() {
function select_all_files() {

   var arr = new Array();

   //for (var i=0; i < document.mss_retrieval.elements.length; i++ ) {
   for (var i=0; i < document.data_retrieval_form.elements.length; i++ ) {

      //element = document.mss_retrieval.elements[i];
      element = document.data_retrieval_form.elements[i];

      //if ( element.name == 'mss_files' ) {
      if ( element.name == 'data_files' ) {

         element.checked = true;
         arr = element.value.split(";");

         if (!add_file(element.value)) {
	    return;
	 }  // endif

      } // endif

   } // endfor

   return false;


}

function submit_me() {

   list_of_fnames = list_of_fnames.replace(/,$/, "");
   // submit the request
   cgi_cmd += list_of_fnames;

   // finally, submit the request
   window.open(cgi_cmd,'getinfo', 'width=800,height=800,resizeable,scrollbars,toolbar');
   parent.bottom.document.mss_retrieval.reset();

   // clear the list of filenames
   list_of_fnames = '';

   // go back to the main window
   parent.location = parent.document.referrer;

   return 1;

}
1;
