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
