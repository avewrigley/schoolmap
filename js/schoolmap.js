var SCHOOLMAP = {
    default_zoom:12,
    default_center:new GLatLng( 53.82659674299412, -1.86767578125 ),
    schools_url:"schools",
    school_url:"school",
    schools:[],
    params:{},
    nschools:0,
    place:false,
    result_types:{ 
        "primary":"Key stage 2",
        "ks3":"Key stage 3",
        "secondary":"GCSE",
        "post16":"GCE and VCE" 
    },
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

SCHOOLMAP.setMapListeners = function() 
{
    SCHOOLMAP.handle_zoom = GEvent.addListener( 
        SCHOOLMAP.map, 
        "zoomend", 
        function() { SCHOOLMAP.getSchools(); }
    );
    SCHOOLMAP.handle_move = GEvent.addListener( 
        SCHOOLMAP.map, 
        "moveend", 
        function() {
            SCHOOLMAP.getSchools();
        }
    );
};

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

SCHOOLMAP.place2point = function( a ) 
{
    return new GLatLng( a.Point.coordinates[1], a.Point.coordinates[0] );
};

SCHOOLMAP.createAddressIcon = function() 
{
    var myIcon = new GIcon();
    myIcon.image = '/markers/image.png';
    myIcon.shadow = '/markers/shadow.png';
    myIcon.iconSize = new GSize(32,37);
    myIcon.shadowSize = new GSize(51,37);
    myIcon.iconAnchor = new GPoint(16,37);
    myIcon.infoWindowAnchor = new GPoint(16,0);
    myIcon.printImage = '/markers/printImage.gif';
    myIcon.mozPrintImage = '/markers/mozPrintImage.gif';
    myIcon.printShadow = '/markers/printShadow.gif';
    myIcon.transparent = '/markers/transparent.png';
    myIcon.imageMap = [29,0,30,1,31,2,31,3,31,4,31,5,31,6,31,7,31,8,31,9,31,10,31,11,31,12,31,13,31,14,31,15,31,16,31,17,31,18,31,19,31,20,31,21,31,22,31,23,31,24,31,25,31,26,31,27,31,28,31,29,30,30,29,31,23,32,22,33,21,34,20,35,19,36,12,36,11,35,10,34,9,33,8,32,2,31,1,30,0,29,0,28,0,27,0,26,0,25,0,24,0,23,0,22,0,21,0,20,0,19,0,18,0,17,0,16,0,15,0,14,0,13,0,12,0,11,0,10,0,9,0,8,0,7,0,6,0,5,0,4,0,3,0,2,1,1,2,0];
    return myIcon;
}

SCHOOLMAP.createAddressMarker = function() 
{
    if ( ! SCHOOLMAP.place ) return;
    if ( SCHOOLMAP.addressMarker ) return;
    SCHOOLMAP.addressMarker = new GMarker( 
        SCHOOLMAP.place.point, 
        { draggable: true, icon:SCHOOLMAP.createAddressIcon() } 
    );
    GEvent.addListener( 
        SCHOOLMAP.addressMarker, 
        "dragend", 
        function( latlng ) { 
            console.log( latlng );
            SCHOOLMAP.findAddress( 
                latlng.lat() + "," + latlng.lng(),
                function( point ) {
                    SCHOOLMAP.resetDistances();
                    SCHOOLMAP.updateSchools();
                }
            );
        }
    );
    SCHOOLMAP.map.addOverlay( SCHOOLMAP.addressMarker );
};

SCHOOLMAP.removeSchoolMarkers = function() 
{
    var listDiv = document.getElementById( "list" );
    SCHOOLMAP.removeChildren( listDiv );
    SCHOOLMAP.mgr.clearMarkers();
    SCHOOLMAP.schools = new Array();
    SCHOOLMAP.active_school = false;
};

SCHOOLMAP.findAddress = function( query, callback ) 
{
    console.log( "find address " + query );
    SCHOOLMAP.geocoder.getLocations( 
        query, 
        function ( response ) {
            if ( ! response || response.Status.code != 200 ) 
            {
                alert("\"" + query + "\" not found");
                return;
            }
            console.log( "address found " + response );
            SCHOOLMAP.place = response.Placemark[0];
            var point = SCHOOLMAP.place.point = SCHOOLMAP.place2point( SCHOOLMAP.place );
            SCHOOLMAP.createAddressMarker();
            var input = document.getElementById( "address" );
            input.value = SCHOOLMAP.place.address;
            var span = document.getElementById( "coords" );
            SCHOOLMAP.setText( span, "(" + SCHOOLMAP.place.point.lat() + "," + SCHOOLMAP.place.point.lng() + ")" );
            if ( callback ) callback( point );
        }
    );
};

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
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=xml";
    console.log( "linkto: " + url );
    link1.href = url;
    SCHOOLMAP.setText( link1, "XML" );
    var link2 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=georss";
    link2.href = url;
    SCHOOLMAP.setText( link2, "GeoRSS" );
    var link3 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=kml";
    link3.href = url;
    SCHOOLMAP.setText( link3, "KML" );
    var link4 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=json";
    link4.href = url;
    SCHOOLMAP.setText( link4, "JSON" );
    linkToDiv = document.getElementById( "linkto" );
    if ( ! linkToDiv ) return;
    SCHOOLMAP.removeChildren( linkToDiv );
    linkToDiv.appendChild( document.createTextNode( "link to this page: " ) );
    linkToDiv.appendChild( link1 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link2 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link3 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link4 );
}

SCHOOLMAP.getJSON = function( url, callback ) 
{
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
    var order_by = document.forms[0].order_by;
    if ( ! order_by ) return false;
    var order_by_val = order_by.value;
    if ( order_by_val == "distance" ) order_by_val = "";
    var type = document.forms[0].type;
    if ( ! type ) return false;
    var type_val = type.value;
    if ( type_val == "all" ) type_val = "";

    var bounds = SCHOOLMAP.map.getBounds();
    var sw = bounds.getSouthWest();
    var ne = bounds.getNorthEast();
    var query_string = 
        "&order_by=" + escape( order_by_val ) +
        "&type=" + escape( type_val ) +
        "&limit=100" +
        "&minLon=" + escape( sw.lng() ) + 
        "&maxLon=" + escape( ne.lng() ) + 
        "&minLat=" + escape( sw.lat() ) + 
        "&maxLat=" + escape( ne.lat() )
    ;
    if ( document.forms[0].age )
    {
        var age = document.forms[0].age.value;
        if ( age.length )
        {
            query_string = query_string + "&age=" + escape( age );
        }
    }
    return query_string;
};

SCHOOLMAP.getSchools = function() 
{
    var query_string = SCHOOLMAP.getQueryString();
    if ( ! query_string ) return;
    SCHOOLMAP.removeSchoolMarkers();
    SCHOOLMAP.schools = new Array();
    SCHOOLMAP.active_school = false;
    var url = SCHOOLMAP.schools_url + "?" + query_string;
    SCHOOLMAP.createLinkTo( query_string );
    SCHOOLMAP.getJSON( url, SCHOOLMAP.getSchoolsCallback );
};

SCHOOLMAP.typesNoUpdateCallback = function( response ) 
{
    var types = JSON.parse( response.responseText );
    var sel = document.forms[0].type;
    var val = sel.value;
    SCHOOLMAP.removeChildren( sel );
    for ( var i = 0; i < types.length; i++ )
    {
        SCHOOLMAP.addOpt( sel, types[i] );
    }
    sel.value = val;
};

SCHOOLMAP.getSchoolsCallback = function( response ) 
{
    var json = JSON.parse( response.responseText );
    SCHOOLMAP.nschools = json.nschools;
    SCHOOLMAP.schools = json.schools;
    var query_string = SCHOOLMAP.getQueryString();
    var types_url = SCHOOLMAP.schools_url + "?" + query_string + "&types";
    SCHOOLMAP.get( types_url, SCHOOLMAP.typesNoUpdateCallback );
    SCHOOLMAP.updateSchools();
};

SCHOOLMAP.updateSchools = function()
{
    var order_by = document.forms[0].order_by.value;
    if ( order_by == "distance" )
    {
        SCHOOLMAP.calculateAllDistances( SCHOOLMAP.redrawSchools );
    }
    else
    {
        SCHOOLMAP.redrawSchools( SCHOOLMAP.calculateAllDistances );
    }
};

SCHOOLMAP.redrawSchools = function( callback ) 
{
    try {
        var body = document.getElementsByTagName( "body" );
        body[0].style.cursor = "auto";
        var listDiv = document.getElementById( "list" );
        var markers = [];
        for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
        {
            var school = SCHOOLMAP.schools[i];
            school.no = i+1;
            if ( ! school.type ) school.type = "unknown";
            var type = SCHOOLMAP.types[school.type];
            if ( ! type )
            {
                console.error( "no type for " + school.name + "(" + school.type + ")" );
                continue;
            }
            var colour = type.colour;
            var icon = SCHOOLMAP.createIcon( colour, school.no );
            if ( school.marker )
            {
                school.marker.setImage( icon.image );
            }
            else
            {
                var marker = SCHOOLMAP.createMarker( school, icon );
                markers.push( marker );
            }
        }
        if ( markers.length )
        {
            SCHOOLMAP.mgr.addMarkers( markers, 0, 17 );
            SCHOOLMAP.mgr.refresh();
        }
        SCHOOLMAP.removeChildren( listDiv );
        if ( SCHOOLMAP.schools.length )
        {
            listDiv.appendChild( SCHOOLMAP.createListTable() );
        }
        var b = document.createElement( "B" );
        b.appendChild( document.createTextNode( SCHOOLMAP.schools.length + " / " + SCHOOLMAP.nschools + " schools" ) );
        listDiv.appendChild( b );
        if ( callback ) callback();
    } catch( e ) { console.error( e.message ) }
};

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
    if ( 0 && ! SCHOOLMAP.calculatingDistances )
    {
        SCHOOLMAP.setDistanceListeners( 
            function( meters ) {
                var m = SCHOOLMAP.convertMeters( meters );
                window.status = "distance to " + school.name + " = " + m;
            }
        );
        SCHOOLMAP.gdir.load( 
            school.directions_text,
            { preserveViewport:true, travelMode:"walking" }
        );
    }
    SCHOOLMAP.active_school = school;
    window.status = school.name;
}

SCHOOLMAP.deActivateSchool = function( school ) 
{
    if ( ! school ) return;
    SCHOOLMAP.changeLinksColour( school, "4444ff" );
    var type = SCHOOLMAP.types[school.type];
    if ( ! type )
    {
        console.error( "no type for " + school.name );
        return;
    }
    SCHOOLMAP.changeMarkerColour( school, type.colour );
    if ( ! SCHOOLMAP.calculatingDistances ) SCHOOLMAP.gdir.clear();
    SCHOOLMAP.active_school = false;
}

SCHOOLMAP.setParams = function() 
{
    for ( var param in SCHOOLMAP.params )
    {
        SCHOOLMAP.setParam( param );
    }
    if ( SCHOOLMAP.params.centerLng && SCHOOLMAP.params.centerLat )
    {
        SCHOOLMAP.params.center = new GLatLng( SCHOOLMAP.params.centerLat, SCHOOLMAP.params.centerLng );
    }
    if (
        ! SCHOOLMAP.params.zoom &&
        SCHOOLMAP.params.minLon &&
        SCHOOLMAP.params.minLat &&
        SCHOOLMAP.params.maxLon &&
        SCHOOLMAP.params.maxLat
    )
    {
        var sw = new GLatLng( SCHOOLMAP.params.minLon, SCHOOLMAP.params.minLat );
        var ne = new GLatLng( SCHOOLMAP.params.maxLon, SCHOOLMAP.params.maxLat );
        var bounds = new GLatLngBounds( sw, ne );
        SCHOOLMAP.params.zoom = SCHOOLMAP.map.getBoundsZoomLevel( bounds );
    }
};

SCHOOLMAP.setParam = function( param ) 
{
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
};

SCHOOLMAP.sortByDistance = function( a, b ) 
{
    return a.meters - b.meters;
};

SCHOOLMAP.resetDistances = function()
{
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        SCHOOLMAP.schools[i].meters = 0;
    }
};

SCHOOLMAP.calculateAllDistances = function( callback ) 
{
    console.log( "calculate distances" );
    SCHOOLMAP.calculatingDistances = true;
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        if ( ! SCHOOLMAP.schools[i].meters ) 
        {
            SCHOOLMAP.calculateDistance( 
                SCHOOLMAP.schools[i], 
                function() { SCHOOLMAP.calculateAllDistances( callback ) }
            );
            return;
        }
    }
    SCHOOLMAP.gdir.clear();
    var order_by = document.forms[0].order_by.value;
    if ( order_by == "distance" )
    {
        console.log( "re-order by distance" );
        SCHOOLMAP.schools = SCHOOLMAP.schools.sort( SCHOOLMAP.sortByDistance );
    }
    SCHOOLMAP.calculatingDistances = false;
    if ( callback ) callback();
}

SCHOOLMAP.setText = function( e, t ) 
{
    SCHOOLMAP.removeChildren( e );
    e.appendChild( document.createTextNode( t ) );
};

SCHOOLMAP.removeDistanceListeners = function( ) 
{
    if ( SCHOOLMAP.handle_error )
    {
        GEvent.removeListener( SCHOOLMAP.handle_error );
        SCHOOLMAP.handle_error = false;
    }
    if ( SCHOOLMAP.handle_load )
    {
        GEvent.removeListener( SCHOOLMAP.handle_load );
        SCHOOLMAP.handle_load = false;
    }
};

SCHOOLMAP.convertMeters = function( m ) 
{
    if ( m < 1000 ) return m + " m";
    var km = m / 1000;
    return km + " km";
}

SCHOOLMAP.setDistanceListeners = function( successcallback, allcallback ) 
{
    SCHOOLMAP.handle_load = GEvent.addListener(
        SCHOOLMAP.gdir, 
        "load", 
        function( obj ) {
            try {
                var nroutes = obj.getNumRoutes();
                if ( nroutes >= 0 )
                {
                    var route = obj.getRoute( 0 );
                    var distance = route.getDistance();
                    if ( typeof( distance.meters ) == "number" )
                    {
                        console.log( "distance " + distance.meters );
                        successcallback( distance.meters );
                    }
                }
            } catch( e ) {
                console.error( "route calculation failed: " + e.message );
            }
            SCHOOLMAP.removeDistanceListeners();
            console.log( allcallback );
            if ( allcallback ) allcallback();
        }
    );
    SCHOOLMAP.handle_error = GEvent.addListener( 
        SCHOOLMAP.gdir, 
        "error", 
        function( obj ) {
            console.error( "error: " + obj.getStatus().code );
            SCHOOLMAP.removeDistanceListeners();
            // SCHOOLMAP.gdir.clear();
            if ( allcallback ) allcallback();
        }
    );
};

SCHOOLMAP.calculateDistance = function( school, callback ) 
{
    if ( ! SCHOOLMAP.place ) return;
    var from = school.lat + "," + school.lon;
    var point = SCHOOLMAP.place.point;
    var to = point.lat() + "," + point.lng();
    // var to = SCHOOLMAP.place.address;
    school.directions_text = "from " + from + " to " + to;
    console.log( "calculate " + school.directions_text );
    try {
        SCHOOLMAP.setDistanceListeners( 
            function( meters ) {
                console.log( "meters: " + meters );
                school.meters = meters;
                if ( school.distance_td ) 
                {
                    var m = SCHOOLMAP.convertMeters( school.meters );
                    console.log( "update td: " + m );
                    SCHOOLMAP.removeChildren( school.distance_td );
                    school.distance_td.appendChild( document.createTextNode( m ) );
                }
            },
            callback 
        );
        SCHOOLMAP.gdir.load( 
            school.directions_text,
            { preserveViewport:true, travelMode:"walking" }
        );
    } catch( e ) {
        console.error( e.message );
        return;
    }
};

SCHOOLMAP.createInfoWindow = function( school )
{
    var div = document.createElement( "DIV" );
    div.className = "infoWindow";
    var h2 = document.createElement( "H2" );
    h2.appendChild( document.createTextNode( school.name ) );
    div.appendChild( h2 );
    var p = document.createElement( "P" );
    var address = school.address.split( "," );
    for ( var i = 0; i < address.length; i++ )
    {
        p.appendChild( document.createTextNode( address[i] ) );
        p.appendChild( document.createElement( "BR" ) );
    }
    div.appendChild( p );
    if ( school.HEAD_LAST )
    {
        var head = school.HEAD_TITLE + " " + school.HEAD_FIRST + " " + school.HEAD_LAST;
        p = document.createElement( "P" );
        p.appendChild( 
            document.createTextNode( "Head: " + head )
        );
        if ( school.HEAD_HONOUR )
        {
            p.appendChild( document.createElement( "BR" ) );
            p.appendChild( document.createTextNode( school.HEAD_HONOUR ) );
        }
        div.appendChild( p );
    }
    if ( school.ofsted_url ) 
    {
        p = document.createElement( "P" );
        var a = document.createElement( "A" );
        a.href = school.ofsted_url;
        a.appendChild( document.createTextNode( "Ofsted report" ) );
        p.appendChild( a );
        div.appendChild( p );
    }
    return div;
};

SCHOOLMAP.createIcon = function( colour, no )
{
    var icon = MapIconMaker.createLabeledMarkerIcon(
        { primaryColor: "#" + colour, label: "" + no }
    );
    icon.colour = colour;
    return icon;
};

SCHOOLMAP.createMarker = function( school, icon ) {
    try {
        var point = new GLatLng( school.lat, school.lon );
        var marker = new GMarker( point, { "icon":icon } );
        // SCHOOLMAP.map.addOverlay( marker );
        GEvent.addListener( marker, "mouseout", function() { SCHOOLMAP.deActivateSchool( school ) } );
        GEvent.addListener( marker, "mouseover", function() { SCHOOLMAP.activateSchool( school ) } );
        GEvent.addListener( 
            marker, 
            "infowindowclose", 
            function() {
                console.log( "info window close" );
                if ( SCHOOLMAP.current_center )
                {
                    SCHOOLMAP.map.setCenter( SCHOOLMAP.current_center );
                }
                SCHOOLMAP.setMapListeners();
            }
        );
        GEvent.addListener( 
            marker, 
            "infowindowopen", 
            function() {
                console.log( "info window open" );
                SCHOOLMAP.removeMapListeners();
            }
        );
        GEvent.addListener( 
            marker, 
            "click", 
            function() {
                console.log( "click on " + marker );
                if ( ! SCHOOLMAP.current_center ) SCHOOLMAP.current_center = SCHOOLMAP.map.getCenter();
            } 
        );
        var div = SCHOOLMAP.createInfoWindow( school );
        marker.bindInfoWindow( div );
        school.marker = marker;
        return marker;
    }
    catch(e) { console.error( e.message ) }
}

SCHOOLMAP.initTableHead = function( tr, result_types ) 
{
    var ths = new Array();
    SCHOOLMAP.createHeadCell( tr, "no" );
    SCHOOLMAP.createHeadCell( tr, "name", "Name of school", 1 );
    SCHOOLMAP.createHeadCell( tr, "stage", "School stage" );
    SCHOOLMAP.createHeadCell( tr, "type", "Type of school" );
    SCHOOLMAP.createHeadCell( tr, "ofsted report", "Link to Ofsted report" );
    for ( var i = 0; i < result_types.length; i++ )
    {
        var result_type = result_types[i];
        var description = SCHOOLMAP.result_types[result_type];
        SCHOOLMAP.createHeadCell( tr, description, "average score" );
    }
    if ( SCHOOLMAP.place )
    {
        SCHOOLMAP.createHeadCell( tr, "distance", "Distance from " + SCHOOLMAP.place.address );
    }
};

SCHOOLMAP.getQueryVariables = function() {
    var query = window.location.search.substring( 1 );
    var vars = query.split( "&" );
    for ( var i = 0; i < vars.length; i++ ) 
    {
        var pair = vars[i].split( "=" );
        var key = unescape( pair[0] );
        var val = unescape( pair[1] );
        val = val.replace( /\+/g, " " );
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

SCHOOLMAP.initMap = function() 
{
    SCHOOLMAP.ignoreConsoleErrors();
    SCHOOLMAP.getQueryVariables();
    SCHOOLMAP.setParams();
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

    // SCHOOLMAP.addLayerControls();
    var center = SCHOOLMAP.params.center || SCHOOLMAP.default_center;
    console.log( "center = " + center );
    var zoom = parseInt( SCHOOLMAP.params.zoom ) || SCHOOLMAP.default_zoom;
    console.log( "zoom = " + zoom );
    SCHOOLMAP.map.setCenter( center, zoom );
    SCHOOLMAP.mgr = new MarkerManager( SCHOOLMAP.map );
    SCHOOLMAP.gdir = new GDirections( SCHOOLMAP.map );
    SCHOOLMAP.geocoder = new GClientGeocoder();
    SCHOOLMAP.geocoder.setBaseCountryCode( "uk" );
    GEvent.addListener( 
        SCHOOLMAP.map, 
        "moveend", 
        function() {
            var center = SCHOOLMAP.map.getCenter();
            var centerLat = document.getElementById( "centerLat" );
            centerLat.value = center.lat();
            var centerLng = document.getElementById( "centerLng" );
            centerLng.value = center.lng();
        }
    );
    GEvent.addListener( 
        SCHOOLMAP.map, 
        "zoomend", 
        function() {
            var zoom = SCHOOLMAP.map.getZoom();
            var zoomInput = document.getElementById( "zoom" );
            zoomInput.value = zoom;
        }
    );
    SCHOOLMAP.setMapListeners();
    if ( SCHOOLMAP.params.address )
    {
        SCHOOLMAP.findAddress( 
            SCHOOLMAP.params.address, 
            function( point ) {
                SCHOOLMAP.removeMapListeners();
                SCHOOLMAP.map.setCenter( point );
                SCHOOLMAP.map.setZoom( zoom );
                SCHOOLMAP.setMapListeners();
                SCHOOLMAP.getSchools();
            }
        );
    }
    else
    {
        SCHOOLMAP.map.setCenter( center, zoom );
    }
};

SCHOOLMAP.addLayerControls = function() {
    var mapContainer = document.getElementById( "mapContainer" );
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
    mapContainer.appendChild( fieldset );
};

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
    if ( opts.nowrap ) td.style.whiteSpace = "nowrap";
    return td;
}

SCHOOLMAP.getResultTypes = function()
{
    var result_types_hash = {};
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        for ( var result_type in SCHOOLMAP.result_types )
        {
            var ave = "average_" + result_type;
            if ( school[ave] && school[ave] != 0 )
            {
                result_types_hash[result_type] = true;
            }
        }
    }
    var result_types_array = [];
    var sel = document.forms[0].order_by;
    var val = sel.value;
    SCHOOLMAP.removeChildren( sel );
    sel.value = val;
    SCHOOLMAP.addOpt( sel, { val: "", str: "-" } );
    SCHOOLMAP.addOpt( sel, { val: "distance", str: "Distance" } );
    for ( var result_type in result_types_hash )
    {
        result_types_array.push( result_type );
        var description = SCHOOLMAP.result_types[result_type];
        SCHOOLMAP.addOpt( sel, { val: result_type, str: description } );
    }
    return result_types_array;
};

SCHOOLMAP.createListRow = function( no, school, result_types ) 
{
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
    if ( school.ofsted_url ) 
    {
        var url = SCHOOLMAP.school_url + "?table=ofsted&id=" + school.ofsted_id;
        tr.appendChild( SCHOOLMAP.createListTd( { "text":"yes", "url":url, "school":school } ) );
    }
    else
    {
        tr.appendChild( SCHOOLMAP.createListTd( { text:"no" } ) );
    }
    for ( var i = 0; i <  result_types.length; i++ )
    {
        var result_type = result_types[i];
        var ave = "average_" + result_type;
        if ( school[ave] && school[ave] != 0 )
        {
            var val = school[ave];
            var url = SCHOOLMAP.school_url + "?table=dcsf&type=" + result_type + "&id=" + school.dcsf_id;
            var td = SCHOOLMAP.createListTd( { "text":val, "url":url, "school":school } );
        }
        else
        {
            var td = SCHOOLMAP.createListTd( { "text":"-" } );
        }
        tr.appendChild( td );
    }
    if ( SCHOOLMAP.place )
    {
        var text = "-";
        if ( school.meters ) text = SCHOOLMAP.convertMeters( school.meters );
        school.distance_td = SCHOOLMAP.createListTd( { "text":text } );
        tr.appendChild( school.distance_td );
    }
    return tr;
}

SCHOOLMAP.createHeadCell = function( tr, name, title ) 
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
    SCHOOLMAP.setText( a, name );
};

SCHOOLMAP.createListTable = function() 
{
    var table = document.createElement( "TABLE" );
    var tbody = document.createElement( "TBODY" );
    table.appendChild( tbody );
    var tr = document.createElement( "TR" );
    tbody.appendChild( tr );
    result_types = SCHOOLMAP.getResultTypes();
    SCHOOLMAP.initTableHead( tr, result_types );
    tbody.appendChild( tr );
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        var tr = SCHOOLMAP.createListRow( i, school, result_types );
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
};

SCHOOLMAP.changeMarkerColour = function( school, colour ) 
{
    var marker = school.marker;
    if ( ! marker ) return;
    var icon = SCHOOLMAP.createIcon( colour, school.no );
    icon.colour = colour;
    marker.setImage( icon.image );
};

SCHOOLMAP.changeLinksColour = function( school, color ) 
{
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
};

SCHOOLMAP.addOpt = function( sel, opts ) 
{
    var opt = new Option( opts.str, opts.val );
    if ( opts.isSel ) opt.selected = opts.isSel;
    sel.options[sel.options.length] = opt;
    return opt;
};
