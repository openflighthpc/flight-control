window.addEventListener('DOMContentLoaded', (event) => {
  setTimeout(checkForNewData, 30000);
});

window.checkForNewData = function() {
  let xhttp = new XMLHttpRequest();
  xhttp.onreadystatechange = function() {
    if (this.readyState == 4 && this.status == 200) {
      let response = JSON.parse(this.responseText);
      if (response.changed === true) {
        requestRefresh();
      } else {
        setTimeout(checkForNewData, 30000);
      }
    }
  };
  xhttp.onerror = function() {
    alert("Unable to connect to server. Please check your connection and that the application is still running.");
  };

  let changeEl = $('#latest-change');
  let projectName = changeEl.data('project');
  let projectParam = `?project=${projectName}&`;
  let latestChange = changeEl.data('value');
  xhttp.open("GET", `/json/data-check${projectParam}timestamp=${latestChange}`, true);
  xhttp.send();
}

window.requestRefresh = function() {
  alert("Project data has been updated. The page will be refreshed to show the latest information.");
  window.location.reload();
}
