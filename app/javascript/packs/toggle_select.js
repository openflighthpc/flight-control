window.addEventListener('DOMContentLoaded', (event) => {
  $('option').click(function() {
    if ($(this).data("already-selected")) {
      $(this).data("already-selected", false);
      $(this).prop('selected', false);
    } else {
      $(this).data("already-selected", true);
    }
  });
  $('select').change(function() {
    $(this).find('option').each(function() {
      if ($(this).prop('selected') === false) {
        $(this).data("already-selected", false);
      }
    });
  });
});
