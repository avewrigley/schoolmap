function MoreControl() {}
MoreControl.prototype = new GControl();
MoreControl.prototype.initialize = function( map ) {
    var container = document.createElement( "div" );
    container.style.border = "2px solid black";
    container.style.fontSize = "12px";
    container.style.fontFamily = "Arial, sans-serif";
    container.style.width="80px";
    container.style.backgroundColor = "#ffffff";
    container.style.textAlign = "center";
    container.innerHTML = "More...";
  
    map.getContainer().appendChild( container );
    
    GEvent.addDomListener( container, "mouseover", function() {
        map.addControl( layerControl );
    } );
    return container;
}
MoreControl.prototype.getDefaultPosition = function() {
    return new GControlPosition( G_ANCHOR_TOP_RIGHT, new GSize( 210, 7 ) );
}

function LayerControl(opts) {
    this.opts = opts;
}

LayerControl.prototype = new GControl();
LayerControl.prototype.initialize = function( map ) {
    var container = document.createElement( "div" );
    container.style.border = "2px solid black";
    container.style.fontSize = "12px";
    container.style.fontFamily = "Arial, sans-serif";
    container.style.width="80px";
    container.style.backgroundColor = "#ffffff";
    container.innerHTML = '<center><b>More...<\/b><\/center>';
    for ( var i = 0; i < this.opts.length; i++ ) 
    {
        var c;
        if ( layers[i].Visible ) c = 'checked';
        else c = '';
        container.innerHTML += '<input type="checkbox" onclick="toggleLayer('+i+')" ' +c+ ' /> '+this.opts[i]+'<br>';
    }
    map.getContainer().appendChild( container );

    //GEvent.addDomListener(container, "mouseout", function() {
    //  map.removeControl(layerControl);
    //});

    setTimeout( "map.removeControl(layerControl)", 5000 );
    return container;
}

LayerControl.prototype.getDefaultPosition = function() {
    return new GControlPosition(G_ANCHOR_TOP_RIGHT, new GSize(210, 7));
}

function toggleLayer(i) {
    if (layers[i].Visible) {
        layers[i].hide();
    } else {
        if(layers[i].Added) {
            layers[i].show();
        } else {
            map.addOverlay(layers[i]);
            layers[i].Added = true;
        }
    }
    layers[i].Visible = !layers[i].Visible;
}

var layers = [];      
layers[0] = new GLayer("org.wikipedia.en");
layers[0].Visible = false;
layers[0].Added = false;
      
layers[1] = new GLayer("org.wikipedia.de");
layers[1].Visible = false;
layers[1].Added = false;
      
layers[2] = new GLayer("com.panoramio.all");
layers[2].Visible = false;
layers[2].Added = false;

layers[3] = new GLayer("com.panoramio.popular");
map.addOverlay(layers[3]);  // This one open by default
layers[3].Visible = true;
layers[3].Added = true;

// === Create the layerControl, but don't addControl() it ===
// = Pass it an array of names for the checkboxes =
var layerControl = new LayerControl(["Wiki", "Wike DE", "Photos", "Popular"]);
