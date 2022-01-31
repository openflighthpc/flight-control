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

window.addEventListener('DOMContentLoaded', (event) => {
  if($('#cost-chart-filter').length > 0) {
    $('.cost-chart-date').on('input', validateCostChartDates);
  }
});

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
