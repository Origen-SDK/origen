jQuery(function($) {
  $('.navbar').singlePageNav({
    filter: ':not(.external)',
    offset: 60,
    currentClass: 'active'
  });
});
