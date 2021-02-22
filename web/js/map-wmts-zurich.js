/*
 * Maps for FMZ using Zurich council's WMTS tile server
 */

// From 'fullExtent' from http://www.gis.stadt-zuerich.ch/maps/rest/services/tiled95/LuftbildHybrid/MapServer?f=pjson
fixmystreet.maps.layer_bounds = new OpenLayers.Bounds(
    2672499, // W
    1238999, // S
    2689999, // E
    1256999); // N

fixmystreet.maps.matrix_ids = [
  {
    "scaleDenominator": 241904.761905,
    "identifier": "0",
  },
  {
    "scaleDenominator": 120952.380952,
    "identifier": "1",
  },
  {
    "scaleDenominator": 60476.1904761,
    "identifier": "2",
  },
  {
    "scaleDenominator": 30238.0952382,
    "identifier": "3",
  },
  {
    "scaleDenominator": 15119.0476189,
    "identifier": "4",
  },
  {
    "scaleDenominator": 7559.52380964,
    "identifier": "5",
  },
  {
    "scaleDenominator": 3779.76190464,
    "identifier": "6",
  },
  {
    "scaleDenominator": 1889.8809525,
    "identifier": "7",
  },
  {
    "scaleDenominator": 944.940476071,
    "identifier": "8",
  },
  {
    "scaleDenominator": 472.470238214,
    "identifier": "9",
  },
  {
    "scaleDenominator": 236.235118929,
    "identifier": "10",
  }
];

(function() {
    function pin_dragged(lonlat) {
        document.getElementById('fixmystreet.latitude').value = lonlat.y.toFixed(6);
        document.getElementById('fixmystreet.longitude').value = lonlat.x.toFixed(6);
    }

    $(function(){
        fixmystreet.maps.base_layer_aerial = true;
        $('.map-layer-toggle').click(fixmystreet.maps.toggle_base);

        /* Admin dragging of pin */
        if (fixmystreet.page == 'admin') {
            if ($.browser.msie) {
                $(window).load(function() { fixmystreet.maps.admin_drag(pin_dragged, true); });
            } else {
                fixmystreet.maps.admin_drag(pin_dragged, true);
            }
        }
    });

})();

/*
 * maps.config() is called on dom ready in map-OpenLayers.js
 * to setup the way the map should operate.
 */
fixmystreet.maps.config = function() {
    // This stuff is copied from js/map-bing-ol.js

    fixmystreet.controls = [
        new OpenLayers.Control.ArgParserFMS(),
        new OpenLayers.Control.Navigation()
    ];
    if ( fixmystreet.page != 'report' || !$('html').hasClass('mobile') ) {
        fixmystreet.controls.push( new OpenLayers.Control.PanZoomFMS({id: 'fms_pan_zoom' }) );
    }

    /* Linking back to around from report page, keeping track of map moves */
    if ( fixmystreet.page == 'report' ) {
        fixmystreet.controls.push( new OpenLayers.Control.PermalinkFMS('key-tool-problems-nearby', '/around') );
    }

    this.setup_wmts_base_map();

    fixmystreet.area_format = { fillColor: 'none', strokeWidth: 4, strokeColor: 'black' };
};

fixmystreet.maps.zoom_for_normal_size = 6;
fixmystreet.maps.zoom_for_small_size = 3;
