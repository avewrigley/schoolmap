function GxMarker( a, b )
{
    this.inheritFrom = GMarker;
    this.inheritFrom( a, b );
    markers.push( this );
}

GxMarker.prototype = new GMarker;

GxMarker.prototype.initialize = function( a ) 
{
    GMarker.prototype.initialize.call(this, a);
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
