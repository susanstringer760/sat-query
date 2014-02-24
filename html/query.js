function resetDate(form, box_changed, box_toset, def)
{
        var year_frm = form.year_frm;
        var year_to = form.year_to;
        var month_frm = form.month_frm;
        var month_to = form.month_to;
        var day_frm = form.day_frm;
        var day_to = form.day_to;

	// reset date options
        year_frm.options[0].selected = true;
        year_to.options[0].selected = true;
        month_frm.options[0].selected = true;
        month_to.options[0].selected = true;
        day_frm.options[0].selected = true;
        day_to.options[0].selected = true;

        setCheckBox(box_changed, box_toset, def);

}
function resetJulianDate(form, box_changed, box_toset, def)
{

	// reset julian date options
        var jdate_frm_yr = form.jdate_frm_yr;
        var jdate_to_yr = form.jdate_to_yr;
        var jdate_frm_dy = form.jdate_frm_dy;
        var jdate_to_dy = form.jdate_to_dy;

        jdate_frm_yr.options[0].selected = true;
        jdate_to_yr.options[0].selected = true;
        jdate_frm_dy.options[0].selected = true;
        jdate_to_dy.options[0].selected = true;

        setCheckBox(box_changed, box_toset, def);

}


function setYearDefault ( box_changed, box_toset, other_box_toset, def )
{

	// resets the year so that when a julian year
	// is selected, the date year is set back to
	// default and vise versa
	//
	// first, update the from/to years
	setCheckBox( box_changed, box_toset, def );

    	var option = document.createElement("option");
    	option.text = def;
    	option.value = def;
    	other_box_toset.appendChild(option);

	// now, reset the other (date or julian date)
	var length = other_box_toset.options.length
	other_box_toset.options[length-1].selected = true;
	//setCheckBox( box_changed, other_box_toset, def );
	

}
function setCheckBox( box_changed, box_toset, def )
{

	var chg_index = box_changed.selectedIndex;
	var set_index =  box_toset.selectedIndex;

	if( box_toset.options[set_index].text == def )
	{
		box_toset.options[ chg_index ].selected = true;
	}
	if( set_index != chg_index )
	{
		box_toset.options[ chg_index ].selected = true;
	}
	return 1;

}

function setTextBox( txt_changed, txt_toset, def )
{
	var chg_val = txt_changed.value
	var set_val = txt_toset.value

	if( set_val == def )
	{
		txt_toset.value = chg_val
	}
}

function setHourChanged( hour, min, def )
{
	var hr_val = hour.value
	var mn_val = min.value

	textChange( hour )
	if( mn_val == def )
	{
		min.value = "00"
	}
}

function textChange( text )
{
	var val = text.value

	if( val.length == 0 )
	{
		val = "00"
	}
	if( val.length == 1 )
	{
		val = "0" + val
	}
	text.value = val
}

function validateForm( form )
{
	var valid = true 
	valid = checkDateTime( form.year_frm, form.month_frm, form.day_frm, form.jdate_frm_yr, form.jdate_frm_dy, form.hour_frm, form.minute_frm, "Begin" );

	if( valid )
		valid = checkDateTime( form.year_to, form.month_to, form.day_to, form.jdate_to_yr, form.jdate_to_dy, form.hour_to, form.minute_to, "End" );

	return valid
}

function checkDateTime( year, month, day, jdate_yr, jdate_dy, hour, minute, type )
{
	var valid = true
	var jyr_i = jdate_yr.selectedIndex;
	var jdy_i = jdate_dy.selectedIndex;

	if( jdate_yr.options[ jyr_i ].text == 'YYYY' && jdate_dy.options[ jdy_i ].text == 'JJJ' )
	{

		//var yr = year.value
		//var mn = month.value
		//var dy = day.value
		var yr = year.options[year.selectedIndex].text;
		var mn = month.options[month.selectedIndex].text;
		var dy = day.options[day.selectedIndex].text;
		var hr = hour.options[hour.selectedIndex].text;
		var min = minute.options[minute.selectedIndex].text;

		if( yr == 'YYYY' || mn == 'MM' || dy == 'DD' )
		{
			valid = false;
			message = 'Date ' + yr + '/' + mn + '/' + dy + ' is invalid' 
			year.focus()	
		} 
		else if( hr == 'HH' || min == 'MM'  )
		{
			valid = false
			message = 'Time ' + hr + ':' + min + ' is invalid' 
			year.focus()
		}
		else if( yr.length != 4 )
		{
			valid = false
			message = "Year entered is not valid.  Must be in YYYY format"
			year.focus()
		}
		else if( mn.length != 2 || mn < 1 || mn > 12 )
		{
			valid = false
			message = "Month entered is not valid.  Must be in MM format and between 1 and 12."
			month.focus()
		}
		else if( dy.length != 2 || dy < 1 || dy > 31 )
		{
			valid = false
			message = "Day entered is not valid.  Must be in DD format and between 1 and 31."
		}
	} 
	else if( jdate_yr.options[ jyr_i ].text != 'YYYY' && jdate_dy.options[ jdy_i ].text == 'JJJ' )
	{
		valid = false
		message = "Please Select a Julian Day" 
		jdate_dy.focus()
	} 
	else if( jdate_yr.options[ jyr_i ].text == 'YYYY' && jdate_dy.options[ jdy_i ].text != 'JJJ' )
	{
		valid = false
		message = "Please Select a Year"
		jdate_yr.focus()
	}

	if( valid )
	{
		if( hour.value > 23 || hour.value < 0 )
		{
			message = "Hour entered is not valid."
			valid = false
			hour.focus()
		}		
		else if( minute.value > 59 || minute.value < 0 )
		{
			message = "Minute entered is not valid."
			minute.focus()
			valid = false
		}
	}

	if( !valid )
	{
		message = type + " date and time not entered correctly.\n" + message
		alert( message )
	}

	return valid
}

function setSectorAndYear( form )
{

  // first, get the satellite selected
  var satellite_options = form.satellite.options;
  var selected_index = form.satellite.selectedIndex;
  var value = satellite_options[selected_index].value;
  value = value.toUpperCase();

  // now, set the available years for the selected satellite
  form.year_frm = setSatelliteYear( form.year_frm, form.jdate_frm_yr, value );
  form.year_to = setSatelliteYear( form.year_to, form.jdate_to_yr,value );
  
  // set the available sectors for the selected satellite
  setSatelliteSector( form, value );

}

//function setSatelliteYear( form, satellite )
function setSatelliteYear( year_select_element, jyear_select_element,satellite )
{

  // set the year based on the selected satellite
  //var year_select_element = form.year_frm;

  //var year_options = form.year_frm.options;
  //var year_options = year_select_element.options;
  satellite = satellite.replace(/GOES-/g, 'G');

  var year_hash = {};
  var meta_arr = document.getElementsByTagName("META")
  var tmp_meta_arr = [];
  var j = 0;
  for (var i=0; i < meta_arr.length; i++) {
    if (meta_arr[i].name.match("sector")) {
      // only select year meta tags
      continue;
    }
    var year = meta_arr[i].name;
    year = year.replace("year::","");
    var satellite_list = meta_arr[i].content;
    if ( satellite.match('ALL') ) {
      //year_hash[year] = year;
      year_hash[year] = '';
      tmp_meta_arr[j] = meta_arr[i];
      j = j+1;
    }
    if ( satellite_list.match(satellite) != null) {
      year_hash[year] = '';
      tmp_meta_arr[j] = meta_arr[i];
      j = j+1;
    }
  } // for year

  // create an array of years so we can sort them
  var year_arr = new Array;
  for (var key in year_hash) {
    year_arr.push(key);
  }
  year_arr = year_arr.sort();
  if ( satellite.match('ALL') ) {
    year_arr[0] = 'YYYY';
  }

  //var tmp_options = form.year_frm.options;
  //var tmp_options = year_select_element.options;

  // clear the year select
  //for(var count = form.year_frm.options.length - 1; count >= 0; count--) {
  //  form.year_frm.options[count] = null;
  //}
  for(var count = year_select_element.options.length - 1; count >= 0; count--) {
    year_select_element.options[count] = null;
  }
  for(var count = jyear_select_element.options.length - 1; count >= 0; count--) {
    jyear_select_element.options[count] = null;
  }

  // finally, set the list of options for the selected satellite
  year_arr.push('YYYY');
  for (var i in year_arr ) {
    var option = document.createElement("option");
    var year = year_arr[i];
    option.text = year;
    option.value = year;
    //option.value = tmp_meta_arr[i].content;
    year_select_element.appendChild(option);
  }

  // set the options for the julian year, but still
  // leave the default value (YYYY) selected
  year_arr.unshift(year_arr.pop());
  for (var i in year_arr ) {
    var option = document.createElement("option");
    var year = year_arr[i];
    option.text = year;
    option.value = year;
    //option.value = tmp_meta_arr[i].content;
    jyear_select_element.appendChild(option);
  }


  year_select_element.selectedIndex = 0;

  return year_select_element;

}

function setSatelliteSector( form, satellite_to_find) {

  var sector_select_element = form.satellite_sector;

  var sector_hash = {};
  var sector_arr = [];
  var meta_arr = document.getElementsByTagName("META");
  for (var i=0; i < meta_arr.length; i++) {
    if (meta_arr[i].name.match("year")) {
      // only select year meta tags
      continue;
    } // end if
    var sector = meta_arr[i].name;
    sector = sector.replace('sector::','');
    var tmp_arr = sector.split("::");
    if ( typeof tmp_arr[1] === 'undefined' ) {
      continue;
    } // end if
    var satellite = tmp_arr[0];
    var sector_abrv = tmp_arr[1];

    if ( satellite_to_find.match('ALL') ) {
        sector_hash[sector] = sector_abrv + ' (' + satellite + ')';
    } else if ( satellite.match(satellite_to_find) ) {
        sector_hash[sector] = sector_abrv;
    }

  } // end for

  // clear the year select
  for(var count = form.satellite_sector.options.length - 1; count >= 0; count--)  {
    form.satellite_sector.options[count] = null;
  }
  var sector_arr = [];
  for (var sector in sector_hash) {
      if ( sector.match('unknown') ) {
	continue;
      }
      sector_arr.push(sector);
  }
  sector_arr.unshift('ALL');
  sector_arr.push('UNKNOWN');
  sector_arr = sector_arr.sort();

  // finally, set the list of options for the selected satellite
  var count = 0;
  for (var i in sector_arr) {
    var sector = sector_arr[i];
    count = count+1;
    var option = document.createElement("option");
    var tmp_arr = sector.split("::");
    var satellite = tmp_arr[0];
    var sector_abrv = tmp_arr[1];
    if ( sector.match('UNKNOWN') || sector.match('ALL') ) {
      option.text = sector;
    } else {
      option.text = sector_hash[sector];
    }
    option.value = sector;
    form.satellite_sector.appendChild(option);
  }

  form.satellite_sector.selectedIndex = 0;

}

function ssetSectorList( form )
{

  // first, get the satellite selected
  var satellite_options = form.satellite.options;
  var selected_index = form.satellite.selectedIndex;
  var value = satellite_options[selected_index].value;
  value = value.toUpperCase();

  // the available options
  var sector_options = form.sector.options;

  // filter out the sectors displayed base on
  // user choice
  for (var i=1; i < sector_options.length; i++) {
    var text = sector_options[i].text;
    var tmp = text.split(" ");
    var abrv = tmp[0];
    var satellite = tmp[1];
    satellite = satellite.replace(/\(|\)/g,"");
    satellite = satellite.replace(/^G/g, 'GOES-');
    if ( value.match(satellite) ) {
      alert('match found: ' + value + ' = ' + satellite);
      break;
    }
  }
  var option = document.createElement("option");
  //option.text = default_value;
  //option.value = default_value;
  //element.appendChild(option);
  for (var i = 1; i < sector.options.length; i++) {
    var text = sector_options[i].txt;
    option = document.createElement("option");
    var tmp = text.split(" ");
    var abrv = tmp[0];
    var satellite = tmp[1];
    option.text = abrv;
    option.value = xx;
    element.appendChild(option);
  }


}
function ssetSectorList( form )
{
	var sat = getSelected( form.satellite );
	if( sat == "G08" )
	{
		setSectorGoes08( form );	
	}
	else if( sat == "G10" )
	{
		setSectorGoes10( form );
	}
	else if( sat == "G11" )
	  {
	    setSectorGoes11(form);
	  }
	else if( sat == "G12" )
	{
		setSectorGoes12( form );
	}
	else if( sat == "G13" )
	{
		setSectorGoes13( form );
	}
	else
	{
		setSectorAll( form )
	}	
}

function getSelected( select )
{
  var list = ""
  var val = "";
  
  for( x = 0; x < select.options.length; x++ )
  {
    list = list + "*" + select.options[x].value
    if( select.options[x].selected )
    {
      val = select.options[x].value
    }
  }

  return val
}

function checkSelection( form )
{
	form.sector.options[form.sector.options.length - 1].selected = false;
}

function resetForm()
{

	//alert('resetting form: ' + document.queryform.elements.length)
	document.queryform.reset()

	//queryform.satellite.options[0].selected = true;
	//document.queryform.satellite.options[0].selected = true;

	//setSectorGoes12( document.queryform );
	//setSectorAll( document.queryform );
}

function setSectorGoes08( form )
{
		form.sector.options[0] = new Option( "ALL", "all", true, true );
		form.sector.options[0].selected = true;
		form.sector.options[1] = new Option( "NOHEM", "1", false, false );
		form.sector.options[1].selected = false;
		form.sector.options[2] = new Option( "NOHEM-EXT", "2", false, false );
		form.sector.options[2].selected = false;
		form.sector.options[3] = new Option( "SOHEM", "3", false, false );
		form.sector.options[3].selected = false;
		form.sector.options[4] = new Option( "SOHEM-LIM", "4", false, false );
		form.sector.options[4].selected = false;
		form.sector.options[5] = new Option( "SOHEM-SS", "5", false, false );
		form.sector.options[5].selected = false;
		form.sector.options[6] = new Option( "CONUS", "6", false, false );
		form.sector.options[6].selected = false;
		form.sector.options[7] = new Option( "SRSO", "7", false, false );
		form.sector.options[7].selected = false;
		form.sector.options[8] = new Option( "FULL", "8", false, false );
		form.sector.options[8].selected = false;
		form.sector.options[9] = new Option( "=================", "null", false, false );
		form.sector.options[9].selected = false;
		form.sector.options.length=10;
		form.sector.size=7
}

function setSectorGoes10( form )
{
		form.sector.options[0] = new Option( "ALL", "all", true, true );
		form.sector.options[0].selected = true;
		form.sector.options[1] = new Option( "NOHEM", "9", false, false );
		form.sector.options[1].selected = false;
		form.sector.options[2] = new Option( "SOHEM", "10", false, false );
		form.sector.options[2].selected = false;
		form.sector.options[3] = new Option( "SOHEM-SS", "11", false, false );
		form.sector.options[3].selected = false;
		form.sector.options[4] = new Option( "PACUS", "12", false, false );
		form.sector.options[4].selected = false;
		form.sector.options[5] = new Option( "SUB-CONUS", "13", false, false );
		form.sector.options[5].selected = false;
		form.sector.options[6] = new Option( "SRSO", "14", false, false );
		form.sector.options[6].selected = false;
		form.sector.options[7] = new Option( "FULL", "15", false, false );
		form.sector.options[7].selected = false;
		form.sector.options[8] = new Option( "=================", "null", false, false );
		form.sector.options[8].selected = false;
		form.sector.options.length=9;
		form.sector.size=7;
}

function setSectorGoes11( form )
{
		form.sector.options[0] = new Option( "ALL", "all", true, true );
		form.sector.options[0].selected = true;
		form.sector.options[1] = new Option( "NOHEM", "24", false, false );
		form.sector.options[1].selected = false;
		form.sector.options[2] = new Option( "SOHEM", "25", false, false );
		form.sector.options[2].selected = false;
		form.sector.options[3] = new Option( "SOHEM-SS", "26", false, false );
		form.sector.options[3].selected = false;
		form.sector.options[4] = new Option( "PACUS", "27", false, false );
		form.sector.options[4].selected = false;
		form.sector.options[5] = new Option( "SUB-CONUS", "28", false, false );
		form.sector.options[5].selected = false;
		form.sector.options[6] = new Option( "SRSO", "29", false, false );
		form.sector.options[6].selected = false;
		form.sector.options[7] = new Option( "FULL", "30", false, false );
		form.sector.options[7].selected = false;
		form.sector.options[8] = new Option( "=================", "null", false, false );
		form.sector.options[8].selected = false;
		form.sector.options.length=9;
		form.sector.size=7;
}

function setSectorGoes12( form )
{
		form.sector.options[0] = new Option( "ALL", "all", true, true );
		form.sector.options[0].selected = true;
		form.sector.options[1] = new Option( "NOHEM", "16", false, false );
		form.sector.options[1].selected = false;
		form.sector.options[2] = new Option( "NOHEM-EXT", "17", false, false );
		form.sector.options[2].selected = false;
		form.sector.options[3] = new Option( "SOHEM", "18", false, false );
		form.sector.options[3].selected = false;
		form.sector.options[4] = new Option( "SOHEM-LIM", "19", false, false );
		form.sector.options[4].selected = false;
		form.sector.options[5] = new Option( "SOHEM-SS", "20", false, false );
		form.sector.options[5].selected = false;
		form.sector.options[6] = new Option( "CONUS", "21", false, false );
		form.sector.options[6].selected = false;
		form.sector.options[7] = new Option( "SRSO", "22", false, false );
		form.sector.options[7].selected = false;
		form.sector.options[8] = new Option( "FULL", "23", false, false );
		form.sector.options[8].selected = false;
		form.sector.options[9] = new Option( "=================", "null", false, false );
		form.sector.options[9].selected = false;
		form.sector.options.length=10;
		form.sector.size=7
}

function setSectorGoes13( form )
{
		form.sector.options[0] = new Option( "ALL", "all", true, true );
		form.sector.options[0].selected = true;
		form.sector.options[1] = new Option( "NOHEM", "31", false, false );
		form.sector.options[1].selected = false;
		form.sector.options[2] = new Option( "NOHEM-EXT", "32", false, false );
		form.sector.options[2].selected = false;
		form.sector.options[3] = new Option( "SOHEM", "33", false, false );
		form.sector.options[3].selected = false;
		form.sector.options[4] = new Option( "SOHEM-LIM", "34", false, false );
		form.sector.options[4].selected = false;
		form.sector.options[5] = new Option( "SOHEM-SS", "35", false, false );
		form.sector.options[5].selected = false;
		form.sector.options[6] = new Option( "CONUS", "36", false, false );
		form.sector.options[6].selected = false;
		form.sector.options[7] = new Option( "SRSO", "37", false, false );
		form.sector.options[7].selected = false;
		form.sector.options[8] = new Option( "FULL", "38", false, false );
		form.sector.options[8].selected = false;
		form.sector.options[9] = new Option( "=================", "null", false, false );
		form.sector.options[9].selected = false;
		form.sector.options.length=10;
		form.sector.size=7
}

function setSectorAll( form )
{
		form.sector.options[0] = new Option( "ALL", "all", true, true );
		form.sector.options[0].selected = true;
		form.sector.options[1] = new Option( "NOHEM (G08)", "1", false, false );
		form.sector.options[1].selected = false;
		form.sector.options[2] = new Option( "NOHEM-EXT (G08)", "2", false, false );
		form.sector.options[2].selected = false;
		form.sector.options[3] = new Option( "SOHEM (G08)", "3", false, false );
		form.sector.options[3].selected = false;
		form.sector.options[4] = new Option( "SOHEM-LIM (G08)", "4", false, false );
		form.sector.options[4].selected = false;
		form.sector.options[5] = new Option( "SOHEM-SS (G08)", "5", false, false );
		form.sector.options[5].selected = false;
		form.sector.options[6] = new Option( "CONUS (G08)", "6", false, false );
		form.sector.options[6].selected = false;
		form.sector.options[7] = new Option( "SRSO (G08)", "7", false, false );
		form.sector.options[7].selected = false;
		form.sector.options[8] = new Option( "FULL (G08)", "8", false, false );
		form.sector.options[8].selected = false;
		form.sector.options[9] = new Option( "NOHEM (G10)", "9", false, false );
		form.sector.options[9].selected = false;
		form.sector.options[10] = new Option( "SOHEM (G10)", "10", false, false );
		form.sector.options[10].selected = false;
		form.sector.options[11] = new Option( "SOHEM-SS (G10)", "11", false, false );
		form.sector.options[11].selected = false;
		form.sector.options[12] = new Option( "PACUS (G10)", "12", false, false );
		form.sector.options[12].selected = false;
		form.sector.options[13] = new Option( "SUB-CONUS (G10)", "13", false, false );
		form.sector.options[13].selected = false;
		form.sector.options[14] = new Option( "SRSO (G10)", "14", false, false );
		form.sector.options[14].selected = false;
		form.sector.options[15] = new Option( "FULL (G10)", "15", false, false );
		form.sector.options[15].selected = false;
		form.sector.options[16] = new Option( "NOHEM (G12)", "16", false, false );
		form.sector.options[16].selected = false;
		form.sector.options[17] = new Option( "NOHEM-EXT (G12)", "17", false, false );
		form.sector.options[17].selected = false;
		form.sector.options[18] = new Option( "SOHEM (G12)", "18", false, false );
		form.sector.options[18].selected = false;
		form.sector.options[19] = new Option( "SOHEM-LIM (G12)", "19", false, false );
		form.sector.options[19].selected = false;
		form.sector.options[20] = new Option( "SOHEM-SS (G12)", "20", false, false );
		form.sector.options[20].selected = false;
		form.sector.options[21] = new Option( "CONUS (G12)", "21", false, false );
		form.sector.options[21].selected = false;
		form.sector.options[22] = new Option( "SRSO (G12)", "22", false, false );
		form.sector.options[22].selected = false;
		form.sector.options[23] = new Option( "FULL (G12)", "23", false, false );
		form.sector.options[23].selected = false;
		form.sector.options[24] = new Option( "NOHEM (G13)", "24", false, false );
		form.sector.options[24].selected = false;
		form.sector.options[25] = new Option( "NOHEM-EXT (G13)", "25", false, false );
		form.sector.options[25].selected = false;
		form.sector.options[26] = new Option( "SOHEM (G13)", "26", false, false );
		form.sector.options[26].selected = false;
		form.sector.options[27] = new Option( "SOHEM-LIM (G13)", "27", false, false );
		form.sector.options[27].selected = false;
		form.sector.options[28] = new Option( "SOHEM-SS (G13)", "28", false, false );
		form.sector.options[28].selected = false;
		form.sector.options[29] = new Option( "CONUS (G13)", "29", false, false );
		form.sector.options[29].selected = false;
		form.sector.options[30] = new Option( "SRSO (G13)", "30", false, false );
		form.sector.options[30].selected = false;
		form.sector.options[31] = new Option( "FULL (G13)", "31", false, false );
		form.sector.options[31].selected = false;
		form.sector.options[32] = new Option( "=================", "null", false, false );
		form.sector.options[32].selected = false;
		form.sector.size=7
}
