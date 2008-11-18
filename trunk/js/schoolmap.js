var SCHOOLMAP = {
    default_centre:new GLatLng( 53.82659674299412, -1.86767578125 ),
    default_zoom:6,
    address_zoom:12,
    schools_url:"schools",
    school_url:"school",
    acronyms_url:"acronyms.json?specials",
    age_range_url:"acronyms.json?age_range",
    schools:[],
    params:{},
    nschools:0,
    place:false,
    keystages:[
        { "name":"primary", "description":"Key stage 2" },
        { "name":"ks3", "description":"Key stage 3" },
        { "name":"secondary", "description":"GCSE" },
        { "name":"post16", "description":"GCE and VCE" }
    ],
    request:false,
    curtags:[ "body", "a", "input", "select", "div" ],
    types:{
        primary:{ colour: "0000ff", active_colour:"aaaaff" },
        secondary:{ colour: "ff0000", active_colour:"ffaaaa" },
        independent:{ colour: "00ff00", active_colour:"aaffaa" },
        special:{ colour: "00ffff", active_colour:"aaffff" }
    },
    handle_load:false,
    handle_error:false,
    handle_zoom:false,
    handle_move:false,
    layer_config:{
        panoramio: "com.panoramio.all",
        "panoramio (popular)": "com.panoramio.popular",
        wikipedia: "org.wikipedia.en"
    },
    layers:{},
    addressMarker:false
};

SCHOOLMAP.setMapListeners = function() {
    SCHOOLMAP.handle_zoom = GEvent.addListener( SCHOOLMAP.map, "zoomend", SCHOOLMAP.getSchools );
    SCHOOLMAP.handle_move = GEvent.addListener( SCHOOLMAP.map, "moveend", SCHOOLMAP.getSchools );
}

SCHOOLMAP.removeMapListeners = function() {
    if ( SCHOOLMAP.handle_zoom )
    {
        console.log( "remove zoom listener" );
        GEvent.removeListener( SCHOOLMAP.handle_zoom );
        SCHOOLMAP.handle_zoom = false;
    }
    if ( SCHOOLMAP.handle_move )
    {
        console.log( "remove move listener" );
        GEvent.removeListener( SCHOOLMAP.handle_move );
        SCHOOLMAP.handle_move = false;
    }
}

SCHOOLMAP.clearFind = function( query ) {
    query.value = "";
    SCHOOLMAP.place = false;
    console.log( "remove " + SCHOOLMAP.addressMarker );
    if ( SCHOOLMAP.addressMarker ) SCHOOLMAP.map.removeOverlay( SCHOOLMAP.addressMarker );
    SCHOOLMAP.addressMarker = false;
    SCHOOLMAP.getSchools();
}

SCHOOLMAP.place2point = function( a ) {
    return new GLatLng( a.Point.coordinates[1], a.Point.coordinates[0] );
}

SCHOOLMAP.createAddressMarker = function() {
    if ( ! SCHOOLMAP.place ) return;
    SCHOOLMAP.addressMarker = new GMarker( SCHOOLMAP.place.point );
    SCHOOLMAP.map.addOverlay( SCHOOLMAP.addressMarker );
}

SCHOOLMAP.removeSchoolMarkers = function() {
    var listDiv = document.getElementById( "list" );
    SCHOOLMAP.removeChildren( listDiv );
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        if ( school.marker ) SCHOOLMAP.map.removeOverlay( school.marker );
        school.marker = null;
    }
    SCHOOLMAP.schools = new Array();
    SCHOOLMAP.active_school = false;
}

SCHOOLMAP.zoomSchools = function( response ) {
    if ( ! SCHOOLMAP.schools.length ) return;
    var bounds = new GLatLngBounds();
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        console.log( school );
        var point = new GLatLng( school.lat, school.lon );
        bounds.extend( point );
    }
    var centre = bounds.getCenter();
    var zoom = SCHOOLMAP.map.getBoundsZoomLevel( bounds );
    console.log( "set centre to " + centre );
    console.log( "set zoom to " + zoom );
    SCHOOLMAP.removeMapListeners();
    SCHOOLMAP.map.setCenter( centre, zoom );
    SCHOOLMAP.setMapListeners();
}

SCHOOLMAP.findSchoolsCallback = function( response )
{
    var json = JSON.parse( response.responseText );
    SCHOOLMAP.nschools = json.nschools;
    SCHOOLMAP.schools = json.schools;
    SCHOOLMAP.updateSchools();
    SCHOOLMAP.zoomSchools();
}

SCHOOLMAP.findSchools = function( query ) {
    SCHOOLMAP.removeSchoolMarkers();
    var query_string = "&find_school=" + escape( query );
    var url = SCHOOLMAP.schools_url + "?" + query_string;
    SCHOOLMAP.createLinkTo( query_string );
    SCHOOLMAP.getJSON( url, SCHOOLMAP.findSchoolsCallback );
}

SCHOOLMAP.find = function( type, query ) {
    if ( ! query.length )
    {
        return;
    }
    if ( type == "school" )
    {
        SCHOOLMAP.findSchools( query );
    }
    else
    {
        SCHOOLMAP.findAddress();
    }
}

SCHOOLMAP.findAddress = function( query ) {
    var geocoder = new GClientGeocoder();
    geocoder.setBaseCountryCode( "uk" );
    geocoder.getLocations( 
        query, 
        function ( response ) {
            if ( ! response || response.Status.code != 200 ) 
            {
                alert("\"" + query + "\" not found");
                return;
            }
            SCHOOLMAP.place = response.Placemark[0];
            var point = SCHOOLMAP.place.point = SCHOOLMAP.place2point( SCHOOLMAP.place );
            SCHOOLMAP.createAddressMarker();
            SCHOOLMAP.map.setCenter( point );
            SCHOOLMAP.map.setZoom( SCHOOLMAP.address_zoom );
            SCHOOLMAP.getSchools();
        }
    );
}

SCHOOLMAP.removeChildren = function( parent ) {
    try {
        while ( parent.childNodes.length ) parent.removeChild( parent.childNodes[0] );
    }
    catch(e) { console.log( e.message ) }
}

SCHOOLMAP.createLinkTo = function( query_string ) {
    var url = document.URL;
    url = url.replace( /\?.*$/, "" );
    var url = url + "?" + query_string;
    var link1 = document.createElement( "A" );
    link1.href = url;
    SCHOOLMAP.setText( link1, "HTML" );
    var link2 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + ".xml?" + query_string + "&format=xml";
    link2.href = url;
    SCHOOLMAP.setText( link2, "XML" );
    var link3 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + ".rss?" + query_string + "&format=georss";
    link3.href = url;
    SCHOOLMAP.setText( link3, "GeoRSS" );
    var link4 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + ".kml?" + query_string + "&format=kml";
    link4.href = url;
    SCHOOLMAP.setText( link4, "KML" );
    var link5 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=json";
    link5.href = url;
    SCHOOLMAP.setText( link5, "JSON" );
    linkToDiv = document.getElementById( "linkto" );
    SCHOOLMAP.removeChildren( linkToDiv );
    var txt = document.createTextNode( "link to this page: " );
    linkToDiv.appendChild( txt );
    linkToDiv.appendChild( link1 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link2 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link3 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link4 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link5 );
}

SCHOOLMAP.updateSchools = function() {
    try {
        var body = document.getElementsByTagName( "body" );
        body[0].style.cursor = "auto";
        var listDiv = document.getElementById( "list" );
        for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
        {
            var school = SCHOOLMAP.schools[i];
            var type = SCHOOLMAP.types[school.ofsted_type];
            if ( ! type )
            {
                console.error( "no type for " + school.name );
            }
            var colour = type.colour;
            SCHOOLMAP.createSchoolMarker( school, colour );
        }
        if ( SCHOOLMAP.schools.length )
        {
            listDiv.appendChild( SCHOOLMAP.createListTable() );
        }
        else
        {
        }
        if ( SCHOOLMAP.place ) SCHOOLMAP.createAddressMarker();
        var b = document.createElement( "B" );
        b.appendChild( document.createTextNode( SCHOOLMAP.schools.length + " / " + SCHOOLMAP.nschools + " schools" ) );
        listDiv.appendChild( b );
    } catch( e ) { console.log( e.message ) }
}

SCHOOLMAP.getJSON = function( url, callback ) {
    SCHOOLMAP.setCursor( "wait" );
    if ( SCHOOLMAP.request )
    {
        console.log( "abort " + SCHOOLMAP.request );
        SCHOOLMAP.request.abort();
    }
    SCHOOLMAP.request = SCHOOLMAP.createXMLHttpRequest();
    SCHOOLMAP.request.open( 'GET', url, true );
    SCHOOLMAP.request.onreadystatechange = function() {
        if ( SCHOOLMAP.request.readyState != 4 ) return;
        if ( SCHOOLMAP.request.status == 0 ) return; // aborted request
        SCHOOLMAP.setCursor( "default" );
        if ( SCHOOLMAP.request.status == 200 ) callback( SCHOOLMAP.request );
        else console.error( "GET " + url + " failed: " + SCHOOLMAP.request.status );
    };
    SCHOOLMAP.request.send( null );
}

SCHOOLMAP.get = function( url, callback ) {
    var request = SCHOOLMAP.createXMLHttpRequest();
    request.open( 'GET', url, true );
    request.onreadystatechange = function() {
        if ( request.readyState != 4 ) return;
        if ( request.status == 0 ) return; // aborted request
        SCHOOLMAP.setCursor( "default" );
        if ( request.status == 200 ) callback( request );
        else console.error( "GET " + url + " failed: " + request.status );
    };
    request.send( null );
}

SCHOOLMAP.createXMLHttpRequest = function() {
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

SCHOOLMAP.setCursor = function( state ) {
    for ( var i = 0; i < SCHOOLMAP.curtags.length; i++ )
    {
        var tag = SCHOOLMAP.curtags[i];
        var es = document.getElementsByTagName( tag );
        for ( var j = 0; j < es.length; j++ )
        {
            es[j].style.cursor = state;
        }
    }
}

SCHOOLMAP.getSchools = function() {
    var order_by = document.forms[0].order_by.value;
    var ofsted_type = document.forms[0].ofsted_type.value;
    var special = document.forms[0].special.value;
    var age = document.forms[0].age.value;
    var bounds = SCHOOLMAP.map.getBounds();
    var center = SCHOOLMAP.map.getCenter();
    var zoom = SCHOOLMAP.map.getZoom();
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
    if ( age.length )
    {
        console.log( "add age parameter" );
        query_string = query_string + "&age=" + escape( age );
    }
    SCHOOLMAP.removeSchoolMarkers();
    SCHOOLMAP.schools = new Array();
    SCHOOLMAP.active_school = false;
    var url = SCHOOLMAP.schools_url + "?" + query_string;
    SCHOOLMAP.createLinkTo( query_string );
    SCHOOLMAP.getJSON( url, SCHOOLMAP.getSchoolsCallback );
}

SCHOOLMAP.getSchoolsCallback = function( response ) {
    var json = JSON.parse( response.responseText );
    SCHOOLMAP.nschools = json.nschools;
    SCHOOLMAP.schools = json.schools;
    SCHOOLMAP.updateSchools();
}

SCHOOLMAP.createMarker = function( letter, colour, point ) {
    var icon = MapIconMaker.createLabeledMarkerIcon(
        { primaryColor: "#" + colour, label: letter }
    );
    icon.colour = colour;
    var marker = new GMarker( point, { "icon":icon } );
    SCHOOLMAP.map.addOverlay( marker );
    return marker;
}

SCHOOLMAP.deActivateSchool = function( school ) {
    SCHOOLMAP.changeLinksColour( school, "4444ff" );
    var type = SCHOOLMAP.types[school.ofsted_type];
    if ( ! type )
    {
        console.error( "no type for " + school.name );
        return;
    }
    SCHOOLMAP.changeMarkerColour( school, type.colour );
}

SCHOOLMAP.setParams = function() {
    for ( var param in SCHOOLMAP.params )
    {
        SCHOOLMAP.setParam( param );
    }
}

SCHOOLMAP.setParam = function( param ) {
    if ( SCHOOLMAP.params[param] == "undefined" ) return;
    if ( typeof( SCHOOLMAP.params[param] ) == "undefined" ) return;
    for ( var i = 0; i < document.forms.length; i++ )
    {
        var input = document.forms[i][param];
        if ( input )
        {
            console.log( param + " = " + SCHOOLMAP.params[param] );
            input.value = SCHOOLMAP.params[param];
        }
    }
}

SCHOOLMAP.activateSchool = function( school )
{
    SCHOOLMAP.changeLinksColour( school, "ff4444" );
    var type = SCHOOLMAP.types[school.ofsted_type];
    if ( ! type )
    {
        console.error( "no type for " + school.name );
        return;
    }
    SCHOOLMAP.changeMarkerColour( school, type.active_colour )
    if ( SCHOOLMAP.active_school ) SCHOOLMAP.deActivateSchool( SCHOOLMAP.active_school );
    SCHOOLMAP.active_school = school;
}

SCHOOLMAP.calculateAllDistances = function() {
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        if ( !  SCHOOLMAP.schools[i].meters ) SCHOOLMAP.calculateDistance( SCHOOLMAP.schools[i] );
    }
}

SCHOOLMAP.empty = function( elem ) {
    while ( elem.firstChild ) remove( elem.firstChild );
}

SCHOOLMAP.setText = function( e, t ) {
    SCHOOLMAP.empty( e );
    e.appendChild( document.createTextNode( t ) );
}

SCHOOLMAP.removeDistanceListeners = function() {
    if ( SCHOOLMAP.handle_error )
    {
        console.log( "remove error listener" );
        GEvent.removeListener( SCHOOLMAP.handle_error );
        SCHOOLMAP.handle_error = false;
    }
    if ( SCHOOLMAP.handle_load )
    {
        console.log( "remove load listener" );
        GEvent.removeListener( SCHOOLMAP.handle_load );
        SCHOOLMAP.handle_load = false;
    }
}

SCHOOLMAP.convertMeters = function( m ) {
    if ( m < 1000 ) return m + " m";
    var km = m / 1000;
    return km + " km";
}
SCHOOLMAP.calculateDistance = function( school ) {
    if ( ! SCHOOLMAP.place ) return;
    console.log( "calclulate distance for " + school.name )
    SCHOOLMAP.setText( school.distance_link, "calclulating ..." )
    var from = school.lat + "," + school.lon;
    var to = SCHOOLMAP.place.address;
    school.directions_text = "from " + from + " to " + to;
    console.log( "get directions:" + school.directions_text );
    SCHOOLMAP.gdir.clear();
    try {
        SCHOOLMAP.removeDistanceListeners();
        SCHOOLMAP.handle_load = GEvent.addListener( SCHOOLMAP.gdir, "load", function( obj ) { 
            console.log( school.name + " route loaded" );
            SCHOOLMAP.setText( school.distance_link, "done ..." )
            try {
                var nroutes = obj.getNumRoutes();
                if ( nroutes >= 0 )
                {
                    var route = obj.getRoute( 0 );
                    var distance = route.getDistance();
                    if ( typeof( distance.meters ) == "number" )
                    {
                        school.meters = distance.meters;
                        SCHOOLMAP.setText( school.distance_link, SCHOOLMAP.convertMeters( school.meters ) );
                    }
                }
            } catch( e ) {
                console.error( school.name + " route calculation failed: " + e.message );
            }
            SCHOOLMAP.removeDistanceListeners();
        } );
        SCHOOLMAP.handle_error = GEvent.addListener( SCHOOLMAP.gdir, "error", function( obj ) { 
            console.log( "error: " + obj.getStatus().code );
            SCHOOLMAP.setText( school.distance_link, "error" )
            SCHOOLMAP.removeDistanceListeners();
        } );
        SCHOOLMAP.gdir.load( 
            school.directions_text,
            { preserveViewport:true, travelMode:"walking" }
        );
    } catch( e ) {
        console.error( e.message );
        return;
    }
}

SCHOOLMAP.createSchoolMarker = function( school, colour ) {
    try {
        school.letter = SCHOOLMAP.getLetter( school );
        var point = new GLatLng( school.lat, school.lon );
        var marker = SCHOOLMAP.createMarker( school.letter, colour, point );
        GEvent.addListener( marker, "mouseout", function() { SCHOOLMAP.deActivateSchool( school ) } );
        GEvent.addListener( marker, "mouseover", function() { SCHOOLMAP.activateSchool( school ) } );
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

SCHOOLMAP.setOrderBy = function() {
    try {
        SCHOOLMAP.removeChildren( document.forms[0].order_by );
        var opt = SCHOOLMAP.addOpt( 
            document.forms[0].order_by, 
            "-",
            ""
        );
        for ( var i = 0; i < SCHOOLMAP.keystages.length; i++ )
        {
            var keystage = SCHOOLMAP.keystages[i];
            var opt = SCHOOLMAP.addOpt( 
                document.forms[0].order_by, 
                keystage.description + " results", 
                keystage.name 
            );
        }
    }
    catch(e) { console.log( e.message ) }
}

SCHOOLMAP.initTableHead = function( tr ) {
    var ths = new Array();
    SCHOOLMAP.createHeadCell( tr, "no" );
    SCHOOLMAP.createHeadCell( tr, "name", "Name of school" );
    SCHOOLMAP.createHeadCell( tr, "type", "Type of school" );
    SCHOOLMAP.createHeadCell( tr, "age range", "Range of ages in the school" );
    SCHOOLMAP.createHeadCell( tr, "special", "Specialist Schools (as designated under the specialist school programme)" );
    SCHOOLMAP.createHeadCell( tr, "ofsted report", "Link to Ofsted report" );
    for ( var i = 0; i < SCHOOLMAP.keystages.length; i++ ) 
        SCHOOLMAP.createHeadCell( tr, SCHOOLMAP.keystages[i].description, "average score" );
    ;
    if ( SCHOOLMAP.place )
    {
        SCHOOLMAP.createHeadCell( tr, "distance", "Distance from " + SCHOOLMAP.place.address );
    }
}

SCHOOLMAP.getQueryVariables = function() {
    var query = window.location.search.substring( 1 );
    var vars = query.split( "&" );
    for ( var i = 0; i < vars.length; i++ ) 
    {
        var pair = vars[i].split( "=" );
        var key = unescape( pair[0] );
        var val = unescape( pair[1] );
        SCHOOLMAP.params[key] = val;
    } 
}

SCHOOLMAP.ignoreConsoleErrors = function() {
    if ( ! window.console )
    {
        window.console = {
            log:function() {},
            error:function() {}
        };
    }
}

SCHOOLMAP.toggleLayer = function( i ) {
    console.log( "togglePanoramio:" + i.checked );
    if ( i.checked ) SCHOOLMAP.layers[i.name].show();
    else SCHOOLMAP.layers[i.name].hide();
}

SCHOOLMAP.ageRangeCallback = function( response ) {
    var age_range = JSON.parse( response.responseText );
    console.log( age_range );
    var sel = document.forms[0].age;
    for ( var i = age_range[0]; i <= age_range[1]; i++ )
    {
        SCHOOLMAP.addOpt( sel, i, i );
    }
    SCHOOLMAP.setParam( "age" );
    SCHOOLMAP.getSchools();
}

SCHOOLMAP.acronymsCallback = function( response ) {
    var specialisms = JSON.parse( response.responseText );
    var sel = document.forms[0].special;
    for ( var s in specialisms )
    {
        SCHOOLMAP.addOpt( sel, specialisms[s], s );
    }
    SCHOOLMAP.setParam( "special" );
    SCHOOLMAP.getSchools();
}

SCHOOLMAP.initMap = function() {
    SCHOOLMAP.ignoreConsoleErrors();
    console.log( "init map" );
    SCHOOLMAP.getQueryVariables();
    if ( ! GBrowserIsCompatible() )
    {
        console.log( "google maps not supported" );
        return;
    }
    var map_div = document.getElementById( "map" );
    SCHOOLMAP.map = new GMap2( map_div );
    SCHOOLMAP.map.addControl( new GSmallMapControl() );
    SCHOOLMAP.map.addControl( new GMapTypeControl() );
    SCHOOLMAP.map.addMapType( G_SATELLITE_3D_MAP );
    SCHOOLMAP.map.addMapType( G_PHYSICAL_MAP );
    var mapTd = document.getElementById( "mapTd" );
    var fieldset = document.createElement( "FIELDSET" );
    var legend = document.createElement( "LEGEND" );
    legend.appendChild( document.createTextNode( "Layers" ) );
    fieldset.appendChild( legend );
    for ( var type in SCHOOLMAP.layer_config )
    {
        console.log( "set up " + type );
        SCHOOLMAP.layers[type] = new GLayer( SCHOOLMAP.layer_config[type] );
        SCHOOLMAP.map.addOverlay( SCHOOLMAP.layers[type] );
        var input = document.createElement( "INPUT" );
        input.type = "checkbox";
        input.name = input.id = type;
        input.onchange = function() { SCHOOLMAP.toggleLayer( this ) };
        if ( input.checked ) SCHOOLMAP.layers[type].show();
        else SCHOOLMAP.layers[type].hide();
        fieldset.appendChild( input );
        var label = document.createElement( "LABEL" );
        label.htmlFor = type;
        label.appendChild( document.createTextNode( type ) );
        fieldset.appendChild( label );
    }
    console.log( fieldset );
    mapTd.appendChild( fieldset );

    SCHOOLMAP.map.setCenter( SCHOOLMAP.default_centre, SCHOOLMAP.default_zoom );
    if ( 
        SCHOOLMAP.params.minLon &&
        SCHOOLMAP.params.minLat &&
        SCHOOLMAP.params.maxLon &&
        SCHOOLMAP.params.maxLat
    )
    {
        var sw = new GLatLng( SCHOOLMAP.params.minLon, SCHOOLMAP.params.minLat );
        console.log( sw );
        var ne = new GLatLng( SCHOOLMAP.params.maxLon, SCHOOLMAP.params.maxLat );
        console.log( ne );
        var bounds = new GLatLngBounds( sw, ne );
        console.log( bounds );
        var zoom = SCHOOLMAP.map.getBoundsZoomLevel( bounds );
        console.log( zoom );
        SCHOOLMAP.map.setZoom( zoom );
    }
    if ( SCHOOLMAP.params.centreLon && SCHOOLMAP.params.centreLat )
    {
        var centre = new GLatLng( SCHOOLMAP.params.centreLat, SCHOOLMAP.params.centreLon );
        SCHOOLMAP.map.setCenter( centre );
    }
    SCHOOLMAP.setMapListeners();
    SCHOOLMAP.setOrderBy();
    SCHOOLMAP.setParams();
    SCHOOLMAP.getSchools();
    SCHOOLMAP.gdir = new GDirections( SCHOOLMAP.map );
    SCHOOLMAP.get( SCHOOLMAP.acronyms_url, SCHOOLMAP.acronymsCallback );
    SCHOOLMAP.get( SCHOOLMAP.age_range_url, SCHOOLMAP.ageRangeCallback );
}

SCHOOLMAP.createListTd = function( opts ) {
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
            SCHOOLMAP.activateSchool( school );
        };
        a.onmouseout = function() {
            SCHOOLMAP.deActivateSchool( school );
        };
    }
    else
    {
        td.appendChild( document.createTextNode( opts.text ) );
    }
    td.style.verticalAlign = "top";
    return td;
}

SCHOOLMAP.createDistanceTd = function( opts ) {
    var td = document.createElement( "TD" );
    var a = document.createElement( "A" );
    a.onclick = function() { opts.onclick( opts.school ); };
    a.onmouseover = function() {
        SCHOOLMAP.activateSchool( opts.school );
    };
    a.onmouseout = function() {
        SCHOOLMAP.deActivateSchool( opts.school );
    };
    a.appendChild( document.createTextNode( opts.text ) );
    if ( ! opts.school.links ) opts.school.links = new Array();
    opts.school.links.push( a );
    opts.school.distance_link = a;
    td.appendChild( a );
    return td;
}

SCHOOLMAP.createListRow = function( no, school ) {
    var tr = document.createElement( "TR" );
    var url = SCHOOLMAP.school_url + "?table=dcsf&id=" + school.dcsf_id;
    tr.appendChild( SCHOOLMAP.createListTd( { "text":no+1, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.name, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.ofsted_type, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.age_range, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.special, "url":url, "school":school } ) );
    if ( school.ofsted_url ) 
    {
        var url = SCHOOLMAP.school_url + "?table=ofsted&id=" + school.ofsted_id;
        tr.appendChild( SCHOOLMAP.createListTd( { "text":"yes", "url":url, "school":school } ) );
    }
    else
    {
        tr.appendChild( SCHOOLMAP.createListTd( { text:"no" } ) );
    }
    for ( var i = 0; i < SCHOOLMAP.keystages.length; i++ )
    {
        var keystage = SCHOOLMAP.keystages[i];
        var ave = "average_" + keystage.name;
        if ( school[ave] && school[ave] != 0 )
        {
            var val = school[ave];
            var url = SCHOOLMAP.school_url + "?table=dcsf&type=" + keystage.name + "&id=" + school.dcsf_id;
            var td = SCHOOLMAP.createListTd( { "text":val, "url":url, "school":school } );
        }
        else
        {
            var td = SCHOOLMAP.createListTd( { "text":"-" } );
        }
        td.noWrap = true;
        tr.appendChild( td );
    }
    if ( SCHOOLMAP.place )
    {
        var td = SCHOOLMAP.createDistanceTd( { text:"[ calculate ]", school:school, onclick:SCHOOLMAP.calculateDistance } );
        td.style.whiteSpace = "nowrap";
        tr.appendChild( td );
    }
    return tr;
}

SCHOOLMAP.createHeadCell = function( tr, name, title ) {
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
    SCHOOLMAP.setText( a, name );
}

SCHOOLMAP.createListTable = function() {
    var table = document.createElement( "TABLE" );
    var tbody = document.createElement( "TBODY" );
    table.appendChild( tbody );
    var tr = document.createElement( "TR" );
    tbody.appendChild( tr );
    SCHOOLMAP.initTableHead( tr );
    tbody.appendChild( tr );
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        var tr = SCHOOLMAP.createListRow( i, school );
        tbody.appendChild( tr );
    }
    var ncells = tr.childNodes.length;
    if ( SCHOOLMAP.place )
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

SCHOOLMAP.changeMarkerColour = function( school, colour ) {
    var marker = school.marker;
    if ( ! marker ) return;
    var icon = marker.getIcon();
    var image = icon.image;
    var new_image = image.replace( icon.colour, colour );
    icon.colour = colour;
    marker.setImage( new_image );
}

SCHOOLMAP.changeLinksColour = function( school, color ) {
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

SCHOOLMAP.addOpt = function( sel, str, val, isSel ) {
    var opt = new Option( str, val );
    opt.selected = isSel;
    sel.options[sel.options.length] = opt;
    return opt;
}

SCHOOLMAP.getLetter = function( school ) {
    var letter = school.ofsted_type.substr( 0, 1 ).toUpperCase() +
        school.ofsted_type.substr( 1, 1 ).toLowerCase();
    return letter;
}
