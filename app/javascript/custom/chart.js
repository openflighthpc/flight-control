window.addEventListener('DOMContentLoaded', (event) => {
  addOverBudgetLines();
  addCycleLines();
  if($('#cost-chart-filter').length > 0) {
    $('.cost-chart-date').on('input', validateCostChartDates);
  }
  $('.instance-tooltip').tooltip();
  setTimeout(checkForNewData, 30000);
});

// to give the illusion that actual & forecast datasets are one and the same
window.hideRelatedDatasetOnClick = function(e, legendItem, legend) {
  let charts = {"cumulativeChart": "cumulative_chart", "simpleChart": "simple_chart", "costBreakdownChart": "costs_chart"};
  let index = legendItem.datasetIndex;
  let name = legendItem.text.replace("forecast ", "");
  let chart = eval(charts[e.srcElement.id]);
  let hidden = chart.getDatasetMeta(index).hidden === true ? null : true;

  if (name === "budget") {
    chart.getDatasetMeta(index).hidden = hidden;
  } else {
    let forecast = chart.data.datasets.find((dataset) => dataset.label === `forecast ${name}`);
    let actual = chart.data.datasets.find((dataset) => dataset.label === name);

    if(forecast != undefined) {
      forecast._meta[1] === undefined ? forecast._meta[0].hidden = hidden : forecast._meta[1].hidden = hidden;
    }
    if(actual != undefined) {
      actual._meta[1] === undefined ? actual._meta[0].hidden = hidden : actual._meta[1].hidden = hidden;
    }
  }
  chart.update();
};

// checking if the current chart has both forecast and actual data
window.forecastAndActual = function() {
  if(typeof costs_chart !== 'undefined') {
    if (costs_chart === null) return false; // if this is called as part of the creation of the chart

    let chart = costs_chart.data;
    let forecast = chart.datasets.find((dataset) => dataset.label === "forecast other");
    let actual = chart.datasets.find((dataset) => dataset.label === "other");
    return forecast !== undefined && actual !== undefined;
  }
}

window.overlapDateIndex = function() {
  let date_index = null;
  let chart = costs_chart;
  forecast = chart.data.datasets.find((dataset) => dataset.label === "forecast remaining budget");
  actual = chart.data.datasets.find((dataset) => dataset.label === "remaining budget");
  if(forecast != undefined && actual != undefined) {
    for (let i=0; i<actual.data.length; i++) {
      if(actual.data[i] === forecast.data[i]) date_index = i;
    }
  }
  return date_index
}

window.filterDatasets = function(chart) {
  chart.data.datasets.forEach(function(dataset, index) {
    if(dataset.show === false) {
      dataset._meta[1] === undefined ? dataset._meta[0].hidden = true : dataset._meta[1].hidden = true;
    }
  });
}

window.validateCostChartDates = function() {
  let endDate = $('#end-date').val();
  let startDate = $('#start-date').val();
  let submitButton = $('#submit-chart-filter');
  if (endDate != undefined && startDate != undefined && new Date(endDate) < new Date(startDate)) {
    submitButton.addClass('disabled');
    submitButton.prop('disabled', true);
    submitButton.prop('title', 'End date must be after start date');
  } else {
    submitButton.removeClass('disabled');
    submitButton.prop('disabled', false);
    submitButton.prop('title', '');
  }
}

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

window.addOverBudgetLines = function(){
  const verticalLinePlugin = {
    renderVerticalLine: function (chartInstance, pointIndex, type, number) {
      let meta = null;
      if(typeof chartInstance !== 'undefined' && chartInstance === cumulative_chart) {
        meta = chartInstance.getDatasetMeta(0);
      } else {
        let index = null;
        let forecastBudgetDataset = null;
        let datasets = chartInstance.data.datasets;
        for (let i = 0; i < datasets.length; i++) {
          if(datasets[i].label === "forecast remaining budget") {
            index = i;
            forecastBudgetDataset = datasets[i];
            break
          }
        }

        if (forecastBudgetDataset != null && forecastBudgetDataset.data[pointIndex] != null) {
          meta = chartInstance.getDatasetMeta(index);
        } else {
          let budgetDataset = null;
          for (let i = 0; i < datasets.length; i++) {
            if(datasets[i].label === "remaining budget") {
              index = i;
              budgetDataset = datasets[i];
              break
            }
          }
          meta = chartInstance.getDatasetMeta(index);
        }
      }
      const lineLeftOffset = meta.data[pointIndex]._model.x
      const scale = chartInstance.scales['y-axis-0'];
      const context = chartInstance.chart.ctx;

      context.beginPath();
      context.strokeStyle = '#ff0000';
      context.moveTo(lineLeftOffset, scale.top);
      context.lineTo(lineLeftOffset, scale.bottom);
      context.stroke();

      context.fillStyle = "#ff0000";
      let position = 'center';
      if (pointIndex < 2) position = 'left';
      if (pointIndex > chartInstance.data.labels.length - 3) position = 'right';
      context.textAlign = position;
      let topPosition = (((scale.bottom - scale.top)/10) * number) + scale.top
      context.fillText(`    ${type} `, lineLeftOffset, topPosition);
    },

    afterDatasetsDraw: function (chart, easing) {
      let indexes = overBudgetDateIndexes();
      for (let i = 0; i < indexes.length; i++) {
        this.renderVerticalLine(chart, indexes[i], "Over budget", 1);
      }
      if(chart.data.balance_end != null) {
        this.renderVerticalLine(chart, chart.data.balance_end, "Empty balance", 2);
      }
    }
  };

  Chart.plugins.register(verticalLinePlugin);
}

// Project start, cycle and project ends
window.addCycleLines = function(){
  const verticalLinePlugin = {
    renderVerticalLine: function (chartInstance, cycle_details) {
      const pointIndex = cycle_details.index
      let meta = null;
      if(typeof chartInstance !== 'undefined' && chartInstance === cumulative_chart) {
        meta = chartInstance.getDatasetMeta(0);
      } else {
        let index = null;
        let forecastBudgetDataset = null;
        let datasets = chartInstance.data.datasets;
        for (let i = 0; i < datasets.length; i++) {
          if(datasets[i].label === "forecast remaining budget") {
            index = i;
            forecastBudgetDataset = datasets[i];
            break
          }
        }

        if (forecastBudgetDataset != null && forecastBudgetDataset.data[pointIndex] != null) {
          meta = chartInstance.getDatasetMeta(index);
        } else {
          let budgetDataset = null;
          for (let i = 0; i < datasets.length; i++) {
            if(datasets[i].label === "remaining budget") {
              index = i;
              budgetDataset = datasets[i];
              break
            }
          }
          meta = chartInstance.getDatasetMeta(index);
        }
      }
      const lineLeftOffset = meta.data[pointIndex]._model.x
      const scale = chartInstance.scales['y-axis-0'];
      const context = chartInstance.chart.ctx;
      let colour = cycle_details.type === "Project start" ? "#0EA31B" : "#2a4b70"
      context.beginPath();
      context.strokeStyle = colour;
      context.moveTo(lineLeftOffset, scale.top);
      context.lineTo(lineLeftOffset, scale.bottom);
      context.stroke();

      context.fillStyle = colour;
      let position = 'center';
      if (pointIndex < 2) position = 'left';
      if (pointIndex > chartInstance.data.labels.length - 3) position = 'right';
      context.textAlign = position;
      context.fillText(`    ${cycle_details.type} `, lineLeftOffset, (scale.bottom - scale.top)/2 + scale.top);
    },

    afterDatasetsDraw: function (chart, easing) {
      let cycle_thresholds = chart.data.cycle_thresholds;
      for (let i = 0; i < cycle_thresholds.length; i++) {
        this.renderVerticalLine(chart, cycle_thresholds[i]);
      }
    }
  };

  Chart.plugins.register(verticalLinePlugin);
}

window.overBudgetDateIndexes = function(){
  let indexes = [];
  if (typeof costs_chart != 'undefined') {
    let budgetDataset = costs_chart.data.datasets.find((dataset) => dataset.label === "remaining budget");
    let forecastBudgetDataset = costs_chart.data.datasets.find((dataset) => dataset.label === "forecast remaining budget");
    // We want to show each time it goes over budget (crosses down 0),
    // but not each day it's already over.
    let firstOver = true;

    if (budgetDataset != null) {
      let data = budgetDataset.data;
      for (let i = 0; i < data.length; i++) {
        if (data[i] != null) {
          if (data[i] < 0) {
            if (firstOver === true) {
              firstOver = false;
              indexes.push(i);
            }
          } else {
            firstOver = true;
          }
        }
      }
    }

    if (forecastBudgetDataset != null) {
      let data = forecastBudgetDataset.data;
      for (let i = 0; i < data.length; i++) {
        if (data[i] != null) {
          if (data[i] < 0) {
            if (firstOver === true) {
              firstOver = false;
              indexes.push(i);
            }
          } else {
            firstOver = true;
          }
        }
      }
    }
  }
  return indexes;
}
