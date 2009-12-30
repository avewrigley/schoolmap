var SCHOOLMAP = {
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
        "unknown":{ colour: "ff00ff", active_colour:"ffaaff" },
        "Secondary school":{ colour: "ff0000", active_colour:"ffaaaa" },
        "Independent school":{ colour: "00ff00", active_colour:"aaffaa" },
        "Independent special college":{ colour: "00ff00", active_colour:"aaffaa" },
        "Independent special school":{ colour: "00ff00", active_colour:"aaffaa" },
        "Higher education instituition":{ colour: "0000ff", active_colour:"aaaaff" },
        "Further education college":{ colour: "0000ff", active_colour:"aaaaff" },
        "Community special school":{ colour: "ff00ff", active_colour:"ffaaff" },
        "Primary school":{ colour: "00ffff", active_colour:"aaffff" },
    },
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
        GEvent.removeListener( SCHOOLMAP.handle_zoom );
        SCHOOLMAP.handle_zoom = false;
    }
    if ( SCHOOLMAP.handle_move )
    {
        GEvent.removeListener( SCHOOLMAP.handle_move );
        SCHOOLMAP.handle_move = false;
    }
}

SCHOOLMAP.clearFind = function( query ) {
    query.value = "";
    SCHOOLMAP.place = false;
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
    SCHOOLMAP.mgr.clearMarkers();
    // for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    // {
        // var school = SCHOOLMAP.schools[i];
        // if ( school.marker ) SCHOOLMAP.map.removeOverlay( school.marker );
        // school.marker = null;
    // }
    SCHOOLMAP.schools = new Array();
    SCHOOLMAP.active_school = false;
}

SCHOOLMAP.zoomSchools = function( response ) {
    if ( ! SCHOOLMAP.schools.length ) return;
    var bounds = new GLatLngBounds();
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
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

SCHOOLMAP.findSchoolCallback = function( response )
{
    var json = JSON.parse( response.responseText );
    SCHOOLMAP.nschools = json.nschools;
    SCHOOLMAP.schools = json.schools;
    SCHOOLMAP.updateSchools();
    SCHOOLMAP.zoomSchools();
}

SCHOOLMAP.findSchool = function( query ) {
    SCHOOLMAP.removeSchoolMarkers();
    var query_string = "&find_school=" + escape( query );
    var url = SCHOOLMAP.schools_url + "?" + query_string;
    SCHOOLMAP.createLinkTo( query_string );
    SCHOOLMAP.getJSON( url, SCHOOLMAP.findSchoolCallback );
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
    catch(e) { console.error( e.message ) }
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
    console.log( "linkto: " + url );
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
        var markers = [];
        for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
        {
            var school = SCHOOLMAP.schools[i];
            if ( ! school.type ) school.type = "unknown";
            var type = SCHOOLMAP.types[school.type];
            if ( ! type )
            {
                console.error( "no type for " + school.name + "(" + school.type + ")" );
                continue;
            }
            var colour = type.colour;
            var marker = SCHOOLMAP.createMarker( school, colour );
            markers.push( marker );
        }
        SCHOOLMAP.mgr.addMarkers( markers, 0, 17 );
        SCHOOLMAP.mgr.refresh();
        if ( SCHOOLMAP.schools.length )
        {
            listDiv.appendChild( SCHOOLMAP.createListTable() );
        }
        if ( SCHOOLMAP.place ) SCHOOLMAP.createAddressMarker();
        var b = document.createElement( "B" );
        b.appendChild( document.createTextNode( SCHOOLMAP.schools.length + " / " + SCHOOLMAP.nschools + " schools" ) );
        listDiv.appendChild( b );
    } catch( e ) { console.error( e.message ) }
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

SCHOOLMAP.getQueryString = function() {
    var order_by = document.forms[0].order_by.value;
    var type = document.forms[0].type.value;
    var special = document.forms[0].special.value;
    var age = document.forms[0].age.value;
    var bounds = SCHOOLMAP.map.getBounds();
    var center = SCHOOLMAP.map.getCenter();
    var zoom = SCHOOLMAP.map.getZoom();
    var sw = bounds.getSouthWest();
    var ne = bounds.getNorthEast();
    var query_string = 
        "&order_by=" + escape( order_by ) +
        "&type=" + escape( type ) +
        "&special=" + escape( special ) +
        "&limit=" + escape( document.forms[0].limit.value ) +
        "&minLon=" + escape( sw.lng() ) + 
        "&maxLon=" + escape( ne.lng() ) + 
        "&minLat=" + escape( sw.lat() ) + 
        "&maxLat=" + escape( ne.lat() )
    ;
    if ( age.length )
    {
        query_string = query_string + "&age=" + escape( age );
    }
    return query_string;
};

SCHOOLMAP.getSchools = function() {
    var query_string = SCHOOLMAP.getQueryString();
    SCHOOLMAP.removeSchoolMarkers();
    SCHOOLMAP.schools = new Array();
    SCHOOLMAP.active_school = false;
    var url = SCHOOLMAP.schools_url + "?" + query_string;
    SCHOOLMAP.createLinkTo( query_string );
    SCHOOLMAP.getJSON( url, SCHOOLMAP.getSchoolsCallback );
    var pageTracker = _gat._getTracker( "UA-242059-4" );
    pageTracker._trackPageview( url );
}

SCHOOLMAP.getSchoolsCallback = function( response ) {
    var json = JSON.parse( response.responseText );
    SCHOOLMAP.nschools = json.nschools;
    SCHOOLMAP.schools = json.schools;
    SCHOOLMAP.updateSchools();
    var query_string = SCHOOLMAP.getQueryString();
    var types_url = SCHOOLMAP.schools_url + "?" + query_string + "&types";
    SCHOOLMAP.get( types_url, SCHOOLMAP.typesNoUpdateCallback );
}

SCHOOLMAP.deActivateSchool = function( school ) {
    if ( ! school ) return;
    SCHOOLMAP.changeLinksColour( school, "4444ff" );
    var type = SCHOOLMAP.types[school.type];
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
            input.value = SCHOOLMAP.params[param];
        }
    }
}

SCHOOLMAP.activateSchool = function( school )
{
    SCHOOLMAP.changeLinksColour( school, "ff4444" );
    var type = SCHOOLMAP.types[school.type];
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
        if ( !  SCHOOLMAP.schools[i].meters ) SCHOOLMAP.calculateDistance( SCHOOLMAP.schools[i], true );
    }
}

SCHOOLMAP.setText = function( e, t ) {
    SCHOOLMAP.removeChildren( e );
    e.appendChild( document.createTextNode( t ) );
}

SCHOOLMAP.removeDistanceListeners = function( handle_error, handle_load ) {
    if ( handle_error )
    {
        GEvent.removeListener( handle_error );
        handle_error = false;
    }
    if ( handle_load )
    {
        GEvent.removeListener( handle_load );
        handle_load = false;
    }
}

SCHOOLMAP.convertMeters = function( m ) {
    if ( m < 1000 ) return m + " m";
    var km = m / 1000;
    return km + " km";
}

SCHOOLMAP.calculateDistance = function( school, all ) {
    if ( ! SCHOOLMAP.place ) return;
    SCHOOLMAP.setText( school.distance_link, "calclulating ..." )
    var from = school.lat + "," + school.lon;
    var to = SCHOOLMAP.place.address;
    school.directions_text = "from " + from + " to " + to;
    if ( ! all && SCHOOLMAP.current_gdir ) SCHOOLMAP.current_gdir.clear();
    var gdir = new GDirections( SCHOOLMAP.map );
    SCHOOLMAP.current_gdir = gdir;
    var handle_load;
    var handle_error;
    try {
        handle_load = GEvent.addListener( gdir, "load", function( obj ) { 
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
            if ( all ) gdir.clear();
            SCHOOLMAP.removeDistanceListeners( handle_error, handle_load );
        } );
        handle_error = GEvent.addListener( gdir, "error", function( obj ) { 
            console.error( "error: " + obj.getStatus().code );
            SCHOOLMAP.setText( school.distance_link, "error" )
            if ( all ) gdir.clear();
            SCHOOLMAP.removeDistanceListeners( handle_error, handle_load );
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

SCHOOLMAP.createMarker = function( school, colour ) {
    try {
        school.letter = SCHOOLMAP.getLetter( school );
        var point = new GLatLng( school.lat, school.lon );
        var icon = MapIconMaker.createLabeledMarkerIcon(
            { primaryColor: "#" + colour, label: school.letter }
        );
        icon.colour = colour;
        var marker = new GMarker( point, { "icon":icon } );
        // SCHOOLMAP.map.addOverlay( marker );
        GEvent.addListener( marker, "mouseout", function() { SCHOOLMAP.deActivateSchool( school ) } );
        GEvent.addListener( marker, "mouseover", function() { SCHOOLMAP.activateSchool( school ) } );
        var address = school.address.split( "," );
        GEvent.addListener( 
            marker, 
            "click", 
            function() {
                var html = "<p><b>" + school.name + "</b></p>";
                html = html + "<p>" + address.join( "<br />" ) + "</p>";
                html = html + "<p>" + school.postcode + "</p>";
                if ( school.HEAD_LAST )
                {
                    var head = school.HEAD_TITLE + " " + school.HEAD_FIRST + " " + school.HEAD_LAST;
                    if ( school.HEAD_HONOUR )
                    {
                        head = head + "<br />(" + school.HEAD_HONOUR + ")";
                    }
                   html = html + "<p><b>Head: </b>" + head + "</p>";
                }
                if ( school.ofsted_url ) 
                {
                   html = html + '<p><a href="' + school.ofsted_url + '">Ofsted report</a></p>';
                }
                marker.openInfoWindowHtml( html, { suppressMapPan:true } );
            } 
        );
        school.marker = marker;
        return marker;
    }
    catch(e) { console.error( e.message ) }
}

SCHOOLMAP.initTableHead = function( tr ) {
    var ths = new Array();
    SCHOOLMAP.createHeadCell( tr, "no" );
    SCHOOLMAP.createHeadCell( tr, "name", "Name of school" );
    SCHOOLMAP.createHeadCell( tr, "stage", "School stage" );
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
    if ( i.checked ) SCHOOLMAP.layers[i.name].show();
    else SCHOOLMAP.layers[i.name].hide();
}

SCHOOLMAP.ageRangeCallback = function( response ) {
    var age_range = JSON.parse( response.responseText );
    var sel = document.forms[0].age;
    for ( var i = age_range[0]; i <= age_range[1]; i++ )
    {
        SCHOOLMAP.addOpt( sel, { str:i, val:i } );
    }
    SCHOOLMAP.setParam( "age" );
    SCHOOLMAP.getSchools();
}

SCHOOLMAP.typesNoUpdateCallback = function( response ) {
    var types = JSON.parse( response.responseText );
    var sel = document.forms[0].type;
    var val = sel.value;
    SCHOOLMAP.removeChildren( sel );
    for ( var i = 0; i < types.length; i++ )
    {
        SCHOOLMAP.addOpt( sel, types[i] );
    }
    sel.value = val;
}

SCHOOLMAP.typesCallback = function( response ) {
    var types = JSON.parse( response.responseText );
    var sel = document.forms[0].type;
    SCHOOLMAP.removeChildren( sel );
    for ( var i = 0; i < types.length; i++ )
    {
        SCHOOLMAP.addOpt( sel, types[i] );
    }
    SCHOOLMAP.setParam( "type" );
    SCHOOLMAP.getSchools();
}

SCHOOLMAP.acronymsCallback = function( response ) {
    var specialisms = JSON.parse( response.responseText );
    var sel = document.forms[0].special;
    var keys = Object.keys( specialisms ).sort();
    for ( var i = 0; i < keys.length; i++ )
    {
        var s = keys[i];
        SCHOOLMAP.addOpt( sel, { str:specialisms[s], val:s } );
    }
    SCHOOLMAP.setParam( "special" );
    SCHOOLMAP.getSchools();
}

SCHOOLMAP.initMap = function() {
    // google.load( "maps", "2" );
    SCHOOLMAP.ignoreConsoleErrors();
    SCHOOLMAP.getQueryVariables();
    if ( ! GBrowserIsCompatible() )
    {
        console.log( "google maps not supported" );
        return;
    }
    var mapOptions = { 
        googleBarOptions : { 
            style : "new",
            adsOptions: {
                client: "6816728437",
                channel: "AdSense for Search channel",
                adsafe: "high",
                language: "en"
            }
        }
    };
    var map_div = document.getElementById( "map", mapOptions );
    SCHOOLMAP.map = new GMap2( map_div );
    SCHOOLMAP.map.setUIToDefault();
    SCHOOLMAP.map.enableGoogleBar();
    SCHOOLMAP.map.disableScrollWheelZoom();
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
    mapTd.appendChild( fieldset );

    var default_centre = new GLatLng( 53.82659674299412, -1.86767578125 );
    SCHOOLMAP.map.setCenter( default_centre, SCHOOLMAP.default_zoom );
    if ( 
        SCHOOLMAP.params.minLon &&
        SCHOOLMAP.params.minLat &&
        SCHOOLMAP.params.maxLon &&
        SCHOOLMAP.params.maxLat
    )
    {
        var sw = new GLatLng( SCHOOLMAP.params.minLon, SCHOOLMAP.params.minLat );
        var ne = new GLatLng( SCHOOLMAP.params.maxLon, SCHOOLMAP.params.maxLat );
        var bounds = new GLatLngBounds( sw, ne );
        var zoom = SCHOOLMAP.map.getBoundsZoomLevel( bounds );
        SCHOOLMAP.map.setZoom( zoom );
    }
    if ( SCHOOLMAP.params.centreLon && SCHOOLMAP.params.centreLat )
    {
        var centre = new GLatLng( SCHOOLMAP.params.centreLat, SCHOOLMAP.params.centreLon );
        SCHOOLMAP.map.setCenter( centre );
    }
    SCHOOLMAP.mgr = new MarkerManager( SCHOOLMAP.map );
    SCHOOLMAP.setMapListeners();
    SCHOOLMAP.setParams();
    SCHOOLMAP.get( SCHOOLMAP.acronyms_url, SCHOOLMAP.acronymsCallback );
    SCHOOLMAP.get( SCHOOLMAP.age_range_url, SCHOOLMAP.ageRangeCallback );

    // var query_string = SCHOOLMAP.getQueryString();
    // var types_url = SCHOOLMAP.schools_url + "?" + query_string + "&types";
    // SCHOOLMAP.get( types_url, SCHOOLMAP.typesCallback );

    if ( SCHOOLMAP.params.find_school )
    {
        console.log( "find school " + SCHOOLMAP.params.find_school );
        SCHOOLMAP.findSchool( SCHOOLMAP.params.find_school );
    }
    else
    {
        SCHOOLMAP.getSchools();
    }
}

SCHOOLMAP.createListTd = function( opts ) {
    var td = document.createElement( "TD" );
    if ( opts.url )
    {
        var a = document.createElement( "A" );
        a.target = "_blank";
        a.onclick = function() { window.open( opts.url, "school", "status,scrollbars,resizable,width=800,height=600" ); return false; };
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
    a.appendChild( document.createTextNode( opts.text ) );
    if ( opts.school )
    {
        if ( ! opts.school.links ) opts.school.links = new Array();
        opts.school.links.push( a );
        opts.school.distance_link = a;
        a.onclick = function() { opts.onclick( opts.school, false ); };
        a.onmouseover = function() {
            SCHOOLMAP.activateSchool( opts.school );
        };
        a.onmouseout = function() {
            SCHOOLMAP.deActivateSchool( opts.school );
        };
    }
    else
    {
        a.onclick = opts.onclick;
    }
    td.appendChild( a );
    return td;
}

SCHOOLMAP.createListRow = function( no, school ) {
    var tr = document.createElement( "TR" );
    var url = false;
    if ( school.dcsf_id && typeof school.dcsf_id != "undefined" )
    {
        url = SCHOOLMAP.school_url + "?table=dcsf&id=" + school.dcsf_id;
    }
    tr.appendChild( SCHOOLMAP.createListTd( { "text":no+1, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.name, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.type, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.TYPE_OF_ESTAB, "url":url, "school":school } ) );
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
    if ( SCHOOLMAP.place )
    {
        var tr = document.createElement( "TR" );
        var td = SCHOOLMAP.createDistanceTd( { text:"[ calculate all ]", onclick:SCHOOLMAP.calculateAllDistances } );
        td.colSpan = 11;
        td.align = "right";
        td.style.whiteSpace = "nowrap";
        tr.appendChild( td );
        tbody.appendChild( tr );
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
    if ( ! school ) return;
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

SCHOOLMAP.addOpt = function( sel, opts ) {
    var opt = new Option( opts.str, opts.val );
    if ( opts.isSel ) opt.selected = opts.isSel;
    sel.options[sel.options.length] = opt;
    return opt;
}

SCHOOLMAP.getLetter = function( school ) {
    var letter = school.type.substr( 0, 1 ).toUpperCase() +
        school.type.substr( 1, 1 ).toLowerCase();
    return letter;
}
