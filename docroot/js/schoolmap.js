$(document).ready(
    function()
    {
        $("#schoolmap_form").validate( {
            rules: {
                limit: {
                    required: true,
                    min: 0,
                    max: 100
                }
            }
        } );
    }
);

var SCHOOLMAP = {
    default_zoom:12,
    min_zoom:11,
    default_center:new google.maps.LatLng( 53.82659674299412, -1.86767578125 ),
    schools_url:"schools",
    schools:[],
    params:{},
    nschools:0,
    order_bys:{ 
        "primary": { "description": "Key stage 2" },
        "ks3": { "description": "Key stage 3" },
        "secondary": { "description": "GCSE", "tooltip": "Average Attainment 8 score per pupil" },
        "post16": { "description": "GCE and VCE" },
    },
    request:false,
    curtags:[ "body", "a", "input", "select", "div" ],
    default_phase_colour: "blue",
    phase_colour:{
        "Nursery": "green",
        "Primary": "purple",
        "Secondary": "red",
        "16 Plus": "orange"
    },
    handle_zoom:false,
    handle_move:false,
    addressMarker:false
};

SCHOOLMAP.updateAddress = function( point, address )
{
    SCHOOLMAP.point = point;
    SCHOOLMAP.createAddressMarker();
    var input = document.getElementById( "address" );
    SCHOOLMAP.address = input.value = address;
    var span = document.getElementById( "coords" );
    SCHOOLMAP.setText( span, "( lat: " + point.lat() + ", lng: " + point.lng() + ")" );
};

SCHOOLMAP.findAddress = function( query, callback ) 
{
    var apikey = 'fe2b2d1377b646c4931bd791051f91d9';
    var api_url = 'https://api.opencagedata.com/geocode/v1/json';
    var request_url = api_url + '?' + 'key=' + apikey + '&q=' + encodeURIComponent(query);
    console.log( request_url );
    var request = new XMLHttpRequest();
    request.open('GET', request_url, true);
    request.onload = function() {
        if (request.status == 200) { 
            var text = request.responseText;
            var data = JSON.parse(text);
            var result = data.results[0];
            if ( result ) 
            {    
                var lat = result.geometry.lat;
                var lng = result.geometry.lng;
                var title = result.formatted;
                var point = new google.maps.LatLng( lat, lng );
                console.log( result );
                console.log( title );
                SCHOOLMAP.updateAddress( point, query );
                callback( point );
            }
        }
    };
    request.send();
}

SCHOOLMAP.setMapListeners = function() 
{
    SCHOOLMAP.handle_zoom = SCHOOLMAP.map.addListener( 
        "zoom_changed", 
        function() { 
            var zoom = SCHOOLMAP.map.getZoom();
            console.log( "zoom = " + zoom );
            console.log( "min zoom = " + SCHOOLMAP.min_zoom );
            if ( zoom >= SCHOOLMAP.min_zoom )
            {
                SCHOOLMAP.getSchools(); 
            }
        }
    );
    SCHOOLMAP.handle_move = SCHOOLMAP.map.addListener( 
        "dragend", 
        function() {
            var zoom = SCHOOLMAP.map.getZoom();
            console.log( "zoom = " + zoom );
            if ( zoom >= SCHOOLMAP.default_zoom )
            {
                SCHOOLMAP.getSchools(); 
            }
        }
    );
};

SCHOOLMAP.removeMapListeners = function() 
{
    if ( SCHOOLMAP.handle_zoom )
    {
        google.maps.event.removeListener( SCHOOLMAP.handle_zoom );
        SCHOOLMAP.handle_zoom = false;
    }
    if ( SCHOOLMAP.handle_move )
    {
        google.maps.event.removeListener( SCHOOLMAP.handle_move );
        SCHOOLMAP.handle_move = false;
    }
}

SCHOOLMAP.createAddressMarker = function() 
{
    if ( ! SCHOOLMAP.point ) return;
    if ( SCHOOLMAP.addressMarker ) return;
    SCHOOLMAP.addressMarker = new google.maps.Marker({
        position: SCHOOLMAP.point,
        map: SCHOOLMAP.map,
        draggable: true,
        icon: '/markers/image.png'
    });

    SCHOOLMAP.addressMarker.addListener( 
        "dragend", 
        function( event ) { 
            SCHOOLMAP.findAddress( 
                event.latLng.lat() + "," + event.latLng.lng(),
                function( point ) {
                    SCHOOLMAP.address_changed = true;
                    SCHOOLMAP.getSchools(); 
                }
            );
        }
    );
};

SCHOOLMAP.removeSchoolMarkers = function() 
{
    var listDiv = document.getElementById( "list" );
    SCHOOLMAP.removeChildren( listDiv );
};

SCHOOLMAP.removeChildren = function( parent ) 
{
    try {
        while ( parent.childNodes.length ) parent.removeChild( parent.childNodes[0] );
    }
    catch(e) { console.error( e.message ) }
}

SCHOOLMAP.createLinkTo = function( query_string ) 
{
    var url = document.URL;
    url = url.replace( /\?.*$/, "" );
    var url = url + "?" + query_string;
    var link1 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=xml";
    link1.href = url;
    link1.target = "_blank";
    SCHOOLMAP.setText( link1, "XML" );
    var link2 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=georss";
    link2.href = url;
    link2.target = "_blank";
    SCHOOLMAP.setText( link2, "GeoRSS" );
    var link3 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=kml";
    link3.href = url;
    link3.target = "_blank";
    SCHOOLMAP.setText( link3, "KML" );
    var link4 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=json";
    link4.href = url;
    link4.target = "_blank";
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
};

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

SCHOOLMAP.get = function( url, callback ) 
{
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

SCHOOLMAP.createXMLHttpRequest = function() 
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

SCHOOLMAP.setCursor = function( state ) 
{
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

SCHOOLMAP.getQueryString = function() 
{
    var bounds = SCHOOLMAP.map.getBounds();
    var sw = bounds.getSouthWest();
    var ne = bounds.getNorthEast();
    var query_string = 
        "&minLon=" + escape( sw.lng() ) + 
        "&maxLon=" + escape( ne.lng() ) + 
        "&minLat=" + escape( sw.lat() ) + 
        "&maxLat=" + escape( ne.lat() )
    ;
    if ( SCHOOLMAP.point ) 
    {
        query_string = query_string + "&lon=" + escape( SCHOOLMAP.point.lng() ) + "&lat=" + escape( SCHOOLMAP.point.lat() );

    }
    var order_by = document.forms[0].order_by;
    if ( order_by ) 
    {
        var order_by_val = order_by.value;
        // if ( order_by_val == "distance" ) order_by_val = "";
        query_string = query_string + "&order_by=" + escape( order_by_val );
    }
    var phase = document.forms[0].phase;
    if ( phase ) 
    {
        var phase_val = phase.value;
        if ( phase_val == "all" ) phase_val = "";
        query_string = query_string + "&phase=" + escape( phase_val );
    }
    return query_string;
};

SCHOOLMAP.getSchools = function() 
{
    var order_by = document.forms[0].order_by;
    if ( ! order_by ) return;
    var phase = document.forms[0].phase;
    if ( ! phase ) return;
    var query_string = SCHOOLMAP.getQueryString();
    var url = SCHOOLMAP.schools_url + "?" + query_string;
    SCHOOLMAP.createLinkTo( query_string );
    console.log(url);
    SCHOOLMAP.getJSON( url, SCHOOLMAP.getSchoolsCallback );
};

SCHOOLMAP.phasesCallback = function( response ) 
{
    var phases = JSON.parse( response.responseText );
    var sel = document.forms[0].phase;
    var val = sel.value;
    SCHOOLMAP.removeChildren( sel );
    for ( var i = 0; i < phases.length; i++ )
    {
        SCHOOLMAP.addOpt( sel, { str:phases[i], val:phases[i] } );
    }
    sel.value = val;
};

SCHOOLMAP.schoolsChanged = function( schools ) 
{
    // check to see if the list of schools has changed ...
    if ( schools.length != SCHOOLMAP.schools.length ) return true;
    try {
        for ( var i = 0;i < schools.length; i++ )
        {
            if ( schools[i].URN != SCHOOLMAP.schools[i].URN ) return true;
        }
        return false;
    } catch( e ) { console.error( e.message ) }
};

SCHOOLMAP.getSchoolsCallback = function( response ) 
{
    var json = JSON.parse( response.responseText );
    if ( SCHOOLMAP.schoolsChanged( json.schools ) )
    {
        console.log( "schools changed" );
        SCHOOLMAP.removeSchoolMarkers();
        SCHOOLMAP.active_school = false;
        SCHOOLMAP.nschools = json.nschools;
        SCHOOLMAP.schools = json.schools;
        SCHOOLMAP.updateSchools();
    }
    else
    {
        console.log( "schools not changed" );
        if ( SCHOOLMAP.address_changed )
        {
            SCHOOLMAP.address_changed = false;
            SCHOOLMAP.resetDistances();
            SCHOOLMAP.updateSchools();
        }
    }
};

SCHOOLMAP.updateSchools = function()
{
    SCHOOLMAP.redrawSchools();
    SCHOOLMAP.updateList();
    if ( SCHOOLMAP.schools.length ) { SCHOOLMAP.calculateDistance( 0 ); }
};

SCHOOLMAP.redrawSchools = function() 
{
    try {
        var body = document.getElementsByTagName( "body" );
        body[0].style.cursor = "auto";
        var markers = [];
        for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
        {
            var school = SCHOOLMAP.schools[i];
            school.no = i+1;
            if ( ! school.phase ) school.phase = "unknown";
            var marker = SCHOOLMAP.createMarker( school );
            school.marker = marker;
            markers.push( marker );
        }
    } catch( e ) { console.error( e.message ) }
};

SCHOOLMAP.orderByOnChange = function()
{
    SCHOOLMAP.getSchools();
};

SCHOOLMAP.phaseOnChange = function()
{
    SCHOOLMAP.getSchools();
};

SCHOOLMAP.updateList = function()
{
        var listDiv = document.getElementById( "list" );
        SCHOOLMAP.removeChildren( listDiv );
        if ( SCHOOLMAP.schools.length )
            listDiv.appendChild( SCHOOLMAP.createListTable() );
};

SCHOOLMAP.activateSchool = function( school )
{
    var colour = SCHOOLMAP.getPhaseColour( school );
    SCHOOLMAP.changeLinksFontWeight( school, "bold" );
    SCHOOLMAP.changeMarkerIcon( school, colour + "-dot" )
    if ( SCHOOLMAP.active_school ) SCHOOLMAP.deActivateSchool( SCHOOLMAP.active_school );
    SCHOOLMAP.active_school = school;
    window.status = school.name;
}

SCHOOLMAP.getPhaseColour = function( school )
{
    return SCHOOLMAP.phase_colour[school.phase] || SCHOOLMAP.default_phase_colour;
}

SCHOOLMAP.deActivateSchool = function( school ) 
{
    if ( ! school ) return;
    var colour = SCHOOLMAP.getPhaseColour( school );
    SCHOOLMAP.changeLinksFontWeight( school, "normal" );
    SCHOOLMAP.changeMarkerIcon( school, colour );
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
        SCHOOLMAP.params.center = new google.maps.LatLng( SCHOOLMAP.params.centerLat, SCHOOLMAP.params.centerLng );
    }
    if (
        ! SCHOOLMAP.params.zoom &&
        SCHOOLMAP.params.minLon &&
        SCHOOLMAP.params.minLat &&
        SCHOOLMAP.params.maxLon &&
        SCHOOLMAP.params.maxLat
    )
    {
        var sw = new google.maps.LatLng( SCHOOLMAP.params.minLon, SCHOOLMAP.params.minLat );
        var ne = new google.maps.LatLng( SCHOOLMAP.params.maxLon, SCHOOLMAP.params.maxLat );
        var bounds = new google.maps.LatLng( sw, ne );
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

SCHOOLMAP.setText = function( e, t ) 
{
    SCHOOLMAP.removeChildren( e );
    e.appendChild( document.createTextNode( t ) );
};

SCHOOLMAP.convertMeters = function( m ) 
{
    m = Math.round( m );
    if ( m < 1000 ) return m + " m";
    var km = m / 1000;
    return km.toPrecision( 3 ) + " km";
}

SCHOOLMAP.calculateDistance = function( school_no ) 
{
    if ( ! SCHOOLMAP.point ) return;
    if ( school_no == SCHOOLMAP.schools.length )
    {
        var order_by = document.forms[0].order_by.value;
        if ( order_by == "distance" )
        {
            console.log( "sort by distance" );
            SCHOOLMAP.schools = SCHOOLMAP.schools.sort( SCHOOLMAP.sortByDistance );
            SCHOOLMAP.updateList();
        }
        return;
    }
    var school = SCHOOLMAP.schools[school_no];
    console.log("calculate distance for " + school.name );
    try {
        SCHOOLMAP.distance_service.getDistanceMatrix( {
                origins: [school.latlng],
                destinations: [SCHOOLMAP.point],
                travelMode: 'WALKING',
            }, 
            function (response, status) {
                school.meters = response.rows[0].elements[0].distance.value;
                if ( school.distance_td ) 
                {
                    var text = SCHOOLMAP.convertMeters( school.meters );
                    var a = SCHOOLMAP.createListTdContents( { "text":text, "school":school } );
                    SCHOOLMAP.removeChildren( school.distance_td );
                    school.distance_td.appendChild( a );
                }
                SCHOOLMAP.calculateDistance( school_no+1 );
            }
        );
    } catch( e ) {
        console.error( e.message );
        return;
    }
};

SCHOOLMAP.addLink = function( url, text )
{
    return '<P><A HREF="' + url + '" TARGET="_blank">' + text + "</A></P>";
};

SCHOOLMAP.createInfoWindow = function( school )
{
    var html = "<H2>" + school.name + "</H2>";
    var html = html + "<P>";
    var address = school.address.split( "," );
    for ( var i = 0; i < address.length; i++ )
    {
        html = html + address[i] + "<BR>";
    }
    var html = html + "</P>";
    if ( school.ofsted_url ) 
    {
        html = html + SCHOOLMAP.addLink( school.ofsted_url, "Ofsted report" );
    }
    return html;
    for ( var order_by in SCHOOLMAP.order_bys )
    {
        var key = order_by + "_url";
        var url = school[key];
        if ( url )
        {
            var ave = "average_" + order_by;
            var text = SCHOOLMAP.order_bys[order_by].description + " (" + school[ave] + ")";
            html = html + SCHOOLMAP.addLink( url, text );
        }
    }
    return div;
};

SCHOOLMAP.openInfoWindow = function( school ) 
{
    if ( ! school.infowindow ) {
        school.infowindow = new google.maps.InfoWindow({
            content: SCHOOLMAP.createInfoWindow( school )
        });
    }
    if ( SCHOOLMAP.current_infowindow ) {
        SCHOOLMAP.current_infowindow.close();
        if ( school.infowindow === SCHOOLMAP.current_infowindow ) {
            return;
        }
    }
    SCHOOLMAP.current_infowindow = school.infowindow;
    school.infowindow.open(SCHOOLMAP.map, school.marker);
};

SCHOOLMAP.createMarker = function( school ) 
{
    try {
        school.latlng = new google.maps.LatLng( school.lat, school.lon );
        var colour = SCHOOLMAP.getPhaseColour( school );
        icon = {
            url: "http://maps.google.com/mapfiles/ms/icons/" + colour + ".png"
        };

        var marker = new google.maps.Marker({
            position: school.latlng,
            icon: icon,
            map: SCHOOLMAP.map
        });
        marker.addListener( "mouseout", function() { SCHOOLMAP.deActivateSchool( school ) } );
        marker.addListener( "mouseover", function() { SCHOOLMAP.activateSchool( school ) } );
        marker.addListener( "click", function() { SCHOOLMAP.openInfoWindow( school ); } );
        return marker;
    }
    catch(e) { console.error( e.message ) }
}

SCHOOLMAP.initTableHead = function( tr, order_bys ) 
{
    var ths = new Array();
    SCHOOLMAP.createHeadCell( tr, "No." );
    SCHOOLMAP.createHeadCell( tr, "Name", "Name of school", 1 );
    // SCHOOLMAP.createHeadCell( tr, "stage", "School stage" );
    SCHOOLMAP.createHeadCell( tr, "Phase", "Educational phase" );
    SCHOOLMAP.createHeadCell( tr, "Type", "Type of school" );
    SCHOOLMAP.createHeadCell( tr, "Ofsted Report", "Link to Ofsted report" );
    for ( var i = 0; i < order_bys.length; i++ )
    {
        var order_by = order_bys[i];
        var description = SCHOOLMAP.order_bys[order_by].description;
        var tooltip = SCHOOLMAP.order_bys[order_by].tooltip;
        SCHOOLMAP.createHeadCell( tr, description, tooltip );
    }
    if ( SCHOOLMAP.point )
    {
        SCHOOLMAP.createHeadCell( tr, "Distance (crow flies)", "Distance from " + SCHOOLMAP.address );
        SCHOOLMAP.createHeadCell( tr, "Distance (walking)", "Distance from " + SCHOOLMAP.address );
    }
};

SCHOOLMAP.getQueryVariables = function() 
{
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

SCHOOLMAP.initMap = function() 
{
    console.log( "init map" );
    SCHOOLMAP.getQueryVariables();
    SCHOOLMAP.setParams();
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
    var center = SCHOOLMAP.params.center || SCHOOLMAP.default_center;
    var zoom = parseInt( SCHOOLMAP.params.zoom ) || SCHOOLMAP.default_zoom;
    SCHOOLMAP.map = new google.maps.Map(
        map_div,
        {
            center: center,
            zoom: zoom,
            mapTypeId: google.maps.MapTypeId.ROADMAP
        }
    );
    SCHOOLMAP.map.setCenter( center, zoom );
    SCHOOLMAP.distance_service = new google.maps.DistanceMatrixService();
    var directionsElement = document.getElementById( "directions" );
    console.log( "directions div: " + directionsElement );
    SCHOOLMAP.map.addListener( 
        "dragend", 
        function() {
            var center = SCHOOLMAP.map.getCenter();
            var centerLat = document.getElementById( "centerLat" );
            centerLat.value = center.lat();
            var centerLng = document.getElementById( "centerLng" );
            centerLng.value = center.lng();
        }
    );
    SCHOOLMAP.map.addListener( 
        "zoom_changed", 
        function() {
            var zoom = SCHOOLMAP.map.getZoom();
            var zoomInput = document.getElementById( "zoom" );
            zoomInput.value = zoom;
        }
    );
    SCHOOLMAP.setMapListeners();
    if ( SCHOOLMAP.params.address )
    {
        console.log( SCHOOLMAP.params.address );
        SCHOOLMAP.findAddress( 
            SCHOOLMAP.params.address, 
            function( point ) {
                SCHOOLMAP.removeMapListeners();
                SCHOOLMAP.map.setCenter( point );
                SCHOOLMAP.map.setZoom( zoom );
                var query_string = SCHOOLMAP.getQueryString();
                var phases_url = SCHOOLMAP.schools_url + "?" + query_string + "&phases";
                SCHOOLMAP.get( phases_url, SCHOOLMAP.phasesCallback );
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

SCHOOLMAP.createListTdContents = function( opts ) 
{
    var a = document.createElement( "A" );
    a.onclick = function() { 
        SCHOOLMAP.openInfoWindow( school );
        return false; 
    };
    a.href = "";
    var school = opts.school;
    var colour = SCHOOLMAP.getPhaseColour( school );
    a.style.color = colour;
    if ( ! school.links ) school.links = new Array();
    school.links.push( a );
    var text = "-";
    if ( opts.text && opts.text != "null" ) text = opts.text;
    a.appendChild( document.createTextNode( text ) );
    a.onmouseover = function() {
        SCHOOLMAP.activateSchool( school );
    };
    a.onmouseout = function() {
        SCHOOLMAP.deActivateSchool( school );
    };
    return a;
};

SCHOOLMAP.createListTd = function( opts ) 
{
    var td = document.createElement( "TD" );
    var a = SCHOOLMAP.createListTdContents( opts );
    td.appendChild( a );
    td.style.verticalAlign = "top";
    if ( opts.nowrap ) td.style.whiteSpace = "nowrap";
    return td;
};

SCHOOLMAP.getOrderBys = function()
{
    var order_bys_hash = {};
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        for ( var order_by in SCHOOLMAP.order_bys )
        {
            var ave = "average_" + order_by;
            if ( school[ave] && school[ave] != 0 && ! order_bys_hash[order_by] )
            {
                console.log( "add " + order_by );
                order_bys_hash[order_by] = true;
            }
        }
    }
    var order_bys_array = [];
    var sel = document.forms[0].order_by;
    var val = sel.value;
    SCHOOLMAP.removeChildren( sel );
    SCHOOLMAP.addOpt( sel, { val: "", str: "-" } );
    SCHOOLMAP.addOpt( sel, { val: "distance", str: "Distance" } );
    for ( var order_by in order_bys_hash )
    {
        order_bys_array.push( order_by );
        var description = SCHOOLMAP.order_bys[order_by].description;
        SCHOOLMAP.addOpt( sel, { val: order_by, str: description } );
    }
    sel.value = val;
    return order_bys_array;
};

SCHOOLMAP.createListRow = function( no, school, order_bys ) 
{
    var tr = document.createElement( "TR" );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":no+1, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.name, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.phase, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.type, "school":school } ) );
    if ( school.ofsted_url ) 
    {
        tr.appendChild( SCHOOLMAP.createListTd( { "text":"yes", "school":school } ) );
    }
    else
    {
        tr.appendChild( SCHOOLMAP.createListTd( { text:"no", "school":school } ) );
    }
    for ( var i = 0; i <  order_bys.length; i++ )
    {
        var order_by = order_bys[i];
        var ave = "average_" + order_by;
        if ( school[ave] && school[ave] != 0 )
        {
            var val = school[ave];
            var td = SCHOOLMAP.createListTd( { "text":val, "school":school } );
        }
        else
        {
            var td = SCHOOLMAP.createListTd( { "text":"-", "school":school } );
        }
        tr.appendChild( td );
    }
    if ( SCHOOLMAP.point )
    {
        var text = "-";
        if ( school.distance ) text = SCHOOLMAP.convertMeters( school.distance * 1000 );
        td = SCHOOLMAP.createListTd( { "text":text, "school":school } );
        tr.appendChild( td );
        text = "-";
        if ( school.meters ) text = SCHOOLMAP.convertMeters( school.meters );
        school.distance_td = SCHOOLMAP.createListTd( { "text":text, "school":school } );
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
    order_bys = SCHOOLMAP.getOrderBys();
    SCHOOLMAP.initTableHead( tr, order_bys );
    tbody.appendChild( tr );
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        var tr = SCHOOLMAP.createListRow( i, school, order_bys );
        tbody.appendChild( tr );
    }
    var ncells = tr.childNodes.length;
    if ( SCHOOLMAP.point )
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

SCHOOLMAP.changeMarkerIcon = function( school, icon ) 
{
    var marker = school.marker;
    if ( ! marker ) return;
    marker.setIcon( "http://maps.google.com/mapfiles/ms/icons/" + icon + ".png" );
};

SCHOOLMAP.changeLinksFontWeight = function( school, fontWeight ) 
{
    if ( ! school ) return;
    var links = school.links;
    if ( ! links ) 
    {
        console.log( "no links for " + school.name );
        return;
    }
    for ( var i = 0; i < links.length; i++ )
    {
        link = links[i];
        link.style.fontWeight = fontWeight;
    }
};

SCHOOLMAP.addOpt = function( sel, opts ) 
{
    var opt = new Option( opts.str, opts.val );
    if ( opts.isSel ) opt.selected = opts.isSel;
    sel.options[sel.options.length] = opt;
    return opt;
};
