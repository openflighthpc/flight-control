window.addEventListener('DOMContentLoaded', (event) => {
  $('select').each(updateOptions);
  $('option').click(function() {
    if ($(this).data("already-selected")) {
      $(this).data("already-selected", false);
      $(this).prop('selected', false);
    } else {
      $(this).data("already-selected", true);
    }
  });
  $('select').change(updateOptions);
});

function updateOptions() {
  const resetAll = $(this).val().length > 1;
  $(this).find('option').each(function() {
    if (resetAll || $(this).prop('selected') === false) {
      $(this).data("already-selected", false);
    }
  });
}
