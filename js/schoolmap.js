var googleDiv;
var google_html;
var map;
var markersLayer;
var default_centre = new GLatLng( 53.82659674299412, -1.86767578125 );
var default_zoom = 6;
var address_zoom = 12;
var max_zoom = 15;
var place;
var schools_url = "schools";
var acronyms_url = "acronyms.json";
var school_url = "school";

var schools = new Array();
var active_school;
var nschools = 0;
var params = new Object();
var keystages = new Array();

var request = false;

var symbols = new Object();
var curtags = [ "body", "a", "input", "select", "div" ];
var listDiv;
var types = {
    primary:{ colour: "0000ff", active_colour:"aaaaff" },
    secondary:{ colour: "ff0000", active_colour:"ffaaaa" },
    independent:{ colour: "00ff00", active_colour:"aaffaa" },
    special:{ colour: "00ffff", active_colour:"aaffff" }
};
var blue = "4444ff";
var red = "ff4444";
var gdir;
var handle_load = false;
var handle_error = false;
var handle_zoom = false;
var handle_move = false;

var layer_config = {
    panoramio: "com.panoramio.all",
    "panoramio (popular)": "com.panoramio.popular",
    wikipedia: "org.wikipedia.en"
};

var layers = new Object();
var addressMarker = false;

function setMapListeners()
{
    handle_zoom = GEvent.addListener( map, "zoomend", getSchools );
    handle_move = GEvent.addListener( map, "moveend", getSchools );
}

function removeMapListeners()
{
    if ( handle_zoom )
    {
        console.log( "remove zoom listener" );
        GEvent.removeListener( handle_zoom );
        handle_zoom = false;
    }
    if ( handle_move )
    {
        console.log( "remove move listener" );
        GEvent.removeListener( handle_move );
        handle_move = false;
    }
}

function clearAddress()
{
    document.forms[0].address.value = "";
    place = false;
    console.log( "remove " + addressMarker );
    if ( addressMarker ) map.removeOverlay( addressMarker );
    addressMarker = false;
    getSchools();
}

function place2point( a )
{
    return new GLatLng( a.Point.coordinates[1], a.Point.coordinates[0] );
}

function createAddressMarker()
{
    if ( ! place ) return;
    addressMarker = new GMarker( place.point );
    map.addOverlay( addressMarker );
}

function getAddress()
{
    var address = document.forms[0].address.value;
    if ( ! address.length )
    {
        address = false;
        return;
    }
    document.forms[0].gotobutton.disabled = true;
    var geocoder = new GClientGeocoder();
    geocoder.setBaseCountryCode( "uk" );
    geocoder.getLocations( 
        address, 
        function ( response ) {
            document.forms[0].gotobutton.disabled = false;
            if ( ! response || response.Status.code != 200 ) 
            {
                alert("\"" + address + "\" not found");
                return;
            }
            place = response.Placemark[0];
            var point = place.point = place2point( place );
            createAddressMarker();
            map.setCenter( point );
            map.setZoom( address_zoom );
            getSchools();
        }
    );
}

function createLinkTo( query_string )
{
    var url = document.URL;
    url = url.replace( /\?.*$/, "" );
    // var url = url + "?" + query_string;
    // var link1 = document.createElement( "A" );
    // link1.href = url;
    // setText( link1, "HTML" );
    var link2 = document.createElement( "A" );
    url = schools_url + ".xml?" + query_string + "&format=xml";
    link2.href = url;
    setText( link2, "XML" );
    var link3 = document.createElement( "A" );
    url = schools_url + ".rss?" + query_string + "&format=georss";
    link3.href = url;
    setText( link3, "GeoRSS" );
    var link4 = document.createElement( "A" );
    url = schools_url + ".kml?" + query_string + "&format=kml";
    link4.href = url;
    setText( link4, "KML" );
    var link5 = document.createElement( "A" );
    url = schools_url + "?" + query_string + "&format=json";
    link5.href = url;
    setText( link5, "JSON" );
    linkToDiv = document.getElementById( "linkto" );
    removeChildren( linkToDiv );
    var txt = document.createTextNode( "link to this page:" );
    linkToDiv.appendChild( txt );
    // linkToDiv.appendChild( link1 );
    // linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link2 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link3 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link4 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link5 );
}

function removeChildren( parent )
{
    try {
        while ( parent.childNodes.length ) parent.removeChild( parent.childNodes[0] );
    }
    catch(e) { console.log( e.message ) }
}

function childReplace( parent, node )
{
    var firstBorn = parent.childNodes[0];
    if ( firstBorn ) parent.replaceChild( node, firstBorn );
    else parent.appendChild( node );
}

function setStatus( text )
{
    window.status = text;
}

function getOptions( sel )
{
    var options = new Array();
    var opts = sel.options;
    for ( var i = 0; i < opts.length; i++ )
    {
        var opt = opts[i];
        if ( opt.selected ) options.push( opt.value );
    }
    return options;
}

function setZoomLevel()
{
    var bounds = new GLatLngBounds();
    for ( var i = 0; i < schools.length; i++ )
    {
        var school = schools[i];
        console.log( school + " (" + school.lat + "," + school.lon + ")" );
        var point = new GLatLng( school.lat, school.lon );
        bounds.extend( point );
    }
    var centre = bounds.getCenter();
    var zoom = map.getBoundsZoomLevel( bounds );
    removeMapListeners();
    // console.log( "set centre to " + centre );
    // map.setCenter( centre );
    // console.log( "set zoom to " + zoom );
    // map.setZoom( zoom );
    setMapListeners();
}

function getSchoolsCallback( xmlDoc )
{
    try {
        var doc = xmlDoc.documentElement;
        var docObj = xml2obj( doc );
        nschools = docObj.nschools;
        var schoolXmlArray = doc.getElementsByTagName( "school" );
        for ( var i = 0; i < schoolXmlArray.length; i++ )
        {
            var school = xml2obj( schoolXmlArray[i] );
            schools.push( school );
        }
        updateSchools();
    } catch( e ) { console.log( e.message ) }
}

function updateSchools()
{
    try {
        var body = document.getElementsByTagName( "body" );
        body[0].style.cursor = "auto";
        removeChildren( listDiv );
        googleDiv.innerHTML = google_html;
        for ( var i = 0; i < schools.length; i++ )
        {
            var school = schools[i];
            var type = types[school.ofsted_type];
            if ( ! type )
            {
                console.error( "no type for " + school.name );
            }
            var colour = type ? type.colour : blue;
            createSchoolMarker( school, colour );
        }
        if ( schools.length )
        {
            listDiv.appendChild( createListTable() );
        }
        else
        {
            setStatus( "there are no schools on this map - zoom out" ); 
        }
        if ( place ) createAddressMarker();
        var b = document.createElement( "B" );
        b.appendChild( document.createTextNode( schools.length + " / " + nschools + " schools" ) );
        listDiv.appendChild( b );
    } catch( e ) { console.log( e.message ) }
}

function getXML( url, callback )
{
    setCursor( "wait" );
    if ( request )
    {
        console.log( "abort " + request );
        request.abort();
    }
    request = new XMLHttpRequest();
    // why is ie so crap?
    url = url + "&.xml";
    request.open( 'GET', url, true );
    request.onreadystatechange = function() {
        if ( request.readyState != 4 ) return;
        if ( request.status == 0 ) return; // aborted request
        setCursor( "default" );
        if ( request.status == 200 )
        {
            var xmlDoc = request.responseXML;
            callback( xmlDoc );
        }
        else
        {
            console.error( "GET " + url + " failed: " + request.status );
        }
        request = false;
    };
    request.send( null );
}

function getJSON( url, callback )
{
    setCursor( "wait" );
    if ( request )
    {
        console.log( "abort " + request );
        request.abort();
    }
    request = new XMLHttpRequest();
    request.open( 'GET', url, true );
    request.onreadystatechange = function() {
        if ( request.readyState != 4 ) return;
        if ( request.status == 0 ) return; // aborted request
        setCursor( "default" );
        if ( request.status == 200 ) callback( request );
        else console.error( "GET " + url + " failed: " + request.status );
    };
    request.send( null );
}

function get( url, callback )
{
    var request = new XMLHttpRequest();
    request.open( 'GET', url, true );
    request.onreadystatechange = function() {
        if ( request.readyState != 4 ) return;
        if ( request.status == 0 ) return; // aborted request
        setCursor( "default" );
        if ( request.status == 200 ) callback( request );
        else console.error( "GET " + url + " failed: " + request.status );
    };
    request.send( null );
}

function createXMLHttpRequest()
{
    if ( typeof XMLHttpRequest != "undefined" )
    {
        return new XMLHttpRequest();
    } else if ( typeof ActiveXObject != "undefined" )
    {
        return new ActiveXObject( "Microsoft.XMLHTTP" );
    } else {
        throw new Error( "XMLHttpRequest not supported" );
    }
}

function setCursor( state )
{
    for ( var i = 0; i < curtags.length; i++ )
    {
        var tag = curtags[i];
        var es = document.getElementsByTagName( tag );
        for ( var j = 0; j < es.length; j++ )
        {
            es[j].style.cursor = state;
        }
    }
}

function getSchools()
{
    setOrderBy();
    var order_by = document.forms[0].order_by.value;
    var ofsted_type = document.forms[0].ofsted_type.value;
    var special = document.forms[0].special.value;
    var status = "finding the top " + document.forms[0].limit.value + " ";
    status = status + "schools ";
    status = status + "(ordered by " + order_by + ")";
    setStatus( status );
    var bounds = map.getBounds();
    var center = map.getCenter();
    var zoom = map.getZoom();
    var sw = bounds.getSouthWest();
    var ne = bounds.getNorthEast();
    var query_string = 
        "&order_by=" + escape( order_by ) +
        "&ofsted_type=" + escape( ofsted_type ) +
        "&special=" + escape( special ) +
        "&limit=" + escape( document.forms[0].limit.value ) +
        "&minLon=" + escape( sw.lng() ) + 
        "&maxLon=" + escape( ne.lng() ) + 
        "&minLat=" + escape( sw.lat() ) + 
        "&maxLat=" + escape( ne.lat() )
    ;
    for ( var i = 0; i < schools.length; i++ )
    {
        var school = schools[i];
        if ( school.marker ) map.removeOverlay( school.marker );
        school.marker = null;
    }
    schools = new Array();
    active_school = false;
    var url = schools_url + "?" + query_string;
    createLinkTo( query_string );
    getJSON( url, getJSONCallback );
}

function getJSONCallback( response ) {
    var json = JSON.parse( response.responseText );
    nschools = json.nschools;
    schools = json.schools;
    updateSchools();
}

function xml2obj( xml )
{
    var obj = new Object();
    for ( var j = 0; j < xml.attributes.length; j++ )
    {
        var attr = xml.attributes.item( j );
        if ( attr.value ) obj[attr.name] = attr.value;
    }
    return obj;
}

function createIcon( letter, colour )
{
    var icon = MapIconMaker.createLabeledMarkerIcon(
        { primaryColor: "#" + colour, label: letter }
    );
    icon.colour = colour;
    return icon;
}

function createMarker( letter, colour, point )
{
    var icon = createIcon( letter, colour );
    var marker = new GMarker( point, { "icon":icon } );
    map.addOverlay( marker );
    return marker;
}

function deActivateSchool( school )
{
    changeLinksColour( school, blue );
    var type = types[school.ofsted_type];
    if ( ! type )
    {
        console.error( "no type for " + school.name );
        return;
    }
    changeMarkerColour( school, type.colour );
}

function activateSchool( school )
{
    changeLinksColour( school, red );
    var type = types[school.ofsted_type];
    if ( ! type )
    {
        console.error( "no type for " + school.name );
        return;
    }
    changeMarkerColour( school, type.active_colour )
    if ( active_school ) deActivateSchool( active_school );
    active_school = school;
}

function calculateAllDistances()
{
    for ( var i = 0; i < schools.length; i++ )
    {
        if ( !  schools[i].meters ) calculateDistance( schools[i] );
    }
}

function setText( e, t )
{
    empty( e );
    e.appendChild( document.createTextNode( t ) );
}

function removeDistanceListeners()
{
    if ( handle_error )
    {
        console.log( "remove error listener" );
        GEvent.removeListener( handle_error );
        handle_error = false;
    }
    if ( handle_load )
    {
        console.log( "remove load listener" );
        GEvent.removeListener( handle_load );
        handle_load = false;
    }
}

function convertMeters( m )
{
    if ( m < 1000 ) return m + " m";
    var km = m / 1000;
    return km + " km";
}
function calculateDistance( school )
{
    if ( ! place ) return;
    console.log( "calclulate distance for " + school.name )
    setText( school.distance_link, "calclulating ..." )
    var from = school.lat + "," + school.lon;
    var to = place.address;
    school.directions_text = "from " + from + " to " + to;
    console.log( "get directions:" + school.directions_text );
    gdir.clear();
    try {
        removeDistanceListeners();
        handle_load = GEvent.addListener( gdir, "load", function( obj ) { 
            console.log( school.name + " route loaded" );
            setText( school.distance_link, "done ..." )
            try {
                var nroutes = obj.getNumRoutes();
                if ( nroutes >= 0 )
                {
                    var route = obj.getRoute( 0 );
                    var distance = route.getDistance();
                    if ( typeof( distance.meters ) == "number" )
                    {
                        school.meters = distance.meters;
                        setText( school.distance_link, convertMeters( school.meters ) );
                    }
                }
            } catch( e ) {
                console.error( school.name + " route calculation failed: " + e.message );
            }
            removeDistanceListeners();
        } );
        handle_error = GEvent.addListener( gdir, "error", function( obj ) { 
            console.log( "error: " + obj.getStatus().code );
            setText( school.distance_link, "error" )
            removeDistanceListeners();
        } );
        gdir.load( 
            school.directions_text,
            { preserveViewport:true, travelMode:"walking" }
        );
    } catch( e ) {
        console.error( e.message );
        return;
    }
}

function createSchoolMarker( school, colour ) 
{
    try {
        school.letter = getLetter( school );
        var point = new GLatLng( school.lat, school.lon );
        var marker = createMarker( school.letter, colour, point );
        GEvent.addListener( marker, "mouseout", function() { deActivateSchool( school ) } );
        GEvent.addListener( marker, "mouseover", function() { activateSchool( school ) } );
        GEvent.addListener( 
            marker, 
            "click", 
            function() {
                var html = "<h2>" + school.name + "</h2>";
                html = html + "<p>" + school.address + "," + school.postcode + "</p>";
                marker.openInfoWindowHtml( html, { suppressMapPan:true } );
            } 
        );
        // marker.school = school;
        school.marker = marker;
        school.point = point;
    }
    catch(e) { console.log( e.message ) }
}

var keystages = new Array(
    { "name":"primary", "description":"Key stage 2" },
    { "name":"ks3", "description":"Key stage 3" },
    { "name":"secondary", "description":"GCSE" },
    { "name":"post16", "description":"GCE and VCE" }
);

function setOrderBy()
{
    try {
        var curr = document.forms[0].order_by.value || params.order_by;
        removeChildren( document.forms[0].order_by );
        var opt = addOpt( 
            document.forms[0].order_by, 
            "-",
            ""
        );
        for ( var i = 0; i < keystages.length; i++ )
        {
            var keystage = keystages[i];
            var opt = addOpt( 
                document.forms[0].order_by, 
                keystage.description + " results", 
                keystage.name 
            );
        }
        if ( curr ) document.forms[0].order_by.value = curr;
    }
    catch(e) { console.log( e.message ) }
}

function initTableHead( tr )
{
    var ths = new Array();
    createHeadCell( tr, "no" );
    createHeadCell( tr, "name", "Name of school" );
    createHeadCell( tr, "type", "Type of school" );
    createHeadCell( tr, "age range", "Range of ages in the school" );
    createHeadCell( tr, "special", "Specialist Schools (as designated under the specialist school programme)" );
    createHeadCell( tr, "ofsted report", "Link to Ofsted report" );
    for ( var i = 0; i < keystages.length; i++ ) 
        createHeadCell( tr, keystages[i].description, "average score" );
    ;
    if ( place )
    {
        createHeadCell( tr, "distance", "Distance from " + place.address );
    }
}

function getQueryVariables() 
{
    var query = window.location.search.substring( 1 );
    var vars = query.split( "&" );
    for ( var i = 0; i < vars.length; i++ ) 
    {
        var pair = vars[i].split( "=" );
        var key = unescape( pair[0] );
        var val = unescape( pair[1] );
        params[key] = val;
    } 
}

function ignoreConsoleErrors()
{
    if ( ! window.console )
    {
        window.console = {
            log:function() {},
            error:function() {}
        };
    }
}

function toggleLayer( i )
{
    console.log( "togglePanoramio:" + i.checked );
    if ( i.checked ) layers[i.name].show();
    else layers[i.name].hide();
}

function initMap()
{
    ignoreConsoleErrors();
    console.log( "init map" );
    getQueryVariables();
    googleDiv = document.getElementById( "google" );
    listDiv = document.getElementById( "list" );
    google_html = googleDiv.innerHTML;
    if ( ! GBrowserIsCompatible() )
    {
        console.log( "google maps not supported" );
        return;
    }
    var map_div = document.getElementById( "map" );
    map = new GMap2( map_div );
    map.addControl( new GSmallMapControl() );
    map.addControl( new GMapTypeControl() );
    map.addMapType( G_SATELLITE_3D_MAP );
    map.addMapType( G_PHYSICAL_MAP );
    var mapTd = document.getElementById( "mapTd" );
    var fieldset = document.createElement( "FIELDSET" );
    var legend = document.createElement( "LEGEND" );
    legend.appendChild( document.createTextNode( "Layers" ) );
    fieldset.appendChild( legend );
    for ( var type in layer_config )
    {
        console.log( "set up " + type );
        layers[type] = new GLayer( layer_config[type] );
        map.addOverlay( layers[type] );
        var input = document.createElement( "INPUT" );
        input.type = "checkbox";
        input.name = input.id = type;
        input.onchange = function() { toggleLayer( this ) };
        if ( input.checked ) layers[type].show();
        else layers[type].hide();
        fieldset.appendChild( input );
        var label = document.createElement( "LABEL" );
        label.htmlFor = type;
        label.appendChild( document.createTextNode( type ) );
        fieldset.appendChild( label );
    }
    console.log( fieldset );
    mapTd.appendChild( fieldset );

    map.setCenter( default_centre, default_zoom );
    if ( 
        params.minLon &&
        params.minLat &&
        params.maxLon &&
        params.maxLat
    )
    {
        var sw = GPoint( params.minLon, params.minLat );
        var ne = GPoint( params.maxLon, params.maxLat );
        var bounds = GLatLngBounds( sw, ne );
        map.setZoom( GMap2.getBoundsZoomLevel( bounds ) );
    }
    if ( params.centreLon && params.centreLat )
    {
        var centre = new GLatLng( params.centreLat, params.centreLon );
        map.setCenter( centre );
    }
    setMapListeners();
    if ( params.address ) document.forms[0].address.value = params.address;
    if ( params.limit ) document.forms[0].limit.value = params.limit;
    setOrderBy();
    getSchools();
    gdir = new GDirections( map );
    get( acronyms_url, acronymsCallback );
}

function acronymsCallback( response ) {
    var specialisms = JSON.parse( response.responseText );
    var sel = document.forms[0].special;
    for ( var s in specialisms )
    {
        addOpt( sel, specialisms[s], s );
    }
}

function createListTd( opts )
{
    var td = document.createElement( "TD" );
    if ( opts.url )
    {
        var a = document.createElement( "A" );
        a.target = "_blank";
        a.onclick = function() { window.open( opts.url, "school", "status,scrollbars,resizable" ); return false; };
        a.href = opts.url;
        var school = opts.school;
        if ( ! school.links ) school.links = new Array();
        school.links.push( a );
        var text = "-";
        if ( opts.text && opts.text != "null" ) text = opts.text;
        a.appendChild( document.createTextNode( text ) );
        td.appendChild( a );
        a.onmouseover = function() {
            activateSchool( school );
        };
        a.onmouseout = function() {
            deActivateSchool( school );
        };
    }
    else
    {
        td.appendChild( document.createTextNode( opts.text ) );
    }
    td.style.verticalAlign = "top";
    return td;
}

function createDistanceTd( opts )
{
    var td = document.createElement( "TD" );
    var a = document.createElement( "A" );
    a.onclick = function() { opts.onclick( opts.school ); };
    a.onmouseover = function() {
        activateSchool( opts.school );
    };
    a.onmouseout = function() {
        deActivateSchool( opts.school );
    };
    a.appendChild( document.createTextNode( opts.text ) );
    if ( ! opts.school.links ) opts.school.links = new Array();
    opts.school.links.push( a );
    opts.school.distance_link = a;
    td.appendChild( a );
    return td;
}

function myround( num, precision )
{
    return Math.round( parseFloat( num ) * Math.pow( 10, precision ) );
}

function remove( elem )
{
    if ( elem && elem.parentNode ) elem.parentNode.removeChild( elem );
}

function empty( elem )
{
    while ( elem.firstChild ) remove( elem.firstChild );
}

function createListRow( no, school )
{
    var tr = document.createElement( "TR" );
    var url = school_url + "?table=dfes&id=" + school.dfes_id;
    tr.appendChild( createListTd( { "text":no+1, "url":url, "school":school } ) );
    tr.appendChild( createListTd( { "text":school.name, "url":url, "school":school } ) );
    tr.appendChild( createListTd( { "text":school.ofsted_type, "url":url, "school":school } ) );
    tr.appendChild( createListTd( { "text":school.age_range, "url":url, "school":school } ) );
    tr.appendChild( createListTd( { "text":school.special, "url":url, "school":school } ) );
    if ( school.ofsted_url ) 
    {
        var url = school_url + "?table=ofsted&id=" + school.ofsted_id;
        tr.appendChild( createListTd( { "text":"yes", "url":url, "school":school } ) );
    }
    else
    {
        tr.appendChild( createListTd( { text:"no" } ) );
    }
    for ( var i = 0; i < keystages.length; i++ )
    {
        var keystage = keystages[i];
        var ave = "average_" + keystage.name;
        if ( school[ave] && school[ave] != 0 )
        {
            var val = school[ave];
            var url = school_url + "?table=dfes&type=" + keystage.name + "&id=" + school.dfes_id;
            var td = createListTd( { "text":val, "url":url, "school":school } );
        }
        else
        {
            var td = createListTd( { "text":"-" } );
        }
        td.noWrap = true;
        tr.appendChild( td );
    }
    if ( place )
    {
        var td = createDistanceTd( { text:"[ calculate ]", school:school, onclick:calculateDistance } );
        td.style.whiteSpace = "nowrap";
        tr.appendChild( td );
    }
    return tr;
}

symbols = {
    "up":"\u2191",
    "down":"\u2193"
};
function getSymbol( label )
{
    var span = document.createElement( "SPAN" );
    setText( span, symbols[label] );
    span.fontWeight = "bold";
    span.fontSize = "200%";
    return span;
}

function createHeadCell( tr, name, title )
{
    var th = document.createElement( "TH" );
    th.style.verticalAlign = "top";
    tr.appendChild( th );
    var a = document.createElement( "A" );
    th.appendChild( a );
    th.appendChild( document.createElement( "BR" ) );
    a.name = name;
    a.title = title || name;
    a.style.color = "black";
    a.style.textDecoration = "none";
    a.href = "";
    a.onclick = function() { return false; };
    setText( a, name );
}

function createListTable()
{
    var table = document.createElement( "TABLE" );
    var tbody = document.createElement( "TBODY" );
    table.appendChild( tbody );
    var tr = document.createElement( "TR" );
    tbody.appendChild( tr );
    initTableHead( tr );
    tbody.appendChild( tr );
    for ( var i = 0; i < schools.length; i++ )
    {
        var school = schools[i];
        var tr = createListRow( i, school );
        tbody.appendChild( tr );
    }
    var ncells = tr.childNodes.length;
    if ( place )
    {
        var tr = document.createElement( "TR" );
        tbody.appendChild( tr );
        for ( var i = 0; i < ncells-1; i++ )
        {
            var td = document.createElement( "TD" );
            tr.appendChild( td );
        }
    }
    return table;
}

function getIconUrl( letter, colour )
{
    return icon_root_url + 'marker-' + colour.toUpperCase() + "-" + letter + '.png';
}

function changeMarkerColour( school, colour )
{
    var marker = school.marker;
    if ( ! marker ) return;
    var icon = marker.getIcon();
    var image = icon.image;
    var new_image = image.replace( icon.colour, colour );
    icon.colour = colour;
    marker.setImage( new_image );
}

function changeLinksColour( school, color )
{
    var links = school.links;
    if ( ! links ) 
    {
        console.error( "no links for " + school.name );
        return;
    }
    for ( var i = 0; i < links.length; i++ )
    {
        link = links[i];
        link.style.color = "#" + color;
    }
}

function addOpt( sel, str, val, isSel )
{
    var opt = new Option( str, val );
    opt.selected = isSel;
    sel.options[sel.options.length] = opt;
    return opt;
}

function getLetter( school )
{
    // var name = school.name;
    // name = name.replace( /The /i, "" );
    var letter = school.ofsted_type.substr( 0, 1 ).toUpperCase();
    return letter;
}

function showInfo() 
{ 
    var pt = new GLatLng( this.lat, this.lon );
    var address = this.address.split( "," ).join( ",<br/>" );
    map.openInfoWindowHtml( pt, "<b>" + this.name + "</b>" + "<br/>" + address );
}
