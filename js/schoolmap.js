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
var school_url = "school";
var nearby_url = "http://www.nearby.org.uk/coord.cgi?p=";
var ononemap_url = "http://ononemap.com/map/?q=";
var gmapLayer;
var geLayer;
var olLayer;

var icon_root_url = 'http://bluweb.com/us/chouser/gmapez/iconEZ2/';
var schools;
var noRedraw = false;
var active_school;
var params = new Object();
var keystages = new Array();
var keystage2str = new Object();
var source2str = new Object();
var type2str = new Object();

var transaction;
var current_url;

var symbols = new Object();
var curtags = [ "body", "a", "input", "select", "div" ];
var listDiv;

var letters = new Object();
letters["post16"] = "O";

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
    var x = coords[0].getAttribute( "lon" );
    var y = coords[0].getAttribute( "lat" );
    var code = coords[0].getAttribute( "code" );
    document.forms[0].postcode.value = code;
    postcodePt = new OpenLayers.LonLat( x, y );
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

function initSources()
{
    var source = document.forms[0].source.value;
    url = schools_url + "?sources";
    get( url, initSourcesCallback );
}

function initSourcesCallback( response )
{
    try {
        var xmlDoc = response.responseXML;
        var sourcesXml = xmlDoc.documentElement.getElementsByTagName( "source" );
        var sources = new Array();
        for ( var i = 0; i < sourcesXml.length; i++ )
        {
            var source = xml2obj( sourcesXml[i] );
            sources.push( source );
        }
        removeChildren( document.forms[0].source );
        for ( var i = 0; i < sources.length; i++ )
        {
            var source = sources[i];
            addOpt( document.forms[0].source, source.description, source.name );
            source2str[source.name] = source.description;
        }
        addOpt( document.forms[0].source, "All", "all" );
        document.forms[0].source.value = "all";
        if ( params.source ) document.forms[0].source.value = params.source;
        initYears();
    }
    catch(e) { alert( e ) }
}

function initYears()
{
    url = schools_url + "?years";
    get( url, initYearsCallback );
}

function initYearsCallback( response )
{
    try {
        var xmlDoc = response.responseXML;
        var yearsXml = xmlDoc.documentElement.getElementsByTagName( "year" );
        removeChildren( document.forms[0].year );
        for ( var i = 0; i < yearsXml.length; i++ )
        {
            var year = xml2obj( yearsXml[i] );
            addOpt( document.forms[0].year, year.year, year.year );
        }
        if ( params.year ) document.forms[0].year.value = params.year;
        initKeystages();
    }
    catch(e) { alert( e ) }
}

function initKeystages()
{
    url = schools_url + "?keystages";
    get( url, initKeystagesCallback );
}

function initKeystagesCallback( response )
{
    try {
        var xmlDoc = response.responseXML;
        var keystagesXml = xmlDoc.documentElement.getElementsByTagName( "keystage" );
        for ( var i = 0; i < keystagesXml.length; i++ )
        {
            var keystage = xml2obj( keystagesXml[i] );
            keystages.push( keystage );
            keystage2str[keystage.name] = keystage.description;
        }
        initTypes();
    }
    catch(e) { alert( e ) }
}

function initTypes()
{
    var source = document.forms[0].source.value;
    url = schools_url + "?types&source=" + source;
    get( url, initTypesCallback );
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
            type2str[type.name] = type.label;
        }
        addOpt( document.forms[0].type, "All", "all" );
        document.forms[0].type.value = "all";
        if ( params.type ) document.forms[0].type.value = params.type;
        if ( document.forms[0].postcode.value ) getPostcode();
        else getSchools();
    }
    catch(e) { alert( e ) }
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

function get( url, callback )
{
    var callbacks = {
        success:function(o) {
            // YAHOO.log( "GOT " + current_url );
            // YAHOO.log( o.responseText );
            setCursor( "default" );
            callback( o );
        },
        failure:function(o) { 
            setCursor( "default" );
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
    // YAHOO.log( "GET " + url );
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
        status = status + "(ordered by " + keystage2str[order_by] + ")";
    }
    var year = document.forms[0].year.value;
    status = status + " for " + year;
    setStatus( status );
    var bounds = map.getExtent();
    var query_string = 
        "source=" + escape( source ) +
        "&year=" + escape( year ) +
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
        // marker.events.register( "mouseout", marker, function() { deActivateSchool( this.school ) } );
        // marker.events.register( "mouseover", marker, function() { activateSchool( this.school ) } );
        marker.events.register( "click", marker, function() { toggleSchool( this.school ) } );
        marker.school = school;
        school.marker = marker;
    }
    catch(e) { YAHOO.log( e ) }
}


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
    catch(e) { YAHOO.log( e ) }
}

function initTableHead( tr )
{
    var ths = new Array();
    createHeadCell( tr, "no" );
    createHeadCell( tr, "name", "Name of school" );
    createHeadCell( tr, "ofsted report", "link to Ofsted report" );
    createHeadCell( tr, "isi report", "link to Independent Schools Inspectorate report" );
    for ( var i = 0; i < keystages.length; i++ ) 
        createHeadCell( tr, keystages[i].description, "average score" );
    ;
    createHeadCell( tr, "type", "Type of school" );
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
    olLayer = new OpenLayers.Layer.WMS( "OpenLayers WMS", "http://labs.metacarta.com/wms/vmap0", {layers: 'basic'} );
    map.addLayer( olLayer );
    geLayer = new OpenLayers.Layer.VirtualEarth( "Virtual Earth", { 'type': VEMapStyle.Aerial } );
    map.addLayer( geLayer );
    map.setCenter( default_centre );
    markersLayer = new OpenLayers.Layer.Markers( "Markers" );
    map.addLayer( markersLayer );
    map.addControl( new OpenLayers.Control.PanZoomBar() );
    map.addControl( new OpenLayers.Control.LayerSwitcher() );
    // var georssLayer = new OpenLayers.Layer.GeoRSS( "Geograph", "http://www.geograph.org.uk/syndicator.php?format=GeoRSS" );
    // map.addLayer( georssLayer );
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
    map.events.register( "zoomend", map, getSchools );
    map.events.register( "moveend", map, getSchools );
    if ( params.postcode ) document.forms[0].postcode.value = params.postcode;
    if ( params.limit ) document.forms[0].limit.value = params.limit;
    initSources();
}

function createListTd( text, url, school )
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
    var isi = "no";
    url = false;
    if ( school.isi_url ) 
    {
        isi = "yes";
        url = school_url + "/" + school.school_id + "?source=isi";
    }
    tr.appendChild( createListTd( isi, url, school ) );
    for ( var i = 0; i < keystages.length; i++ )
    {
        var keystage = keystages[i];
        var val = "-";
        var ave = "average_" + keystage.name;
        var url = false;
        if ( school[ave] && school[ave] != 0 )
        {
            val = school[ave];
            var year = document.forms[0].year.value;
            url = 
                school_url + "/" +
                school.school_id + 
                "?source=dfes" +
                "&type=" + keystage.name +
                "&year=" + year
            ;
        }
        var td = createListTd( val, url, school );
        td.noWrap = true;
        tr.appendChild( td );
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
