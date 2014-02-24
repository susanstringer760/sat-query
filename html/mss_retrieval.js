/* create a window to list the requested files */

// the maximum request size in GB;
max_size = 3.0;
//max_size = .1;

// the total request size
total_size = 0.0;

// the list of filename
list_of_fnames = '';

// the getinfo cgi base command
cgi_cmd = "http://www.eol.ucar.edu/cgi-bin/mss_retrieval/getinfo.cgi?file=";

// print out an object for testing purposes
function testit(item) {

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

function select_all() {

   var arr = new Array();

   for (var i=0; i < document.mss_retrieval.elements.length; i++ ) {

      element = document.mss_retrieval.elements[i];

      if ( element.name == 'mss_files' ) {

         element.checked = true;
         arr = element.value.split(";");

         if (!add_file(element.value)) {
	    return;
	 }  // endif

      } // endif

   } // endfor

   return;
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
