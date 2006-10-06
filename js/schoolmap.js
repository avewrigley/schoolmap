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
var schools_url = "schools.xml";
var school_url = "cgi/school.cgi";
var nearby_url = "http://www.nearby.org.uk/";
var icon_root_url = 'http://bluweb.com/us/chouser/gmapez/iconEZ2/';
var schools;
var noRedraw = false;
var params = new Object();

var dfes_types = new Array();

var dfes_type2str = {
    post16:"GCE and VCE",
    secondary:"GCSE",
    primary:"Key stage 2"
};

var source2str = {
    ofsted:"Ofsted",
    isi:"Independent Schools Inspectorate",
    dfes:"DfES",
    all:"All"
};

var order_by2str = {
    "name":"Name of school",
    "ofsted report":"link to Ofsted report for this school",
    "isi report":"link to Independent Schools Inspectorate report for this school",
    "pupils_post16":"Number of students aged 16-18",
    "average_post16":"GCE and VCE results: average point score per student",
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
    a.appendChild( document.createTextNode( "other stuff nearby " + postcode + " from " + nearby_url ) );
    childReplace( nearbyDiv, a );
    document.forms[0].gotobutton.disabled = true;
    setStatus( "finding " + postcode ); 
    var url = postcode_url + "?postcode=" + escape( postcode );
    get( url, getPostcodeCallback );
}

function createLinkTo( query_string )
{
    var url = document.URL;
    url = url.replace( /\?.*$/, "" );
    var url = url + "?" + query_string;
    var link1 = document.createElement( "A" );
    link1.href = url;
    link1.appendChild( document.createTextNode( "link to this page" ) );
    var link2 = document.createElement( "A" );
    url = schools_url + "?" + query_string;
    link2.href = url;
    link2.appendChild( document.createTextNode( "schools data for this page as XML" ) );
    linkToDiv = document.getElementById( "linkto" );
    removeChildren( linkToDiv );
    linkToDiv.appendChild( link1 );
    linkToDiv.appendChild( document.createElement( "BR" ) );
    linkToDiv.appendChild( link2 );
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
    try {
        while ( parent.childNodes.length ) parent.removeChild( parent.childNodes[0] );
    }
    catch(e) { YAHOO.log( e ) }
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
    try {
        markersLayer.clearMarkers();
        removeChildren( listDiv );
        googleDiv.innerHTML = google_html;
        var xmlDoc = response.responseXML;
        var nschools = xmlDoc.documentElement.getAttribute( 'nschools' );
        var schoolsXml = xmlDoc.documentElement.getElementsByTagName( "school" );
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
    } catch( e ) { alert( e ) }
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
    var status = "finding the top " + document.forms[0].limit.value + " ";
    if ( type != "all" ) status = status + type2str[type] + " ";
    status = status + "schools ";
    if ( source != 'all' ) status = status + "from " + source2str[source] + " ";
    if ( order_by == "distance" )
    {
        status = status + "closest to " + document.forms[0].postcode.value;
    }
    else
    {
        status = status + "(ordered by " + order_by2str[order_by] + ")";
    }
    setStatus( status );
    var bounds = map.getExtent();
    var query_string = 
        "source=" + escape( source ) +
        "&type=" + escape( type ) +
        "&order_by=" + escape( order_by ) +
        "&limit=" + escape( document.forms[0].limit.value ) +
        "&minX=" + escape( bounds.left ) + 
        "&maxX=" + escape( bounds.right ) + 
        "&minY=" + escape( bounds.bottom ) + 
        "&maxY=" + escape( bounds.top )
    ;
    if ( postcodePt )
    {
        query_string +=
            "&centreX=" + escape( postcodePt.lon ) +
            "&centreY=" + escape( postcodePt.lat ) +
            "&postcode=" + escape( document.forms[0].postcode.value )
        ;
    }
    else
    {
        var centre = map.getCenter();
        query_string +=
            "&centreX=" + escape( centre.lon ) +
            "&centreY=" + escape( centre.lat )
        ;
    }
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
    catch(e) { YAHOO.log( e ) }
}


function setOrderBy()
{
    removeChildren( document.forms[0].order_by );
    dfes_types = new Array();
    try {
        for ( var dfes_type in dfes_type2str )
        {
            var opt = addOpt( document.forms[0].order_by, dfes_type2str[dfes_type] + " results", "average_" + dfes_type );
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
        if ( params.order_by ) document.forms[0].order_by.value = params.order_by;
    }
    catch(e) { YAHOO.log( e ) }
}

var type2str = new Object();

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
            type2str[type.name] = type.label;
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
    ths.push( { name:"no" } );
    ths.push( { name:"name" } );
    ths.push( { name:"ofsted report" } );
    ths.push( { name:"isi report" } );
    for ( var i = 0; i < dfes_types.length; i++ )
    {
        var dfes_type = dfes_types[i];
        obj = new Object();
        obj["keys"] = new Array();
        var average = { "name":"average", "dfes_type":dfes_type };
        var pupils = { "name":"pupils", "dfes_type":dfes_type };
        obj["keys"].push( average );
        obj["keys"].push( pupils );
        ths.push( obj );
    }
    var obj = new Object();
    obj["name"] = "type";
    ths.push( obj );
    if ( postcodePt ) 
    {
        obj = new Object();
        obj["name"] = "distance";
        ths.push( obj );
    }
    return ths;
}

function initSources()
{
    try {
        removeChildren( document.forms[0].source );
        for ( var source in source2str )
            addOpt( document.forms[0].source, source2str[source], source );
        document.forms[0].source.value = "all";
        if ( params.source ) document.forms[0].source.value = params.source;
    }
    catch( e ) { YAHOO.log( e ) }
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
    var gmapLayer = new OpenLayers.Layer.Google( "GMaps" );
    map.addLayer( gmapLayer );
    map.setCenter( default_centre );
    markersLayer = new OpenLayers.Layer.Markers( "Markers" );
    map.addLayer( markersLayer );
    initSources();
    if ( 
        params.minX &&
        params.minY &&
        params.maxX &&
        params.maxY
    )
    {
        var bounds = new OpenLayers.Bounds( params.minX, params.minY, params.maxX, params.maxY );
        map.zoomToExtent( bounds );
    }
    else
    {
        map.zoomTo( default_zoom );
    }
    if ( params.centreX && params.centreY )
    {
        var centre = new OpenLayers.LonLat( params.centreX, params.centreY );
        map.setCenter( centre );
    }
    setOrderBy();
    map.events.register( "zoomend", map, getSchools );
    map.events.register( "moveend", map, getSchools );
    if ( params.postcode ) document.forms[0].postcode.value = params.postcode;
    if ( params.limit ) document.forms[0].limit.value = params.limit;
    initTypes();
}

function createListTd( text, url, school, wrap )
{
    var td = document.createElement( "TD" );
    if ( url )
    {
        var a = document.createElement( "A" );
        a.target = school.school_id;
        a.onclick = function() { window.open( url, "_new", "status,scrollbars" ); return false; };
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
    td.style.verticalAlign = "top";
    return td;
}

function addCell( tr, dfes_type, keyname, school )
{
    var val = "-";
    var key = keyname + "_" + dfes_type;
    var url;
    if ( school[key] && school[key] != 0 )
    {
        val = school[key];
        url = school_url + "?source=dfes&school_id=" + school.school_id;
    }
    tr.appendChild( createListTd( val, url, school ) );
}

function myround( num, precision )
{
    return Math.round( parseFloat( num ) * Math.pow( 10, precision ) );
}

function createListRow( no, school )
{
    var tr = document.createElement("TR");
    var url = school_url + "?school_id=" + school.school_id;
    tr.appendChild( createListTd( no+1, url, school, true ) );
    tr.appendChild( createListTd( school.name, url, school, true ) );
    var ofsted = "no";
    url = false;
    if ( school.ofsted_url ) 
    {
        ofsted = "yes";
        url = school_url + "?source=ofsted&school_id=" + school.school_id;
    }
    tr.appendChild( createListTd( ofsted, url, school ) );
    var isi = "no";
    url = false;
    if ( school.isi_url ) 
    {
        isi = "yes";
        url = school_url + "?source=isi&school_id=" + school.school_id;
    }
    tr.appendChild( createListTd( isi, url, school ) );
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
        var dist = sprintf( "%0.2f", school.distance );
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

function createHeadCell( tr, name, dfes_type )
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
    a.title = order_by2str[key];
    a.style.color = "black";
    a.style.textDecoration = "none";
    a.href = "";
    a.onclick = function() { 
        alert( order_by2str[this.name] );
        return false;
    };
    a.appendChild( document.createTextNode( name ) );
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
            th.appendChild( document.createTextNode( dfes_type2str[key.dfes_type] ) );
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
                createHeadCell( tr, keys[j].name, keys[j].dfes_type );
            }
        }
        else
        {
            createHeadCell( tr, ths[i].name );
        }
    }
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
