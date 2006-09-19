var markers = new Array();
var n4=(document.layers);
var n6=(document.getElementById&&!document.all);
var ie=(document.all);
var o6=(navigator.appName.indexOf("Opera") != -1);
var safari=(navigator.userAgent.indexOf("Safari") != -1);

var curr_marker = 0;

function getFirstMarker()
{
    curr_marker = 0;
    return markers[0];
}

function getNextMarker()
{
    if ( ++curr_marker == markers.length )
    {
        curr_marker = 0;
        return false;
    }
    return markers[curr_marker];
}

function removeMarkers()
{
    var marker = getFirstMarker();
    while ( marker )
    {
        marker.map.removeOverlay( marker );
        marker = getNextMarker();
    }
    markers = new Array();
}

function GxMarker( a, b, map )
{
    this.inheritFrom = GMarker;
    this.inheritFrom( a, b );
    markers.push( this );
    this.map = map;
}

GxMarker.prototype = new GMarker;

GxMarker.prototype.initialize = function( a ) 
{
    GMarker.prototype.initialize.call(this, a);
    var c = this.iconImage;
    // Use the image map for Firefox/Mozilla browsers
    if ( n6 && this.icon.imageMap && !safari) {
        c = this.imageMap;
    }
    // If we have a transparent icon, use that instead of the main image
    else if ( this.transparentIcon && typeof this.transparentIcon != "undefined" ) {
        c = this.transparentIcon;
    }
    // Setup the mouse over/out events
    GEvent.bindDom( c, "mouseover", this, this._onMouseOver );
    GEvent.bindDom( c, "mouseout", this, this._onMouseOut );
    GEvent.bindDom( c, "click", this, this._onClick );
}

GxMarker.prototype._onClick = function() 
{
    GEvent.trigger( this, "click" );
    if ( this.onClick ) this.onClick();
};

GxMarker.prototype._onMouseOver = function() 
{
    GEvent.trigger( this, "mouseover" );
    if ( this.onMouseOver ) this.onMouseOver();
};

GxMarker.prototype._onMouseOut = function() 
{
    GEvent.trigger( this, "mouseout" );
    if ( this.onMouseOut ) this.onMouseOut();
};

function makeInterface(a) 
{
    var b = a || window;
    b.GxMarker = GxMarker;
}

makeInterface();
