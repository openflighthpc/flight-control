window.addEventListener('DOMContentLoaded', (event) => {
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
    $('#wizard-next-button').data('next', 'extras');
  } else {
    $('#future-choice').collapse('hide');
    $('#wizard-next-button').data('next', 'review');
  }
}

// Once done, try to merge show next and show previous
function showNextSection() {
  let nextButton = $('#wizard-next-button');
  if(nextButton.attr('disabled') === 'disabled') return;

  let target = nextButton.data('next');
  let backButton = $('#wizard-back-button');
  let nextSection = $(`#wizard-choose-${target}`);
  let current = nextButton.data('current');
  if(current === "when") {
    getEventCostForecast();
  }
  backButton.data('previous', current);
  backButton.css('visibility', 'visible');
  nextButton.data('current', target);
  if(target === "when") {
    nextButton.data('next', 'review');
    validateTimings();
  } else if(target === "extras") {
    nextButton.data('next', 'review');
  } else if(target === "review") {
    nextButton.hide();
    $('#wizard-submit-button').show();
  }
  $('.wizard-section').hide();
  nextSection.show();
}

function showPreviousSection() {
  let backButton = $('#wizard-back-button');
  let nextButton = $('#wizard-next-button');
  let origin = nextButton.data('current');
  let target = backButton.data('previous');
  let targetSection = $(`#wizard-choose-${target}`);
  nextButton.data('current', target);
  nextButton.data('next', origin);
  if(target === "counts") {
    backButton.css('visibility', 'hidden');
  }
  let newPrevious = null;
  if(target === "when") {
    newPrevious = "counts";
  } else if (target === "extras") {
    newPrevious = "when";
  }
  nextButton.show();
  $('#wizard-submit-button').hide();
  backButton.data('previous', newPrevious);
  $('.wizard-section').hide();
  targetSection.show();
  // Remove any validation from what is now the next section
  nextButton.removeClass('disabled');
  nextButton.attr('disabled', false);
  nextButton.prop('title', '');
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
    nextButton.attr('disabled', true);
    nextButton.prop('title', "No counts selected");
  } else {
    nextButton.removeClass('disabled');
    nextButton.attr('disabled', false);
    nextButton.prop('title', "");
  }
}

function validateTimings() {
  let nextButton = $('#wizard-next-button');
  let valid = false;
  if ($('#time-now').prop("checked")) {
    valid = true;
    nextButton.data('next', 'review');
  } else {
    nextButton.data('next', 'extras')
    let time = $('#scheduled-time').val();
    let date = $('#scheduled-date').val();
    let weekdays = $('#weekdays').val();
    let endDate = $('#end-date').val();
    if (time === "" || date === "") {
      nextButton.attr("disabled", true);
      nextButton.prop("title", "Date and time must be specified");
      nextButton.addClass("disabled");
    } else if (weekdays != "" && endDate === "" || weekdays === "" && endDate != "") {
      nextButton.attr("disabled", true);
      nextButton.prop("title", "For repeated policy, weekdays and an end date must be selected");
      nextButton.addClass("disabled");
    } else if (endDate != "" && new Date(endDate) < new Date(date)) {
      nextButton.attr("disabled", true);
      nextButton.prop("title", "For repeated policy, end date must be after or equal to start date");
      nextButton.addClass("disabled");
    } else {
      let oneHourAhead = new Date();
      oneHourAhead.setHours(oneHourAhead.getHours() + 1);
      let fullDate = new Date(`${date} ${time}`);
      if (weekdays === "" && fullDate < oneHourAhead) {
        nextButton.attr("disabled", true);
        nextButton.prop("title", "Must be at least one hour in the future");
        nextButton.addClass("disabled");
      } else {
        valid = true;
      }
    }
  }
  if (valid) {
    nextButton.removeClass('disabled');
    nextButton.attr('disabled', false);
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
  } else {
    $('#weekdays').val(null);
  }
}

window.getEventCostForecast = function(event) {
  let xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      let response = JSON.parse(this.responseText);
      updateChart(response.costs);
      $('#loading-chart-spinner').addClass('d-none');
      $('#simpleChart').css('visibility', 'visible');
    }
  };
  xhttp.onerror = function() {
    alert("Unable to connect to server. Please check your connection and that the application is still running.");
  };

  $('#loading-chart-spinner').removeClass('d-none');
  $('#simpleChart').css('visibility', 'hidden');
  let params = `?${$('#create-event-form').serialize()}`;
  xhttp.open("GET", `/json/events/costs-forecast${params}`, true);
  xhttp.send();
}

function updateChart(costs) {
  simple_chart.data.labels = costs.dates;
  let budgetDataset = simple_chart.data.datasets.find((dataset) => dataset.label === "budget");
  let actualTotalDataset = simple_chart.data.datasets.find((dataset) => dataset.label === "total");
  let forecastTotalDataset = simple_chart.data.datasets.find((dataset) => dataset.label == "forecast total");
  budgetDataset.data = costs.budget;
  actualTotalDataset.data = costs.actual.total;
  forecastTotalDataset.data = costs.forecast.total
  simple_chart.update();
  let submitButton = $('#wizard-submit-button');
  if(overBudgetDateIndexes().length > 0) {
    submitButton.addClass('disabled');
    submitButton.attr('disabled', true);
    submitButton.prop('title', 'Cannot submit request that goes over budget');
  } else {
    submitButton.removeClass('disabled');
    submitButton.attr('disabled', false);
    submitButton.prop('title', '');
  }
}
