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
var modperl_url = "schools";
var schools_url = cgi_url;
var nearby_url = "http://www.nearby.org.uk/";
var icon_root_url = 'http://bluweb.com/us/chouser/gmapez/iconEZ2/';
var schools;
var noRedraw = false;

var dfes_types = new Array();

var type2keystage = {
    post16:"GCE and VCE",
    secondary:"GCSE",
    primary:"Key stage 2"
};

var sources = {
    ofsted:"Ofsted",
    isi:"Independent Schools Inspectorate",
    dfes:"DfES",
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
    "isi report":"link to Independent Schools Inspectorate report for this school",
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
    setOrderBy();
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
    var url = postcode_url + "?postcode=" + escape( postcode );
    get( url, getPostcodeCallback );
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
    createMarker( "X", "red", postcodePt );
    map.setCenter( postcodePt );
    setOrderBy();
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

function initTypes()
{
    var source = document.forms[0].source.value;
    url = schools_url + "?types&source=" + source;
    get( url, initTypesCallback );
}

function getSchoolsCallback( response )
{
    markersLayer.clearMarkers();
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
        var school = xml2obj( schoolsXml[i] );
        schools.push( school );
        createSchoolMarker( school, "blue" );
    }
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
    if ( postcodePt )
    {
        var zl = max_zoom;
        noRedraw = true;
        createMarker( "X", "red", postcodePt );
        var markersOffScreen = 1;
        while ( markersOffScreen )
        {
            markersOffScreen = 0;
            map.zoomTo( zl-- );
            map.setCenter( postcodePt );
            markersOffScreen = 0;
            for ( var i = 0; i < markersLayer.markers.length; i++ )
            {
                var marker = markersLayer.markers[i];
                if ( ! marker.onScreen() )
                {
                    markersOffScreen++;
                }
            }
        }
        noRedraw = false;
    }
}

var transaction;
var current_url;

function get( url, callback )
{
    var callbacks = {
        success:function(o) {
            YAHOO.log( "GOT " + current_url );
            // YAHOO.log( o.responseText );
            callback( o );
        },
        failure:function(o) { 
            YAHOO.log( "GET " + current_url + " failed:" + o.statusText ) 
        }
    };
    current_url = url;
    if ( transaction )
    {
        if ( YAHOO.util.Connect.isCallInProgress( transaction ) )
        {
            YAHOO.log( "abort " + transaction );
            YAHOO.util.Connect.abort( transaction );
        }
    }
    YAHOO.log( "GET " + url );
    transaction = YAHOO.util.Connect.asyncRequest( 'GET', url, callbacks );
}

function getSchools()
{
    if ( noRedraw ) return;
    var type = document.forms[0].type.value;
    var source = document.forms[0].source.value;
    var order_by = document.forms[0].order_by.value;
    YAHOO.log( "order_by " + order_by );
    var order_by_str = "(ordered by " + order_by + ")";
    var url;
    var top = "";
    if ( order_by == "distance" )
    {
        order_by_str = 
            " closest to " + document.forms[0].postcode.value + " " +
            "(ordered by " + order_by + ")"
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
        type +
        " schools" +
        " from " + source + " " +
        order_by_str
    ); 
    var bounds = map.getExtent();
    url = schools_url + "?" +
        "source=" + escape( source ) +
        "&type=" + escape( type ) +
        "&orderBy=" + escape( order_by ) +
        "&limit=" + escape( document.forms[0].limit.value )
    ;
    if ( postcodePt )
    {
        url +=
            "&centreX=" + escape( postcodePt.lon ) +
            "&centreY=" + escape( postcodePt.lat )
        ;
    }
    url +=
        "&minX=" + escape( bounds.left ) + 
        "&maxX=" + escape( bounds.right ) + 
        "&minY=" + escape( bounds.bottom ) + 
        "&maxY=" + escape( bounds.top )
    ;
    schools = new Array();
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

function createMarker( letter, colour, point )
{
    var image = getIconUrl( letter, colour );
    var icon = new OpenLayers.Icon(
        image, 
        new OpenLayers.Size( 20, 34 ),
        new OpenLayers.Pixel( -9, -27 )
    );
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

function deActivateSchool( school )
{
    changeLinksColour( school.links, "blue" )
    changeMarkerColour( school.marker, "blue" )
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
        school.letter = getLetter( school.type );
        var point = new OpenLayers.LonLat( school.lon, school.lat );
        var marker = createMarker( school.letter, colour, point );
        // marker.events.register( "mouseover", marker, function() { activateSchool( this.school ) } );
        // marker.events.register( "mouseout", marker, function() { deActivateSchool( this.school ) } );
        marker.events.register( "click", marker, function() { toggleSchool( this.school ) } );
        marker.school = school;
        school.marker = marker;
    }
    catch(e) { alert( e ) }
}


function setOrderBy()
{
    removeChildren( document.forms[0].order_by );
    dfes_types = new Array();
    for ( var dfes_type in type2keystage )
    {
        var opt = addOpt( document.forms[0].order_by, type2keystage[dfes_type] + " results", "average_" + dfes_type );
        dfes_types.push( dfes_type );
        YAHOO.log( "add order_by option " + opt.value );
    }
    if ( postcodePt )
    {
        var postcode = document.forms[0].postcode.value;
        var opt = addOpt( document.forms[0].order_by, "Distance from " + postcode, "distance" );
        YAHOO.log( "add order_by option " + opt.value );
        document.forms[0].order_by.value = "distance";
        YAHOO.log( "set order_by = distance" );
    }
}

function initTypesCallback( response )
{
    try {
        var xmlDoc = response.responseXML;
        var typesXml = xmlDoc.documentElement.getElementsByTagName( "type" );
        var types = new Array();
        for ( var i = 0; i < typesXml.length; i++ )
        {
            var type = xml2obj( typesXml[i] );
            types.push( type );
        }
        removeChildren( document.forms[0].type );
        for ( var i = 0; i < types.length; i++ )
        {
            var type = types[i];
            addOpt( document.forms[0].type, type.label, type.name );
        }
        addOpt( document.forms[0].type, "All", "all" );
        document.forms[0].type.value = "all";
        if ( document.forms[0].postcode.value ) getPostcode();
        else getSchools();
    }
    catch(e) { alert( e ) }
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
    var obj = new Object();
    obj["name"] = "isi report";
    obj["orderable"] = false;
    ths.push( obj );
    for ( var i = 0; i < dfes_types.length; i++ )
    {
        var dfes_type = dfes_types[i];
        obj = new Object();
        obj["keys"] = new Array();
        var average = { "name":"average", "orderable":true, "dfes_type":dfes_type };
        var pupils = { "name":"pupils", "orderable":false, "dfes_type":dfes_type };
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

function initSources()
{
    removeChildren( document.forms[0].source );
    for ( var source in sources )
        addOpt( document.forms[0].source, sources[source], source );
    document.forms[0].source.value = "all";
}

function initMap()
{
    // logreader = new YAHOO.widget.LogReader();
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
    var gmapLayer = new OpenLayers.Layer.Google( "GMaps" );
    map.addLayer( gmapLayer );
    map.setCenter( default_centre );
    markersLayer = new OpenLayers.Layer.Markers( "Markers" );
    map.addLayer( markersLayer );
    initSources();
    map.zoomTo( default_zoom );
    setOrderBy();
    initTypes();
    map.events.register( "zoomend", map, getSchools );
    map.events.register( "moveend", map, getSchools );
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
    td.noWrap = ! wrap;
    return td;
}

function addCell( tr, dfes_type, keyname, school )
{
    var val = "-";
    var key = keyname + "_" + dfes_type;
    if ( school[key] && school[key] != 0 ) val = school[key];
    var url = school["url_" + dfes_type];
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
    var isi = "no";
    if ( school.isi_url ) isi = "yes";
    var onclick = function() { window.open( school.isi_url, "_new", "status,scrollbars" ); return false; };
    tr.appendChild( createListTd( isi, school.isi_url, school, onclick ) );
    for ( var i = 0; i < dfes_types.length; i++ )
    {
        var dfes_type = dfes_types[i];
        addCell( tr, dfes_type, "average", school );
        addCell( tr, dfes_type, "pupils", school );
    }
    var type = "-";
    if ( school.type ) type = school.type;
    tr.appendChild( createListTd( type ) );
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

function createHeadCell( tr, name, orderable, dfes_type )
{
    var key = name;
    if ( dfes_type ) key = name + "_" + dfes_type;
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
            th.appendChild( document.createTextNode( type2keystage[key.dfes_type] ) );
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
                createHeadCell( tr, keys[j].name, keys[j].orderable, keys[j].dfes_type );
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

var active_school;

function toggleSchool( school )
{
    if ( school.active ) deActivateSchool( school );
    else 
    {
        if ( active_school ) deActivateSchool( active_school );
        activateSchool( school );
        active_school = school;
    }
}

function addOpt( sel, str, val, isSel )
{
    var opt = new Option( str, val );
    opt.selected = isSel;
    sel.options[sel.options.length] = opt;
    return opt;
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
