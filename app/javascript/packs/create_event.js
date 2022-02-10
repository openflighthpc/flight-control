window.addEventListener('DOMContentLoaded', (event) => {
  $('.tool-tip').tooltip();
  $('.when-radio').change(toggleDateSelectors);
  $('#wizard-next-button').click(showNextSection);
  $('#wizard-back-button').click(showPreviousSection);
});

function toggleDateSelectors() {
  if($('#time-future').prop('checked')) {
    $('#future-choice').collapse('show');
  } else {
    $('#future-choice').collapse('hide');
  }
}

// Once done, try to merge show next and show previous
function showNextSection() {
  let nextButton = $('#wizard-next-button');
  let current = nextButton.data('current');
  let backButton = $('#wizard-back-button');
  if(current === "counts") {
    $('#wizard-choose-counts').hide();
    $('#wizard-choose-when').show();
    backButton.data('previous', 'counts')
    backButton.css('visibility', 'visible');
    nextButton.data('current', 'when');
  }
}

function showPreviousSection() {
  let backButton = $('#wizard-back-button');
  let previous = backButton.data('previous');
  if(previous === "counts") {
    $('#wizard-choose-when').hide();
    backButton.css('visibility', 'hidden');;
    $('#wizard-choose-counts').show();
    backButton.data('previous', "");
    $('#wizard-next-button').data('current', 'counts');
  }
}
