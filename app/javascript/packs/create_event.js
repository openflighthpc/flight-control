window.addEventListener('DOMContentLoaded', (event) => {
  $('.simple-node-count').change(validateCounts);
  $('.when-radio').change(toggleDateSelectors);
  $('.when-radio').change(validateTimings);
  $('.day-input').change(updateWeekdays);
  $('.scheduled-input').change(validateTimings);
  $('#wizard-next-button').click(showNextSection);
  $('#wizard-back-button').click(showPreviousSection);
  validateCounts();
  // Prevent pressing enter in the description field submitting the form early
  $('#create-event-form').on("keydown", function(event) {
    return event.key != "Enter";
  });
});

function toggleDateSelectors() {
  if($('#time-future').prop('checked')) {
    $('#future-choice').collapse('show');
    $('#wizard-next-button').data('next', 'extras');
  } else {
    $('#future-choice').collapse('hide');
    $('#wizard-next-button').data('next', 'review');
    $('.day-input').prop('checked', false);
    $('.scheduled-input').val("");
    $('.scheduled-description').val("");
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
    updateRequestSummary();
    $('#wizard-submit-button').show();
  }
  $('.wizard-section').hide();
  nextSection.show();
  if(current === "when") {
    getEventCostForecast();
  }
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
      const existing = $('#request-id').length > 0;
      const changedTime = existing && fullDate.getTime() != new Date($('#original-start').data('value')).getTime();
      if ((!existing || changedTime) && fullDate < oneHourAhead) {
        nextButton.attr("disabled", true);
        nextButton.prop("title", "Must be at least one hour in the future");
        nextButton.addClass("disabled");
      } else if(overlapsExisting()) {
        nextButton.attr("disabled", true);
        nextButton.prop("title", "Timings overlap an existing request");
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
  let type = $('#request-type');
  if(any) {
    $('#weekdays').val(weekdays.join(""));
    type.val('RepeatedChangeRequest');
  } else {
    $('#weekdays').val(null);
    type.val('OneOffChangeRequest');
  }
}

window.getEventCostForecast = function(event) {
  let xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      let response = JSON.parse(this.responseText);
      updateChart(response);
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

function updateChart(response) {
  let costs = response.costs;
  simple_chart.data.labels = costs.dates;
  let budgetDataset = simple_chart.data.datasets.find((dataset) => dataset.label === "budget");
  let actualTotalDataset = simple_chart.data.datasets.find((dataset) => dataset.label === "total");
  let forecastTotalDataset = simple_chart.data.datasets.find((dataset) => dataset.label == "forecast total");
  budgetDataset.data = costs.budget;
  actualTotalDataset.data = costs.actual.total;
  forecastTotalDataset.data = costs.forecast.total
  simple_chart.data.balance_end = response.balance_end;
  simple_chart.update();
  let submitButton = $('#wizard-submit-button');
  let overBudget = overBudgetDateIndexes().length > 0;
  if(simple_chart.data.balance_end != null) {
    submitButton.addClass('disabled');
    submitButton.attr('disabled', true);
    submitButton.prop('title', 'Cannot submit request that goes over balance');
  } else if(overBudget) {
    submitButton.addClass('disabled');
    submitButton.attr('disabled', true);
    submitButton.prop('title', 'Cannot submit request that goes over budget');
  } else {
    submitButton.removeClass('disabled');
    submitButton.attr('disabled', false);
    submitButton.prop('title', '');
  }
  if(simple_chart.data.balance_end != null) {
    $('#over-balance-warning').css('display', 'block');
  } else {
    $('#over-balance-warning').css('display', 'none');
  }
  if(overBudget) {
    $('#over-budget-warning').css('display', 'block');
  } else {
    $('#over-budget-warning').css('display', 'none');
  }
}

window.updateRequestSummary = function() {
  let summarySection = $('#request-choices-summary');
  const countCriteria = $('input[name="counts_criteria"]:checked').val();
  let timing = "";
  const now = $('input[name="timeframe"]:checked').val() === "now";
  if(now) {
    timing = "now (5 minutes after submission)";
  } else {
    timing = `at ${$('#scheduled-date').val()} ${$('#scheduled-time').val()}`;
  }
  let text = `Set <strong>${countCriteria}</strong> counts ${timing}:<br><br>`;
  let counts = $('.simple-node-count');
  let includedGroups = [];
  counts.each(function() {
    let count = $(this);
    if(count.val() != "") {
      let group = count.data('compute-group');
      if(!includedGroups.includes(group)) {
        text += `<strong>${group}</strong><br>`;
        includedGroups.push(group);
      }
      text += `${count.val()} ${count.data('customer-facing')}<br>`
    }
  });
  text += "<br>";
  if(!now) {
    if($('#weekdays').val() != "") {
      text += `<strong>Repeat:</strong> ${readableWeekdays()}<br>`;
      text += `<strong>Until:</strong> ${$('#end-date').val()}<br>`;
    }
    let description = $('#scheduled-description').val().replace(/<\/?[^>]+(>|$)/g, "");
    if(description != "") text += `<strong>Description</strong>: ${description}`;
  }
  summarySection.html(text);
}

function readableWeekdays() {
  let weekdays = $('#weekdays').val();
  if(weekdays === "1111111") return "Every day";

  daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  let readable = "";
  let firstDay = true;
  for (let i = 0; i < weekdays.length; i++) {
    if(weekdays[i] === "1") {
      if (firstDay) {
        firstDay = false;
      } else {
        readable += ", ";
      }
      readable += daysOfWeek[i];
    }
  }
  return readable;
}

function overlapsExisting() {
  if(Object.keys(existingRequestTimings).length === 0) return false;

  let time = $('#scheduled-time').val();
  let date = $('#scheduled-date').val();
  if(time === "" || date === "") return false;

  let weekdays = $('#weekdays').val();
  let endDate = $('#end-date').val();
  if(weekdays === "") {
    if(existingRequestTimings[date] && existingRequestTimings[date][time]) {
      return true;
    }
  } else if(weekdays != "" && endDate != "") {
    weekdays = weekdays.split("");
    endDate =  new Date(endDate);
    endDate.setHours(0,0,0,0);
    date = new Date(date);
    date.setHours(0,0,0,0);
    while(date <= endDate) {
      date.setDate(date.getDate() + 1);
      let day = (date.getDay() + 6) % 7; // JS treats Sunday as day one, we use Monday
      if(weekdays[day] === "1") {
        let formattedDate = format_date(date);
        if(existingRequestTimings[formattedDate] && existingRequestTimings[formattedDate][time]) {
          return true;
        }
      }
    }
  }
  return false;
}

function format_date(dateTime) {
  // JS getMonth method starts at 0
  let month = ensureTwoDigits((dateTime.getMonth() + 1).toString());
  let year = dateTime.getFullYear();
  let date = ensureTwoDigits(dateTime.getDate().toString());
  return `${year}-${month}-${date}`;
}

function format_time(dateTime) {
  let hours = ensureTwoDigits(dateTime.getHours().toString());
  let minutes = ensureTwoDigits(dateTime.getMinutes().toString());
  return `${hours}:${minutes}`;
}

function ensureTwoDigits(timeAspect) {
  return timeAspect.length < 2 ? `0${timeAspect}` : timeAspect;
}
