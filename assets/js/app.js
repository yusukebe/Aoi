$().ready(function(){

  var isEditing = true;
  $('#editor-tab ul li a').bind('click', function(){
    if($(this).parent().hasClass('pure-menu-selected')) return;
    $('#editor-tab ul li').toggleClass('pure-menu-selected');
    if(isEditing) {
      var title = $('#editor-title').val();
      var body = $('#editor-content').val();
      $('#editor').hide();
      $('#preview h2').text(title);
      $('#preview-body').html(marked(body));
      $('#preview').show();
    }else{
      $('#preview').hide();
      $('#editor').show();
    }
    isEditing = !isEditing;
  });

  $('#permalink .markdown-body').html(marked($('#permalink .markdown-body').text(), { options: {header:false} }));
  $('.pretty-date').each(function(){
    var epoch = $(this).text();
    var date = new Date(epoch * 1000);
    $(this).text(date.toLocaleString());
  });
  
});




