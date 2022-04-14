window.addEventListener('DOMContentLoaded', (event) => {
  $('.tool-tip').tooltip();
  $('#load-more-logs').click(function() {
    loadLogs();
  });
});

function loadLogs(event) {
  let xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      let response = JSON.parse(this.responseText);
      addLogs(response);
      $('.tool-tip').tooltip();
    }
  };
  xhttp.onerror = function() {
    alert("Unable to connect to server. Please check your connection and that the application is still running.");
  };

  let dataElement = $('#load-more-logs');
  const latestTimestamp = $('.log-timestamp').eq(4).data("value");
  const logCount = $('.audit-row').length;
  const projectName = dataElement.data('project');
  const projectParam = `?project=${projectName}`;
  const startDate = dataElement.data('start_date');
  const startDateParam = startDate === undefined ? "" : `&start_date=${startDate}`;
  const endDate = dataElement.data('end_date');
  const endDateParam = endDate === undefined ? "" : `&end_date=${endDate}`;
  let filtersParam = "";
  const filters = dataElement.data();
  for([key, details] of Object.entries(filters)) {
    if(key != "start_date" && key != "end_date" && key != "project") {
      const values = details.split(',');
      for (let i = 0; i < values.length; i++) {
        filtersParam = filtersParam.concat(`&${key}[]=${values[i]}`);
      }
    }
  }
  xhttp.open("GET", `/json/audit-logs${projectParam}&timestamp=${latestTimestamp}&log_count=${logCount}${filtersParam}`, true);
  xhttp.send();
}

function addLogs(response){
  response.logs.forEach(function(log){
    if(log.type === "change_request"){
      addChangeRequestCard(log);
    } else if(log.type === "config_log") {
      addConfigLogCard(log);
    } else if(log.type === "change_request_audit_log") {
      addChangeRequestChangeCard(log);
    }else {
      addActionLogCard(log);
    }
  });
  if(response.more === false){
    $('#load-more-logs').addClass('d-none');
  }
}

function addChangeRequestCard(log){
  const blankSrCard = $('.blank-change-request-card');
  let newCard = blankSrCard.clone();
  newCard.removeClass('blank-change-request-card');
  newCard.removeClass('d-none');
  newCard.addClass('audit-row');
  $('.cr-username', newCard).html(log.username);
  let timestamp = $('.log-timestamp', newCard);
  timestamp.data('value', log.timestamp);
  timestamp.html(log.formatted_timestamp);
  $('.card-text', newCard).html(log.details);
  $('.change-status', newCard).html(log.status);
  newCard.insertAfter($('.audit-row').last());
}

function addChangeRequestChangeCard(log) {
  const blankSrCard = $('.blank-change-request-audit-log-card');
  let newCard = blankSrCard.clone();
  newCard.removeClass('blank-change-request-audit-log-card');
  newCard.removeClass('d-none');
  newCard.addClass('audit-row');
  if(log.cancellation) {
    let header = $('.card-header', newCard);
    header.removeClass('request-change-header');
    header.addClass('request-cancel-header');
  }
  $('.cr-username', newCard).html(log.username);
  let timestamp = $('.log-timestamp', newCard);
  timestamp.data('value', log.timestamp);
  timestamp.html(log.formatted_timestamp);
  $('.card-text', newCard).html(log.details);
  $('.change-status', newCard).html(log.status);
  newCard.insertAfter($('.audit-row').last());
}

function addActionLogCard(log){
  const blankActionLogCard = $('.blank-action-log-card');
  let newCard = blankActionLogCard.clone();
  newCard.removeClass('blank-action-log-card');
  newCard.removeClass('d-none');
  newCard.addClass('audit-row');
  let timestamp = $('.log-timestamp', newCard);
  timestamp.data('value', log.timestamp);
  timestamp.html(log.formatted_timestamp);
  $('.action-log-type', newCard).html(log.automated === true ? "Automated action log" : "Action log");
  if(log.automated) {
    let header = $('.card-header', newCard);
    header.removeClass('action-header');
    header.addClass('automated-action-header');
  }
  $('.card-text', newCard).html(log.details);
  $('.action-status', newCard).html(log.status);
  newCard.insertAfter($('.audit-row').last());
  $('.action-log-tooltip').tooltip();
}

function addConfigLogCard(log) {
  const blankConfigCard = $('.blank-config-log-card');
  let newCard = blankConfigCard.clone();
  newCard.removeClass('blank-config-log-card');
  newCard.removeClass('d-none');
  newCard.addClass('audit-row');
  if(log.automated) {
    let link = `<a href='/scheduled-changes/${log.scheduled_request_id}'>power-on policy.</a>`
    $('.config-log-source', newCard).html(`Project configuration updated as part of a ${link}`);
  } else {
    $('.config-username', newCard).html(log.username);
  }
  let timestamp = $('.log-timestamp', newCard);
  timestamp.data('value', log.timestamp);
  timestamp.html(log.formatted_timestamp);
  $('.card-text', newCard).html(log.details);
  $('.log-status', newCard).html(log.status);
  newCard.insertAfter($('.audit-row').last());
}
