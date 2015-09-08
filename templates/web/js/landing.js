//jQuery(function($) {
//  $('.navbar').singlePageNav({
//    filter: ':not(.external)',
//    offset: 60,
//    currentClass: 'active',
//    updateHash: true,
//    speed: 1000
//  });
//});

$(function() {
  $("#subscribe input").focus();

  $('#subscribe').submit(function(e) {
    e.preventDefault();    

    var email = $($(this).find("input")[0]).val();
    var data = {};

    data['email'] = email;

    $("#subscribe button").html('<i class="fa fa-spinner fa-pulse"></i>');

    $.ajax({
      type: 'POST',
      url: 'http://hub.origen-sdk.org:3000/api/subscriptions/origen_news',
      crossDomain: true,
      data: data,
      dataType: 'json',
      success: function(responseData, textStatus, jqXHR) {
        $("#subscribe form").hide();
        $("#subscribe .text-danger").hide();
        $("#subscribe .text-primary").show();
      },
      error: function(responseData, textStatus, errorThrown) {
        var msg;
        try {
          msg = "The email, "
          msg = msg + responseData.responseJSON.errors.email[0];
        }
        catch(err) {
          msg = "Sorry, something went wrong"
        }
        $("#subscribe .text-danger").show().text(msg);
      },
      complete: function(jqXHR, textStatus) {
        $("#subscribe button").html("Subscribe to updates!");
      }
    });

  });
});
