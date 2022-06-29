window.addEventListener('DOMContentLoaded', (event) => {
  $('.tool-tip').tooltip();
  $('#load-more-logs').click(function() {
    loadLogs();
  });
});

function loadLogs(event) {
  let dataElement = $('#load-more-logs');
  const latestTimestamp = $('.log-timestamp').first().data("value");
  const logCount = $('.audit-row').length;
  const projectName = dataElement.data('project');
  const projectParam = `?project=${projectName}`;
  const startDate = dataElement.data('start_date');
  const startDateParam = startDate === undefined ? "" : `&start_date=${startDate}`;
  const endDate = dataElement.data('end_date');
  const endDateParam = endDate === undefined ? "" : `&end_date=${endDate}`;
  let filtersParam = `${startDateParam}${endDateParam}`;
  const filters = dataElement.data();
  for([key, details] of Object.entries(filters)) {
    if(key != "start_date" && key != "end_date" && key != "project") {
      const values = details.split(',');
      for (let i = 0; i < values.length; i++) {
        filtersParam = filtersParam.concat(`&${key}[]=${values[i]}`);
      }
    }
  }
  $.ajax({
    type: "GET",
    url: `/more-audit-logs${projectParam}&timestamp=${latestTimestamp}&log_count=${logCount}${filtersParam}`,
    error: function(xhr, status, error){
      alert(`Unable to connect to the server`);
    }
  })
}
