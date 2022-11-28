window.addEventListener('DOMContentLoaded', (event) => {
  $('.config-tooltip').tooltip();
  $('.override-input').change(function(e) {
    updateMinuteMax();
    if (e.originalEvent) {
      $(this).attr('data-changed', 'yes');
      updateOverrideDateTime();
      validateConfigChange();
    }
  });
  $('#monitor-pause').click(function() {
    toggleOverrideInputs();
    validateConfigChange();
  });
  $('.config-input').change(validateConfigChange);
  toggleOverrideInputs();
  $('#monitor-status-switch').change(disableMonitor);
  $('#config-change-form').submit(function() {
    confirmMonitorDisable();
    if(document.querySelectorAll(`[data-changed='yes']`).length > 0) {
      updateOverrideDateTime();
    }
  });
  $('.group-priority-input').change(updateGroupWeightedPriorities);
  $('.type-priority-input').change(updateTypeWeightedPriority);
  validateConfigChange();
});

function updateMinuteMax() {
  if ($('#override-hours').val() === '8') {
    $('#override-minutes').attr('max', '0');
    $('#override-minutes').val('0');
  } else {
    $('#override-minutes').attr('max', '59');
  }
}

function resetOverrideInputs() {
  let originalDate = moment($('#override-monitor-until').data('original'));
  let now = moment();
  let difference = moment.duration(originalDate.diff(now));

  let hours = parseInt(difference.asHours());
  let minutes = parseInt(difference.asMinutes()) % 60;
  $('#override-hours').val(hours);
  $('#override-minutes').val(minutes);
  validateConfigChange();
}

function confirmMonitorDisable() {
  let statusInput = $('#monitor-status-input');
  if (statusInput.val() === 'false' && statusInput.data('original')) {
    let confirmation = confirm("WARNING: Disabling the utilisation switch-offs will prevent idle nodes from being switched off to preserve budget. This could lead to excessive compute unit consumption; please confirm that this is your intention.")
    return confirmation;
  }
}

function updateOverrideDateTime() {
  if (!$('#monitor-pause').is(':checked')) {
    resetOverrideInputs();
    $('#override-monitor-until').val(null);
  } else {
    let hours = $('#override-hours');
    let minutes = $('#override-minutes');
    if (hours.val() === '' || minutes.val() === '') {
      $('#override-monitor-until').val('');
    } else {
      let currentDate = moment()
      currentDate.add(hours.val(), 'hours');
      currentDate.add(parseInt(minutes.val()) + 1, 'minutes');
      currentDate.set({second:'0'});
      $('#override-monitor-until').val(currentDate.format('YYYY/MM/DD HH:mm:ss ZZ'));
    }
  }
}

function validateConfigChange() {
  let submitButton = $('#config-change-submit');
  let change = false;
  $('.config-input').each(function() {
    if($(this).val() != $(this).data('original')) change = true;
  });

  if($('#monitor-pause').data('original') != $('#monitor-pause').prop('checked')) {
    change = true;
  }

  if(($('#monitor-status-input').val() === 'true') != $('#monitor-status-input').data('original')) {
    change = true;
  }
  
  if(change === true) {
    submitButton.removeClass("disabled");
    submitButton.prop("disabled", false);
    submitButton.prop("title", "");
  } else {
    submitButton.addClass("disabled");
    submitButton.prop("disabled", true);
    submitButton.prop("title", "No changes");
  }
  if($('#monitor-pause').prop("checked") === true) {
    if($('#override-monitor-until').val() === '') {
      submitButton.addClass("disabled");
      submitButton.prop("disabled", true);
      submitButton.prop("title", "Time must not be blank");
    } else {
      const overrideTime = moment($('#override-monitor-until').val());
      let eightHoursAhead = moment()
      eightHoursAhead.add({hours:'8'})
      if(eightHoursAhead.isBefore(overrideTime) || overrideTime.isBefore(moment())) {
        submitButton.addClass("disabled");
        submitButton.prop("disabled", true);
        submitButton.prop("title", "Time must be within the next 8 hours");
      }
    }
  }
}

function toggleOverrideInputs() {
  if ($('#monitor-pause').is(':checked')) {
    $('.override-input').prop("disabled", false);
    $('.override-input').prop("required", "required");
  } else {
    $('.override-input').prop("disabled", true);
    $('.override-input').prop("required", false);
  }
  updateOverrideDateTime();
  validateConfigChange();
}

function disableMonitor() {
  if ($('#monitor-status-switch').is(':checked')) {
    $('#monitor-status-input').val('true')
    $('#threshold-input').prop('disabled', false)
    let original = $('#threshold-input').data('original');
    if(original === '') original = 5;
    $('#threshold-input').val(original);
    $('#threshold-row').fadeIn();
    $('#monitor-pause').prop('checked', $('#monitor-pause').data('original'));
    $('#override-date').val($('#override-date').data('original'));
    $('#override-time').val($('#override-time').data('original'));
    $('#pause-row').fadeIn();
  } else {
    $('#monitor-status-input').val('false')
    $('#threshold-input').val('');
    $('#pause-row').fadeOut();
    $('#threshold-row').fadeOut();
    $('#monitor-pause').prop('checked', false);
    $('#threshold-input').prop('disabled', true)
  }
  toggleOverrideInputs();
}

function updateGroupWeightedPriorities() {
  const groupId = $(this).data('group-id');
  const groupPriority = $(this).val();
  $(`.group-${groupId}-instance`).each(function() {
    const typeId = $(this).data('type-id');
    const typePriority = $(this).val();
    const weightedPriority = groupPriority * typePriority;
    let typeEl = $(`#type-${typeId}-weighted-priority`);
    typeEl.html(weightedPriority);
    typeEl.data('value', weightedPriority);
  });
  updateSwitchOffOrder();
}

function updateTypeWeightedPriority() {
  const groupId = $(this).data('group-id');
  const groupPriority = $(`#group-${groupId}-priority`).val();
  const typeId = $(this).data('type-id');
  const typePriority = $(this).val();
  const weightedPriority = groupPriority * typePriority;
  let typeEl = $(`#type-${typeId}-weighted-priority`);
  typeEl.html(weightedPriority);
  typeEl.data('value', weightedPriority);
  updateSwitchOffOrder();
}

function updateSwitchOffOrder() {
  let instanceDetails = $(".type-weighted-priority").map(function () {
    let data = $(this).data();
    data.groupPriority = parseInt($(`#group-${data.groupId}-priority`).val());
    data.mem = parseInt(data.mem);
    return data;
  });
  let target = $('#switch-off-cards');
  let html = "";
  console.log(instanceDetails.sort(sortSwitchOff));
  instanceDetails.sort(sortSwitchOff).each(function(index, typeData) {
    console.log(typeData);
    html += '<div class="card switch-off-order-card"><div class="card-header">';
    html += typeData.groupName;
    html += '</div> <div class="card-body">';
    html += typeData.customerFacingType;
    html+= '</div></div>';
  });
  target.html(html);
}

function sortSwitchOff(a, b) {
  if (a.value === b.value) {
    if(a.groupPriority === b.groupPriority) {
      if(a.mem === b.mem) return 0;
      return a.mem > b.mem ? 1 : -1;
    } else {
      if (a.mem === b.mem) return 0;
      return a.groupPriority > b.groupPriority ? 1 : -1;
    }
  }
  return a.value > b.value ? 1 : -1;
}
