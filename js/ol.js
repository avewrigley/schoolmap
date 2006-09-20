var googleDiv;
var google_html;
var map;
var markers;
var default_centre;
var default_zoom = 6;
var max_zoom = 15;
var postcodePt;
var cgi_url = "cgi/schools.cgi";
var modperl_url = "schools";
var schools_url = modperl_url;
var nearby_url = "http://www.nearby.org.uk/";
var icon_root_url = 'http://bluweb.com/us/chouser/gmapez/iconEZ2/';
var schools;

var types = new Array();

var dfes_type_names = {
    "16to18":"GCE and VCE",
    secondary:"GCSE",
    primary:"Key stage 2"
};

var ofsted_type_names = {
    secondary:"Secondary",
    post16:"Sixteen Plus",
    primary:"Primary",
    independent:"Independent",
    all:"All"
};

var default_order = {
    secondary:"average_secondary",
    post16:"average_16to18",
    independent:"average_16to18",
    primary:"average_primary",
    all:"average_secondary"
};

var explanation = {
    "name":"Name of school",
    "ofsted report":"link to Ofsted report for this school",
    "pupils_16to18":"Number of students aged 16-18",
    "average_16to18":"GCE and VCE results: average point score per student",
    "average_primary":"Key Stage 2: average point score",
    "pupils_primary":"Total pupils eligible for Key Stage 2 assesment",
    "average_secondary":"GCSE (and equivalent) results: average total point score per pupil",
    "pupils_secondary":"Number of pupils at the end of KS4"
};


var listDiv;

var letters = new Object();
letters["post16"] = "O";

function clearPostcode()
{
    document.forms[0].postcode.value = "";
    postcodePt = false;
    childReplace( nearbyDiv, document.createTextNode( '' ) );
    setDefaultOrder();
    getSchools();
}

function getPostcode()
{
    var postcode = document.forms[0].postcode.value;
    nearbyDiv = document.getElementById( "nearby" );
    if ( ! postcode.length )
    {
        postcodePt = false;
        childReplace( nearbyDiv, document.createTextNode( '' ) );
        return;
    }
    var a = document.createElement( "A" );
    a.href = nearby_url + "coord.cgi?p=" + escape( postcode );
    a.target = "nearby";
    a.appendChild( document.createTextNode( "click here for other stuff nearby " + postcode + " from " + nearby_url ) );
    childReplace( nearbyDiv, a );
    document.forms[0].gotobutton.disabled = true;
    setStatus( "finding " + postcode ); 
    var url = "cgi/postcode.cgi?postcode=" + escape( postcode );
    var transaction = YAHOO.util.Connect.asyncRequest( 'GET', url, { success:getPostcodeCallback } );
}

function getPostcodeCallback( response )
{
    var xmlDoc = response.responseXML;
    var coords = xmlDoc.documentElement.getElementsByTagName( "coords" );
    var x = coords[0].getAttribute( "lon" );
    var y = coords[0].getAttribute( "lat" );
    var code = coords[0].getAttribute( "code" );
    document.forms[0].postcode.value = code;
    postcodePt = new OpenLayers.LonLat( x, y );
    map.setCenter( postcodePt );
    initTypes();
    setDefaultOrder();
    document.forms[0].gotobutton.disabled = false;
    getSchools();
}

function removeChildren( parent )
{
    while ( parent.childNodes.length ) parent.removeChild( parent.childNodes[0] );
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

function setDefaultOrder()
{
    var ofsted_type = document.forms[0].ofsted_type.value;
    if ( default_order[ofsted_type] )
    {
        document.forms[0].order_by.value = default_order[ofsted_type];
    }
    if ( postcodePt && ofsted_type == "all" )
    {
        document.forms[0].order_by.value = "distance";
    }
}

var transaction;
var noRedraw = false;

function getSchoolsCallback( response )
{
    removeChildren( listDiv );
    googleDiv.innerHTML = google_html;
    var xmlDoc = response.responseXML;
    var meta = xmlDoc.documentElement.getElementsByTagName( "schools" );
    var schoolsXml = xmlDoc.documentElement.getElementsByTagName( "school" );
    var nschools;
    if ( meta ) nschools = meta[0].getAttribute( 'nschools' );
    var nSchools = schoolsXml.length;
    for ( var i = 0; i < schoolsXml.length; i++ )
    {
        createSchoolMarker( createSchool( schoolsXml[i] ), "blue" );
    }
    if ( postcodePt ) createMarker( "X", "red", postcodePt );
    if ( nschools && schoolsXml.length )
    {
        listDiv.appendChild( createListTable() );
        var b = document.createElement( "B" );
        b.appendChild( document.createTextNode( schoolsXml.length + " / " + nschools + " schools" ) );
        listDiv.appendChild( b );
    }
    else
    {
        setStatus( "there are no schools in on this map" ); 
    }
    var zl = max_zoom;
    noRedraw = true;
    var markersOffScreen = 1;
    while ( markersOffScreen )
    {
        markersOffScreen = 0;
        map.zoomTo( zl-- );
        markersOffScreen = 0;
        for ( var i = 0; i < markers.markers.length; i++ )
        {
            var marker = markers.markers[i];
            if ( ! marker.onScreen() )
            {
                markersOffScreen++;
            }
        }
    }
    noRedraw = false;
    transation = false;
}

function getSchools()
{
    if ( noRedraw ) return;
    var ofsted_type = document.forms[0].ofsted_type.value;
    var order_by = document.forms[0].order_by.value;
    var url;
    var top = "";
    var closest = "";
    if ( order_by == "distance" )
    {
        closest = " closest to " + document.forms[0].postcode.value + " ";
    }
    else
    {
        closest = " on this map ";
        top = "top ";
    }
    setStatus( 
        "finding the " + 
        document.forms[0].limit.value + " " +
        top +
        ofsted_type +
        " schools" +
        closest +
        "(ordered by " +
        order_by + 
        ")", 4
    ); 
    var bounds = map.getExtent();
    url = schools_url + "?" +
        "minX=" + escape( bounds.left ) + 
        "&maxX=" + escape( bounds.right ) + 
        "&minY=" + escape( bounds.bottom ) + 
        "&maxY=" + escape( bounds.top ) +
        "&limit=" + escape( document.forms[0].limit.value ) +
        "&orderBy=" + escape( order_by ) +
        "&ofstedType=" + escape( ofsted_type )
    ;
    if ( postcodePt )
    {
        url +=
            "&centreX=" + escape( postcodePt.lon ) +
            "&centreY=" + escape( postcodePt.lat )
        ;
    }
    schools = new Array();
    markers.clearMarkers();
    removeChildren( listDiv );
    if ( transaction ) YAHOO.util.Connect.abort( transaction );
    transaction = YAHOO.util.Connect.asyncRequest( 'GET', url, { success:getSchoolsCallback } );
}

function createSchool( schoolXML )
{
    var school = new Object();
    for ( var j = 0; j < schoolXML.attributes.length; j++ )
    {
        var attr = schoolXML.attributes.item( j );
        if ( attr.value ) school[attr.name] = attr.value;
    }
    schools.push( school );
    return school;
}

function createMarker( letter, colour, point )
{
    var image = getIconUrl( letter, colour );
    var icon = new OpenLayers.Icon( image, new OpenLayers.Size( 20, 34 ) );
    var marker = new OpenLayers.Marker( point, icon );
    markers.addMarker( marker );
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

function createSchoolMarker( school, colour ) 
{
    try {
        school.letter = getLetter( school.ofsted_type );
        var point = new OpenLayers.LonLat( school.lon, school.lat );
        var marker = createMarker( school.letter, colour, point );
        // marker.events.register( "mouseover", marker, mouseOver );
        // marker.events.register( "mouseout", marker, mouseOut );
        // marker.events.register( "click", marker, addPopup );
        marker.school = school;
        school.marker = marker;
    }
    catch(e) { alert( e ) }
}


function initTypes()
{
    removeChildren( document.forms[0].order_by );
    types = new Array();
    for ( var type in dfes_type_names )
    {
        addOpt( document.forms[0].order_by, dfes_type_names[type] + " results", "average_" + type );
        types.push( type );
    }
    if ( postcodePt )
    {
        var postcode = document.forms[0].postcode.value;
        addOpt( document.forms[0].order_by, "Distance from " + postcode, "distance" );
    }
    removeChildren( document.forms[0].ofsted_type );
    for ( var ofsted_type in ofsted_type_names )
    {
        addOpt( document.forms[0].ofsted_type, ofsted_type_names[ofsted_type], ofsted_type );
    }
    document.forms[0].ofsted_type.value = "all";
}

function initTableHead()
{
    var ths = new Array();
    var obj = new Object();
    obj["name"] = "name";
    obj["orderable"] = false;
    ths.push( obj );
    var obj = new Object();
    obj["name"] = "ofsted report";
    obj["orderable"] = false;
    ths.push( obj );
    for ( var i = 0; i < types.length; i++ )
    {
        var type = types[i];
        obj = new Object();
        obj["keys"] = new Array();
        var average = { "name":"average", "orderable":true, "type":type };
        var pupils = { "name":"pupils", "orderable":false, "type":type };
        obj["keys"].push( average );
        obj["keys"].push( pupils );
        obj["orderable"] = true;
        ths.push( obj );
    }
    var obj = new Object();
    obj["name"] = "type";
    obj["orderable"] = false;
    ths.push( obj );
    if ( postcodePt ) 
    {
        obj = new Object();
        obj["name"] = "distance";
        obj["orderable"] = true;
        ths.push( obj );
    }
    return ths;
}

function initMap()
{
    googleDiv = document.getElementById( "google" );
    listDiv = document.getElementById( "list" );
    google_html = googleDiv.innerHTML;
    default_centre = new OpenLayers.LonLat( -1.4881, 52.5713 );
    map = new OpenLayers.Map( 'map' );
    var gmapLayer = new OpenLayers.Layer.Google( "GMaps" );
    map.addLayer( gmapLayer );
    map.setCenter( default_centre );
    map.events.register( "zoomend", map, getSchools );
    map.events.register( "moveend", map, getSchools );
    markers = new OpenLayers.Layer.Markers( "Markers" );
    map.addLayer( markers );
    initTypes();
    if ( document.forms[0].postcode.value ) getPostcode();
    setDefaultOrder();
    map.zoomTo( default_zoom );
    getSchools();
}

function createListTd( text, url, school, onclick, wrap )
{
    var td = document.createElement( "TD" );
    if ( url )
    {
        var a = document.createElement( "A" );
        a.target = school.school_id;
        if ( onclick ) a.onclick = onclick;
        a.href = url;
        var marker = school.marker;
        a.marker = marker;
        if ( ! marker.links ) marker.links = new Array();
        marker.links.push( a );
        a.style.color = "blue";
        a.appendChild( document.createTextNode( text ) );
        td.appendChild( a );
        a.onmouseover = function() {
            activateMarker( marker );
        };
        a.onmouseout = function() {
            deActivateMarker( marker );
        };
    }
    else
    {
        td.appendChild( document.createTextNode( text ) );
    }
    td.noWrap = ! wrap;
    return td;
}

function addCell( tr, type, keyname, school )
{
    var val = "-";
    var key = keyname + "_" + type;
    if ( school[key] != 0 ) val = school[key];
    var url = school["url_" + type];
    var onclick = function() { window.open( url, "_new", "status,scrollbars" ); return false; };
    tr.appendChild( createListTd( val, url, school, onclick ) );
}

function createListRow( school )
{
    var onclick = function() { return false };
    var tr = document.createElement("TR");
    tr.appendChild( createListTd( school.name, "about:blank", school, onclick, true ) );
    var ofsted = "no";
    if ( school.ofsted_url ) ofsted = "yes";
    var onclick = function() { window.open( school.ofsted_url, "_new", "status,scrollbars" ); return false; };
    tr.appendChild( createListTd( ofsted, school.ofsted_url, school, onclick ) );
    for ( var i = 0; i < types.length; i++ )
    {
        var type = types[i];
        addCell( tr, type, "average", school );
        addCell( tr, type, "pupils", school );
    }
    var ofsted_type = "-";
    if ( school.ofsted_type ) ofsted_type = school.ofsted_type;
    tr.appendChild( createListTd( ofsted_type ) );
    if ( postcodePt )
    {
        var dist = school.distance;
        tr.appendChild( createListTd( dist + " miles" ) );
    }
    return tr;
}

var symbols = new Object();
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

function createHeadCell( tr, name, orderable, type )
{
    var key = name;
    if ( type ) key = name + "_" + type;
    var th = document.createElement( "TH" );
    th.style.verticalAlign = "top";
    tr.appendChild( th );
    var a = document.createElement( "A" );
    th.appendChild( a );
    th.appendChild( document.createElement( "BR" ) );
    a.name = key;
    a.title = explanation[key];
    a.style.color = "black";
    a.style.textDecoration = "none";
    a.href = "";
    a.onclick = function() { 
        alert( explanation[this.name] );
        return false;
    };
    a.appendChild( document.createTextNode( name ) );
    if ( ! orderable ) return;
}

function createListTable()
{
    var table = document.createElement( "TABLE" );
    var tbody = document.createElement( "TBODY" );
    table.appendChild( tbody );
    var tr = document.createElement( "TR" );
    tbody.appendChild( tr );
    var ths = initTableHead();
    for ( var i = 0; i < ths.length; i++ )
    {
        if ( ths[i].keys )
        {
            var key = ths[i].keys[0];
            var th = document.createElement( "TH" );
            tr.appendChild( th );
            th.colSpan = 2;
            th.appendChild( document.createTextNode( dfes_type_names[key.type] ) );
        }
        else
        {
            var th = document.createElement( "TH" );
            tr.appendChild( th );
            th.appendChild( document.createTextNode( '' ) );
        }
    }
    tr = document.createElement( "TR" );
    tbody.appendChild( tr );
    for ( var i = 0; i < ths.length; i++ )
    {
        if ( ths[i].keys )
        {
            var keys = ths[i].keys;
            for ( var j = 0; j < keys.length; j++ )
            {
                createHeadCell( tr, keys[j].name, keys[j].orderable, keys[j].type );
            }
        }
        else
        {
            createHeadCell( tr, ths[i].name, ths[i].orderable );
        }
    }
    for ( var i = 0; i < schools.length; i++ )
    {
        var tr = createListRow( schools[i] );
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
    // var url = getIconUrl( marker.school.letter, colour );
    // marker.icon.src = url;
    // markers.redraw();
    createSchoolMarker( marker.school, colour );
    markers.removeMarker( marker );
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

function mouseOut()
{
    deActivateMarker( this );
}

function mouseOver()
{
    activateMarker( this );
}

function deActivateMarker( marker )
{
    changeLinksColour( marker.links, "blue" )
    changeMarkerColour( marker, "blue" )
}

function activateMarker( marker )
{
    changeLinksColour( marker.links, "red" )
    changeMarkerColour( marker, "red" )
}

function addOpt( sel, str, val, isSel )
{
    var opt = new Option( str, val );
    opt.selected = isSel;
    sel.options[sel.options.length] = opt;
}

function getLetter( type )
{
    if ( ! type ) return "-";
    if ( type == "undefined" ) return "-";
    if ( type == "null" ) return "-";
    if ( letters[type] ) return letters[type];
    var letter = type.substr( 0, 1 ).toUpperCase();
    letters[type] = letter;
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
