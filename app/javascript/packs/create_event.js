window.addEventListener('DOMContentLoaded', (event) => {
  $('.tool-tip').tooltip();
  $('.simple-node-count').change(validateCounts);
  $('.when-radio').change(toggleDateSelectors);
  $('.day-input').change(updateWeekdays);
  $('.when-radio').change(validateTimings);
  $('.scheduled-input').change(validateTimings);
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

function validateCounts(){
  let defaults = $('.default-node-count');
  let nextButton = $('#wizard-next-button');
  let changes = false;
  defaults.each(function() {
    if(!($(this).prop('selected'))) changes = true;
  });
  if(!changes) {
    nextButton.addClass('disabled');
    nextButton.prop('disabled', true);
    nextButton.prop('title', "No counts selected");
  } else {
    nextButton.removeClass('disabled');
    nextButton.prop('disabled', false);
    nextButton.prop('title', "");
  }
}

function validateTimings() {
  let nextButton = $('#wizard-next-button');
  let valid = false;
  if ($('#time-now').prop("checked")) {
    valid = true;
  } else {
    let time = $('#scheduled-time').val();
    let date = $('#scheduled-date').val();
    let weekdays = $('#weekdays').val();
    let endDate = $('#end-date').val();
    if (time === "" || date === "") {
      nextButton.prop("disabled", true);
      nextButton.prop("title", "Date and time must be specified");
      nextButton.addClass("disabled");
    } else if (weekdays != "" && endDate === "" || weekdays === "" && endDate != "") {
      nextButton.prop("disabled", true);
      nextButton.prop("title", "For repeated policy, weekdays and an end date must be selected");
      nextButton.addClass("disabled");
    } else if (endDate != "" && new Date(endDate) < new Date(date)) {
      nextButton.prop("disabled", true);
      nextButton.prop("title", "For repeated policy, end date must be after or equal to start date");
      nextButton.addClass("disabled");
    } else {
      let oneHourAhead = new Date();
      oneHourAhead.setHours(oneHourAhead.getHours() + 1);
      let fullDate = new Date(`${date} ${time}`);
      if (weekdays === "" && fullDate < oneHourAhead) {
        submitButton.prop("disabled", true);
        submitButton.prop("title", "Must be at least one hour in the future");
        submitButton.addClass("disabled");
      } else {
        valid = true;
      }
    }
  }
  if (valid) {
    nextButton.removeClass('disabled');
    nextButton.prop('disabled', false);
    nextButton.prop('title', '');
  }
}

function updateWeekdays() {
  let any = false;
  let weekdays = [];
  $('.day-input').each(function() {
    if($(this).prop('checked')) {
      weekdays.push("1");
      any = true;
    } else {
      weekdays.push("0");
    }
  });
  if(any) {
    $('#weekdays').val(weekdays.join(""));
    $('#type').val("RepeatedScheduledRequest");
  } else {
    $('#weekdays').val(null);
    $('#type').val("OneOffScheduledRequest");
  }
}
