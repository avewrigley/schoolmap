(function($) {
    $.fn.autoResize = function(options) {
        this.filter('input').each(function() {
            var $this       = $(this)
            console.log( $this );
            var shadow = $('<div></div>').css({
                position:   'absolute',
                top:        -10000,
                left:       -10000,
                width:      'auto',
                fontSize:   $this.css('fontSize'),
                fontFamily: $this.css('fontFamily'),
            }).appendTo(document.body);
            
            var update = function() 
            {
                shadow.text( this.value );
                $(this).css( 'width', shadow.width() );
            
            };
            $(this).change(update).keyup(update).keydown(update);
            update.apply(this);
        });
        return this;
    }
})(jQuery);
