var logreader;
var googleDiv;
var google_html;
var map;
var markersLayer;
var default_centre;
var default_zoom = 6;
var max_zoom = 15;
var postcodePt;
var postcode_url = "cgi/postcode.cgi";
var postcodes_url = "cgi/postcodes.cgi";
var cgi_url = "cgi/schools.cgi";
var modperl_url = "schools.xml";
var schools_url = modperl_url;
// var schools_url = cgi_url;
var school_url = "school";
var nearby_url = "http://www.nearby.org.uk/coord.cgi?p=";
var ononemap_url = "http://ononemap.com/map/?q=";
var gmapLayer;
var veLayer;
var olLayer;
var osLayer;

var icon_root_url = 'http://bluweb.com/us/chouser/gmapez/iconEZ2/';
var schools;
var noRedraw = false;
var params = new Object();
var keystages = new Array();

var transaction;
var current_url;

var symbols = new Object();
var curtags = [ "body", "a", "input", "select", "div" ];
var listDiv;

function clearPostcode()
{
    document.forms[0].postcode.value = "";
    postcodePt = false;
    childReplace( nearbyDiv, document.createTextNode( '' ) );
    getSchools();
}

function getPostcode()
{
    var postcode = document.forms[0].postcode.value;
    if ( ! postcode.length )
    {
        postcodePt = false;
        childReplace( nearbyDiv, document.createTextNode( '' ) );
        return;
    }
    var ononemapDiv = document.getElementById( "ononemap" );
    var a = document.createElement( "A" );
    a.href = ononemap_url + escape( postcode );
    a.target = "ononemap";
    a.appendChild( document.createTextNode( "search property near " + postcode + " from ononemap.com" ) );
    childReplace( ononemapDiv, a );
    var nearbyDiv = document.getElementById( "nearby" );
    a = document.createElement( "A" );
    a.href = nearby_url + escape( postcode );
    a.target = "nearby";
    a.appendChild( document.createTextNode( "other stuff nearby " + postcode + " from nearby.org.uk" ) );
    childReplace( nearbyDiv, a );
    document.forms[0].gotobutton.disabled = true;
    setStatus( "finding " + postcode ); 
    var url = postcode_url + "?postcode=" + escape( postcode );
    get( url, getPostcodeCallback );
}

function createLinkTo( query_string )
{
    var txt = document.createTextNode( "link to this page:" );
    var url = document.URL;
    url = url.replace( /\?.*$/, "" );
    var url = url + "?" + query_string;
    var link1 = document.createElement( "A" );
    link1.href = url;
    link1.appendChild( document.createTextNode( "HTML" ) );
    var link2 = document.createElement( "A" );
    url = schools_url + "?" + query_string;
    link2.href = url;
    link2.appendChild( document.createTextNode( "XML" ) );
    var link3 = document.createElement( "A" );
    url = schools_url + "?" + query_string + "&format=georss";
    link3.href = url;
    link3.appendChild( document.createTextNode( "GeoRSS" ) );
    linkToDiv = document.getElementById( "linkto" );
    removeChildren( linkToDiv );
    linkToDiv.appendChild( txt );
    linkToDiv.appendChild( link1 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link2 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link3 );
}

function getPostcodeCallback( response )
{
    document.forms[0].gotobutton.disabled = false;
    var xmlDoc = response.responseXML;
    var coords = xmlDoc.documentElement.getElementsByTagName( "coords" );
    var postcode = document.forms[0].postcode.value;
    if ( ! coords || ! coords[0] || ! coords[0].getAttribute( "lon" ) )
    {
        alert( "can't find postcode " + postcode );
        return;
    }
    var x = coords[0].getAttribute( "x" );
    document.forms[1].x.value = x;
    var y = coords[0].getAttribute( "y" );
    document.forms[1].y.value = y;
    var lon = coords[0].getAttribute( "lon" );
    document.forms[1].lon.value = lon;
    var lat = coords[0].getAttribute( "lat" );
    document.forms[1].lat.value = lat;
    var code = coords[0].getAttribute( "code" );
    document.forms[0].postcode.value = code;
    postcodePt = new OpenLayers.LonLat( lon, lat );
    createMarker( "X", "red", postcodePt );
    map.setCenter( postcodePt );
    var postcode = document.forms[0].postcode.value;
    var opt = addOpt( document.forms[0].order_by, "Distance from " + postcode, "distance" );
    document.forms[0].order_by.value = "distance";
    getSchools();
}

function removeChildren( parent )
{
    try {
        while ( parent.childNodes.length ) parent.removeChild( parent.childNodes[0] );
    }
    catch(e) { console.log( e ) }
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

function markersOffScreen()
{
    for ( var i = 0; i < markersLayer.markers.length; i++ )
    {
        var marker = markersLayer.markers[i];
        if ( ! marker.onScreen() )
        {
            return true;
        }
    }
    return false;
}

function getSchoolsCallback( response )
{
    try {
        var body = document.getElementsByTagName( "body" );
        body[0].style.cursor = "auto";
        markersLayer.clearMarkers();
        removeChildren( listDiv );
        googleDiv.innerHTML = google_html;
        var xmlDoc = response.responseXML;
        var schoolsXml = xmlDoc.documentElement.getElementsByTagName( "school" );
        for ( var i = 0; i < schoolsXml.length; i++ )
        {
            var school = xml2obj( schoolsXml[i] );
            schools.push( school );
            createSchoolMarker( school, "blue" );
        }
        if ( schoolsXml.length )
        {
            listDiv.appendChild( createListTable() );
        }
        else
        {
            setStatus( "there are no schools in on this map" ); 
        }
        if ( postcodePt )
        {
            noRedraw = true;
            map.setCenter( postcodePt );
            map.zoomTo( max_zoom );
            createMarker( "X", "red", postcodePt );
            while ( markersOffScreen() ) map.zoomOut();
            noRedraw = false;
        }
    } catch( e ) { alert( e ) }
    getNSchools();
}

function getNSchools()
{
    if ( noRedraw ) return;
    setOrderBy();
    var order_by = document.forms[0].order_by.value;
    var bounds = map.getExtent();
    var query_string = 
        "count=1" +
        "&minLon=" + escape( bounds.left ) + 
        "&maxLon=" + escape( bounds.right ) + 
        "&minLat=" + escape( bounds.bottom ) + 
        "&maxLat=" + escape( bounds.top )
    ;
    var url = schools_url + "?" + query_string;
    get( url, getNSchoolsCallback );
}

function getNSchoolsCallback( response )
{
    var xmlDoc = response.responseXML;
    var schoolsXml = xmlDoc.documentElement.getElementsByTagName( "schools" );
    if ( schoolsXml[0] )
    {
        var obj = xml2obj( schoolsXml[0] );
        var b = document.createElement( "B" );
        b.appendChild( document.createTextNode( schools.length + " / " + obj.count + " schools" ) );
        listDiv.appendChild( b );
    }
}

function get( url, callback )
{
    var callbacks = {
        success:function(o) {
            console.log( "GOT " + current_url );
            console.log( o.responseText );
            setCursor( "default" );
            callback( o );
        },
        failure:function(o) { 
            setCursor( "default" );
            console.log( "GET " + current_url + " failed:" + o.statusText ) 
        }
    };
    current_url = url;
    if ( transaction )
    {
        if ( YAHOO.util.Connect.isCallInProgress( transaction ) )
        {
            console.log( "abort " + transaction );
            YAHOO.util.Connect.abort( transaction );
        }
    }
    // console.log( "GET " + url );
    setCursor( "wait" );
    transaction = YAHOO.util.Connect.asyncRequest( 'GET', url, callbacks );
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
    if ( noRedraw ) return;
    setOrderBy();
    var order_by = document.forms[0].order_by.value;
    var status = "finding the top " + document.forms[0].limit.value + " ";
    status = status + "schools ";
    if ( order_by == "distance" )
    {
        status = status + "closest to " + document.forms[0].postcode.value;
    }
    else
    {
        status = status + "(ordered by " + order_by + ")";
    }
    setStatus( status );
    var bounds = map.getExtent();
    var query_string = 
        "&order_by=" + escape( order_by ) +
        "&limit=" + escape( document.forms[0].limit.value ) +
        "&minLon=" + escape( bounds.left ) + 
        "&maxLon=" + escape( bounds.right ) + 
        "&minLat=" + escape( bounds.bottom ) + 
        "&maxLat=" + escape( bounds.top )
    ;
    if ( postcodePt )
    {
        var x = document.forms[1].x.value;
        var y = document.forms[1].y.value;
        query_string +=
            "&centreLon=" + escape( postcodePt.lon ) +
            "&centreLat=" + escape( postcodePt.lat ) +
            "&centreX=" + escape( x ) +
            "&centreY=" + escape( y ) +
            "&postcode=" + escape( document.forms[0].postcode.value )
        ;
    }
    // else
    // {
        // var centre = map.getCenter();
        // query_string +=
            // "&centreLon=" + escape( centre.lon ) +
            // "&centreLat=" + escape( centre.lat )
        // ;
    // }
    schools = new Array();
    var url = schools_url + "?" + query_string;
    createLinkTo( query_string );
    get( url, getSchoolsCallback );
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
    var image = getIconUrl( letter, colour );
    return new OpenLayers.Icon(
        image, 
        new OpenLayers.Size( 20, 34 ),
        new OpenLayers.Pixel( -9, -27 )
    );
}

function createMarker( letter, colour, point )
{
    var icon = createIcon( letter, colour );
    var marker = new OpenLayers.Marker( point, icon );
    markersLayer.addMarker( marker );
    return marker;
}

function addPopup()
{
    if ( this.popup ) this.removePopup( this.popup );
    this.popup = new OpenLayers.Popup( 
        this.school.name,
        this.lonlat,
        new OpenLayers.Size( 200, 50 ),
        this.school.address
    );
    map.addPopup( this.popup, true );
}

var active_school;

function deActivateSchool( school )
{
    changeLinksColour( school.links, "blue" )
    changeMarkerColour( school.marker, "blue" )
    active_school = school;
    school.marker.active = false;
}

function activateSchool( school )
{
    changeLinksColour( school.links, "red" )
    changeMarkerColour( school.marker, "red" )
    if ( active_school ) deActivateSchool( active_school );
    school.marker.active = true;
}

function createSchoolMarker( school, colour ) 
{
    try {
        school.letter = getLetter( school.name );
        var point = new OpenLayers.LonLat( school.lon, school.lat );
        var marker = createMarker( school.letter, colour, point );
        marker.events.register( "mouseout", marker, function() { changeLinksColour( this.school.links, "blue" ) } );
        marker.events.register( "mouseover", marker, function() { changeLinksColour( this.school.links, "red" ) } );
        marker.school = school;
        school.marker = marker;
    }
    catch(e) { console.log( e ) }
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
        for ( var i = 0; i < keystages.length; i++ )
        {
            var keystage = keystages[i];
            var opt = addOpt( 
                document.forms[0].order_by, 
                keystage.description + " results", 
                keystage.name 
            );
        }
        if ( postcodePt )
        {
            var postcode = document.forms[0].postcode.value;
            var opt = addOpt( document.forms[0].order_by, "Distance from " + postcode, "distance" );
        }
        if ( curr ) document.forms[0].order_by.value = curr;
    }
    catch(e) { console.log( e ) }
}

function initTableHead( tr )
{
    var ths = new Array();
    createHeadCell( tr, "no" );
    createHeadCell( tr, "name", "Name of school" );
    createHeadCell( tr, "ofsted report", "link to Ofsted report" );
    for ( var i = 0; i < keystages.length; i++ ) 
        createHeadCell( tr, keystages[i].description, "average score" );
    ;
    if ( postcodePt ) 
    {
        var postcode = document.forms[0].postcode.value;
        createHeadCell( tr, "distance", "Distance from " + postcode );
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

function initMap()
{
    getQueryVariables();
    if ( params.debug ) logreader = new YAHOO.widget.LogReader();
    var oACDS = new YAHOO.widget.DS_XHR( postcodes_url, ["\n", "\t"]); 
    oACDS.responseType = YAHOO.widget.DS_XHR.prototype.TYPE_FLAT; 
    oACDS.queryMatchSubset = true; 
    var oAutoComp = new YAHOO.widget.AutoComplete(
        "ysearchinput",
        "ysearchcontainer", 
        oACDS
    );
    googleDiv = document.getElementById( "google" );
    listDiv = document.getElementById( "list" );
    google_html = googleDiv.innerHTML;
    default_centre = new OpenLayers.LonLat( -1.4881, 52.5713 );
    map = new OpenLayers.Map( 'map' );
    gmapLayer = new OpenLayers.Layer.Google( "Google Maps" );
    map.addLayer( gmapLayer );
    olLayer = new OpenLayers.Layer.WMS( "Metacarta", "http://labs.metacarta.com/wms/vmap0", {layers: 'basic'} );
    map.addLayer( olLayer );
    veLayer = new OpenLayers.Layer.VirtualEarth( "Virtual Earth", { 'type': VEMapStyle.Aerial } );
    map.addLayer( veLayer );
    // osLayer = new OpenLayers.Layer.WMS( "Openstreetmap", "http://tile.openstreetmap.org/ruby/wmsmod.rbx?" );
    // map.addLayer( osLayer );
    map.setCenter( default_centre );
    markersLayer = new OpenLayers.Layer.Markers( "Markers" );
    map.addLayer( markersLayer );
    map.addControl( new OpenLayers.Control.PanZoomBar() );
    map.addControl( new OpenLayers.Control.LayerSwitcher() );
    // var georssLayer = new OpenLayers.Layer.GeoRSS( "Geograph", "http://www.geograph.org.uk/syndicator.php?format=GeoRSS" );
    // map.addLayer( georssLayer );
    if ( 
        params.minLon &&
        params.minLat &&
        params.maxLon &&
        params.maxLat
    )
    {
        var bounds = new OpenLayers.Bounds( params.minLon, params.minLat, params.maxLon, params.maxLat );
        map.zoomToExtent( bounds );
    }
    else
    {
        map.zoomTo( default_zoom );
    }
    if ( params.centreLon && params.centreLat )
    {
        var centre = new OpenLayers.LonLat( params.centreLon, params.centreLat );
        map.setCenter( centre );
    }
    map.events.register( "zoomend", map, getSchools );
    map.events.register( "moveend", map, getSchools );
    if ( params.postcode ) document.forms[0].postcode.value = params.postcode;
    if ( params.limit ) document.forms[0].limit.value = params.limit;
    setOrderBy();
    getSchools();
}

function createListTd( text, url, school )
{
    var td = document.createElement( "TD" );
    if ( url )
    {
        var a = document.createElement( "A" );
        a.target = school.school_id;
        a.onclick = function() { window.open( url, "school", "status,scrollbars,resizable" ); return false; };
        a.href = url;
        if ( ! school.links ) school.links = new Array();
        school.links.push( a );
        a.style.color = "blue";
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
        td.appendChild( document.createTextNode( text ) );
    }
    td.style.verticalAlign = "top";
    return td;
}

function myround( num, precision )
{
    return Math.round( parseFloat( num ) * Math.pow( 10, precision ) );
}

function createListRow( no, school )
{
    var tr = document.createElement("TR");
    var url = school_url + "/" + school.school_id;
    tr.appendChild( createListTd( no+1, url, school ) );
    tr.appendChild( createListTd( school.name, url, school ) );
    var ofsted = "no";
    url = false;
    if ( school.ofsted_url ) 
    {
        ofsted = "yes";
        url = school_url + "/" + school.school_id + "?source=ofsted";
    }
    tr.appendChild( createListTd( ofsted, url, school ) );
    for ( var i = 0; i < keystages.length; i++ )
    {
        var keystage = keystages[i];
        var val = "-";
        var ave = "average_" + keystage.name;
        var url = false;
        if ( school[ave] && school[ave] != 0 )
        {
            val = school[ave];
            url = 
                school_url + "/" +
                school.school_id + 
                "?source=dfes"
            ;
        }
        var td = createListTd( val, url, school );
        td.noWrap = true;
        tr.appendChild( td );
    }
    if ( postcodePt )
    {
        var dist = sprintf( "%0.2f", ( school.distance / 1000 ) );
        tr.appendChild( createListTd( dist + " km" ) );
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
    span.appendChild( document.createTextNode( symbols[label] ) );
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
    a.appendChild( document.createTextNode( name ) );
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
        var tr = createListRow( i, schools[i] );
        tbody.appendChild( tr );
    }
    return table;
}

function getIconUrl( letter, colour )
{
    return icon_root_url + 'marker-' + colour.toUpperCase() + "-" + letter + '.png';
}

function changeMarkerColour( marker, colour )
{
    // var image = getIconUrl( letter, colour );
    // marker.icon.src = image;
    // markersLayer.redraw();
    createSchoolMarker( marker.school, colour );
    markersLayer.removeMarker( marker );
}

function changeLinksColour( links, color )
{
    if ( ! links ) return;
    for ( var i = 0; i < links.length; i++ )
    {
        link = links[i];
        link.style.color = color;
    }
}

function addOpt( sel, str, val, isSel )
{
    var opt = new Option( str, val );
    opt.selected = isSel;
    sel.options[sel.options.length] = opt;
    return opt;
}

function getLetter( name )
{
    name = name.replace( /The /i, "" );
    var letter = name.substr( 0, 1 ).toUpperCase();
    return letter;
}

function showInfo() 
{ 
    var x = this.lon;
    var y = this.lat;
    var pt = new OpenLayers.LonLat( x, y );
    var address = this.address.split( "," ).join( ",<br/>" );
    map.openInfoWindowHtml( pt, "<b>" + this.name + "</b>" + "<br/>" + address );
}
