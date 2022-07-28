window.addEventListener('DOMContentLoaded', (event) => {
  let currentEvents = setTimeout(checkCurrentEvents, 30000);
  $('.tool-tip').tooltip();
});

function checkCurrentEvents() {
  let xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      let response = JSON.parse(this.responseText);
      updateCurrentStates(response["states"]);
      updateUpcoming(response["upcoming"]);
      updateInProgress(response["in_progress"]);
      updateFuture(response["future"]);
      newDataTimeout = setTimeout(checkCurrentEvents, 30000);
    }
  };
  xhttp.onerror = function() {
    alert("Unable to connect to server. Please check your connection and that the application is still running.");
  };
  let projectName = $('#project-name').data('project');
  let projectParam = `?project=${projectName}`;
  let groups = $('#original-groups').data('original-groups');
  let groupsParam = "";
  if(groups != "") {
    for(let i = 0; i < groups.length; i++) {
      groupsParam += `&groups[]=${groups[i]}`;
    }
  }
  xhttp.open("GET", `/json/events/latest${projectParam}${groupsParam}`, true);
  xhttp.send();
}

function updateCurrentStates(states) {
  Object.keys(states).forEach((group) => {
    Object.keys(states[group]).forEach((instanceType) => {
      let id = `${group}-${instanceType}-on`;
      let value = states[group][instanceType].toString();
      if($(`#${id}`).html() != value.toString()) {
        updateCountWithFade(group, instanceType, value);
      }
    });
  });
  $('.tool-tip').tooltip();
}

function updateCountWithFade(group, type, value) {
  let countEl = $(`#${group}-${type}-on`);
  let costEl = $(`#${group}-${type}-total`);
  let totalCost = value * parseInt(costEl.data('cost-each'));
  countEl.fadeOut('slow', function() {
    countEl.html(value);
    countEl.fadeIn('slow');
  });
  costEl.fadeOut('slow', function() {
    costEl.html(`${totalCost}c.u.`);
    costEl.fadeIn('slow');
  });
}

function updateInProgress(actionLogs) {
  if(Object.keys(actionLogs).length === 0) {
    $('#in-progress-table-row').fadeOut('slow', function() {
      $('#no-in-progress-row').fadeIn('slow');
    });
  } else {
    $('#no-in-progress-row').fadeOut('slow', function() {
      $('#in-progress-table-row').fadeIn('slow');
    });
  }
  let existing = $('.action-log-row');
  existing.each(function() {
    let id = parseInt($(this).data('log-id'));
    if(actionLogs[id] === undefined) {
      $(this).fadeOut('slow');
    }
  });
  Object.keys(actionLogs).forEach((logId) => {
    if($(`#action-${logId}`).length === 0) {
      addNewInProgress(actionLogs[logId]);
    }
  });
}

function addNewInProgress(details) {
  let html = `<tr class='action-log-row' id='action-${details.id}' data-log-id='${details.id}'`;
  html += "style='display:none'>";
  html += `<td>${details.formatted_timestamp}</td>`;
  html += `<td>${details.simplified_details}</td>`;
  html += `<td>${details.username}</td>`;
  html += `<td>${details.status}</td></tr>`;
  $('#in-progress-table').append(html);
  $(`#action-${details.id}`).fadeIn('slow');
}

function updateUpcoming(scheduledRequests) {
  updateScheduledTable(scheduledRequests, "upcoming");
}

function updateScheduledTable(scheduledRequests, type) {
  if(Object.keys(scheduledRequests).length === 0) {
    $(`#${type}-events-table-row`).fadeOut('slow', function() {
      $(`#no-${type}-events-row`).fadeIn('slow');
    });
  } else {
    $(`#no-${type}-events-row`).fadeOut('slow', function() {
      $(`#${type}-events-table-row`).fadeIn('slow');
    });
  }
  let eventsTable = $(`#${type}-events-table-row`);
  let existing = eventsTable.find(".schedule-row");
  existing.each(function() {
    let id = $(this).attr('id');
    let date = $(this).data('date');
    if(scheduledRequests[date] === undefined || scheduledRequests[date][id] === undefined) {
      $(this).fadeOut('slow');
    }
  });
  let existingDetails = eventsTable.find(`.${type}.event-details-row`);
  existingDetails.each(function() {
    let id = $(this).attr('id');
    let date = $(this).data('date');
    if(scheduledRequests[date] === undefined || scheduledRequests[date][id] === undefined) {
      $(this).fadeOut('slow');
    }
  });
  let previousId = null;
  Object.keys(scheduledRequests).forEach((date) => {
    let firstForDate = true;
    Object.keys(scheduledRequests[date]).forEach((scheduledId) => {
      let element = $(`#${type}-events-table`).find(`#${scheduledId}`);
      if(element.length === 0) {
        addNewSchedule(scheduledRequests[date][scheduledId], type, firstForDate, previousId);
        // update formatting & date display to group things correctly by date
        // when new events/ events removed
      } else {
        if(scheduledRequests[date][scheduledId].updated_at != element.data('updated_at')) {
          updateScheduleDetails(scheduledRequests[date][scheduledId], type, firstForDate);
        } else if(firstForDate && !element.hasClass("border-top")) {
          element.addClass("border-top");
          element.find(".future-event-date").html(date);
        } else if(!firstForDate && element.hasClass("border-top")) {
          element.removeClass("border-top");
          element.find(".future-event-date").html("");
        }
      }
      firstForDate = false;
      previousId = scheduledId;
    });
  });
}

function updateFuture(scheduledRequests) {
  updateScheduledTable(scheduledRequests, "future");
}

function addNewSchedule(details, type, firstForDate, previousId) {
  let html = buildNewSchedule(details, type, firstForDate);
  if(previousId === null) {
    $(`#${type}-events-table-body`).prepend(html);
  } else {
    let previous = $(`#${type}-events-table`).find(`.table-row#${previousId}`);
    $(html).insertAfter(previous);
  }
  $(`#${type}-events-table`).find(`#${details.frontend_id}`).fadeIn('slow');
}

function updateScheduleDetails(details, type, firstForDate) {
  let html = buildNewSchedule(details, type, firstForDate, true);
  $(`#${type}-events-table`).find(`#${details.frontend_id}`).replaceWith(html);
}

function buildNewSchedule(details, type, firstForDate, display=false) {
  let html = `<tr class='text-center schedule-row ${firstForDate ? "border-top" : ""}' id='${details.frontend_id}' data-date='${details.date}'`;
  html += `data-updated_at="${details.updated_at}" ${display ? "" : "style='display:none;'"}>`;
  html += `<td>${firstForDate ? details.date : ""}</td>`;
  html += `<td>${details.time}</td>`;
  html += `<td>${details.counts_criteria}</td>`;
  groups.forEach(function(group) {
    html += `<td ${details.type === "budget_switch_off" ? "class='text-danger'" : ""}>`;
    let instances = details.descriptive_counts[group];
    if(instances != undefined) {
      if(instances === "All on" || instances === "All off") {
        html += instances;
      } else {
        Object.keys(instances).forEach(function(instance, index) {
          if(index != 0) html += "<br>";
          html += `${details.descriptive_counts[group][instance]} x ${instance}`;
          if(details.type === "budget_switch_off") html += " off";
        });
      }
    } else {
      html += "-";
    }
    html += "</td>";
  });
  let override = details.monitor_override_hours;
  if (override) override = `${override} hour${ override > 1 ? 's' : '' }`;
  html += `<td>${override ? override : '-'}</td>`;
  html += `<td>${details.description ? details.description : '-'}</td>`;

  let viewButton = $(`#view-button-${details.frontend_id}`);
  html += `<td>`;
  html += viewButton[0].outerHTML;
  html += "</td>";
  html += "</tr>";

  let eventDetails = $(`#event-details-${details.frontend_id}`);
  html += "<tr>";
  html += `<td colspan="7" class="${type} event-details-row" id="${details.frontend_id}" data-date="${details.date}">`;
  html += eventDetails[0].outerHTML;
  html += "</td>";
  html += "</tr>";

  viewButton.remove();
  eventDetails.remove();
  return html;
}
