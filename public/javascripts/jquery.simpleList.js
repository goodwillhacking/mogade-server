(function($) 
{
  var defaults = {viewUrl: null};
  $.fn.simpleList = function(options) 
  {        
    var opts = $.extend({}, defaults, options);
    return this.each(function() 
    {
      if (this.simpleList) { return false; }
      var $container = $(this)
      var $table = $container.children('table')
      var $tbody = $table.find('tbody');
      var $empty = $container.children('h3')
      var $count = $('#' + this.id + '_count');
      var self =
      {   
        initialize: function()
        {
          self.setInitialState();
          if (opts.viewUrl) 
          {
            $tbody.delegate('tr[data-id]', 'click', self.rowClicked)
                .delegate('tr[data-id]', 'mouseover', self.rowOver)
                .delegate('tr[data-id]', 'mouseout', self.rowOut);
          }
        },
        rowClicked: function() { top.location = opts.viewUrl + '/' + $(this).data('id'); },
        rowOver: function() { $(this).addClass('over'); },
        rowOut: function() { $(this).removeClass('over'); },
        setInitialState: function()
        {
          var rows = $tbody.children('tr').length;
          if (rows == 0)
          {
            $empty.show();
            $count.hide();
            $table.find('thead').hide();
          }
          else
          {
            $count.find('.count').text(rows);
            $empty.hide();
            $count.show();
            $table.find('thead').show();           
          }
        }
      };
      this.simpleList = self;
      self.initialize();      
    });
  };
})(jQuery);