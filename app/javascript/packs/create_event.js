window.addEventListener('DOMContentLoaded', (event) => {
  $('.tool-tip').tooltip();
  $('.when-radio').change(toggleDateSelectors);
});

function toggleDateSelectors() {
  if($('#time-future').prop('checked')) {
    $('#future-choice').collapse('show');
  } else {
    $('#future-choice').collapse('hide');
  }
}
