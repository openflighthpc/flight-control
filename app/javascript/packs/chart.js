window.addEventListener('DOMContentLoaded', (event) => {
  addOverBudgetLines();
  addCycleLines();
  addShutOffLines();
  if($('#cost-chart-filter').length > 0) {
    $('.cost-chart-date').on('input', validateCostChartDates);
  }
  $('.tool-tip').tooltip();
});

// to give the illusion that actual & forecast datasets are one and the same
window.hideRelatedDatasetOnClick = function(e, legendItem, legend) {
  let charts = {"cumulativeChart": "cumulative_chart", "simpleChart": "simple_chart", "costBreakdownChart": "costs_chart"};
  let index = legendItem.datasetIndex;
  let name = legendItem.text.replace("forecast ", "");
  let chart = eval(charts[e.chart.canvas.id]);
  let hidden = chart.getDatasetMeta(index).hidden === true ? null : true;
  if (name === "budget") {
    chart.getDatasetMeta(index).hidden = hidden;
  } else {
    let forecastIndex = chart.data.datasets.findIndex((dataset) => dataset.label === `forecast ${name}`);
    let actualIndex = chart.data.datasets.findIndex((dataset) => dataset.label === name);
    if(forecastIndex !== -1) {
      chart.getDatasetMeta(forecastIndex).hidden = hidden;
    }
    if(actualIndex !== -1) {
      chart.getDatasetMeta(actualIndex).hidden = hidden;
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
  } else {
    if (simple_chart === null) return false; // if this is called as part of the creation of the chart

    let chart = simple_chart.data;
    let forecast = chart.datasets.find((dataset) => dataset.label === "forecast total");
    let actual = chart.datasets.find((dataset) => dataset.label === "total");
    return forecast !== undefined && actual !== undefined;
  }
}

window.overlapDateIndex = function() {
  let date_index = null;
  let chart = typeof cumulative_chart !== 'undefined' ? cumulative_chart : simple_chart;
  forecast = chart.data.datasets.find((dataset) => ["forecast cycle total", "forecast total"].includes(dataset.label));
  actual = chart.data.datasets.find((dataset) => ["cycle total", "total"].includes(dataset.label));
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

window.addOverBudgetLines = function(){
  const verticalLinePlugin = {
    id: 'verticalLinePlugin',
    renderVerticalLine: function (chartInstance, pointIndex, type, number) {
      let meta = null;
      if(typeof simple_chart !== 'undefined' && chartInstance === simple_chart ||
         typeof chartInstance !== 'undefined' && chartInstance === cumulative_chart) {
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
      let position = 'left';
      if (pointIndex > chartInstance.data.labels.length / 2) position = 'right';
      context.textAlign = position;
      if(position === 'left') {
        type = "< " + type;
      } else {
        type += " >";
      }
      let topPosition = (((scale.bottom - scale.top)/10) * number) + scale.top
      context.fillText(type, lineLeftOffset, topPosition);
    },

    afterDatasetsDraw: function (chart, easing) {
      let indexes = overBudgetDateIndexes();
      for (let i = 0; i < indexes.length; i++) {
        this.renderVerticalLine(chart, indexes[i], "Over budget", 1);
      }
      if(chart.data.balance_end !== undefined && chart.data.balance_end.cycle_index !== null) {
        this.renderVerticalLine(chart, chart.data.balance_end.cycle_index, "Empty balance", 9);
      }
    }
  };

  Chart.register(verticalLinePlugin);
}

// Project start, cycle and project ends
window.addCycleLines = function(){
  const verticalLinePlugin = {
    id: 'cycleLinesPlugin',
    renderVerticalLine: function (chartInstance, cycle_details) {
      const pointIndex = cycle_details.index
      let meta = null;
      if(typeof simple_chart !== 'undefined' && chartInstance === simple_chart ||
         typeof chartInstance !== 'undefined' && chartInstance === cumulative_chart) {
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
      if(meta.data[pointIndex] === undefined) return;
      const lineLeftOffset = meta.data[pointIndex].x
      const scale = chartInstance.scales.y.min;
      const context = chartInstance.ctx;
      let colour = cycle_details.type === "Project start" ? "#0EA31B" : "#2a4b70"
      context.beginPath();
      context.strokeStyle = colour;
      context.moveTo(lineLeftOffset, scale.top);
      context.lineTo(lineLeftOffset, scale.bottom);
      context.stroke();

      context.fillStyle = colour;
      let type = cycle_details.type;
      let position = 'left';
      if (pointIndex > chartInstance.data.labels.length / 2) position = 'right';
      context.textAlign = position;
      if(position === 'left') {
        type = "< " + type;
      } else {
        type += " >";
      }
      context.fillText(type, lineLeftOffset, (scale.bottom - scale.top)/2 + scale.top);
    },

    afterDatasetsDraw: function (chart, easing) {
      let cycle_thresholds = chart.data.cycle_thresholds;
      if (cycle_thresholds !== undefined) {
        for (let i = 0; i < cycle_thresholds.length && i < chart.data.labels.length; i++) {
          this.renderVerticalLine(chart, cycle_thresholds[i]);
        }
      }
    }
  };

  Chart.register(verticalLinePlugin);
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
  } else {
    let budgetData = simple_chart.data.datasets.find((dataset) => dataset.label === "budget").data;
    let totalDataset = simple_chart.data.datasets.find((dataset) => dataset.label === "total");
    let forecastTotalDataset = simple_chart.data.datasets.find((dataset) => dataset.label === "forecast total");
    let firstOver = true;

    if (totalDataset != null) {
      let data = totalDataset.data;
      for (let i = 0; i < data.length; i++) {
        if (data[i] != null && data[i] > budgetData[i]) {
          if (firstOver === true) {
            firstOver = false;
            indexes.push(i);
          }
        } else {
          firstOver = true;
        }
      }
    }

    if (forecastTotalDataset != null) {
      let data = forecastTotalDataset.data;
      for (let i = 0; i < data.length; i++) {
        if (data[i] != null && data[i] > budgetData[i]) {
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
  return indexes;
}

window.addShutOffLines = function() {
  const shutOffLinesPlugin = {
    id: 'shutOffLinesPlugin',
    renderVerticalLine: function (chartInstance, pointIndex, text, number) {
      let meta = null;
      if(typeof simple_chart !== 'undefined' && chartInstance === simple_chart ||
         typeof chartInstance !== 'undefined' && chartInstance === cumulative_chart) {
        meta = chartInstance.getDatasetMeta(0);
      }  else {
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
      let position = 'left';
      if (pointIndex > chartInstance.data.labels.length / 2) position = 'right';
      context.textAlign = position;
      if(position === 'left') {
        text = "< " + text;
      } else {
        text += " >";
      }
      context.fillText(text, lineLeftOffset, (((scale.bottom - scale.top)/18) * number) + scale.top * 1.5);
    },

    afterDatasetsDraw: function (chart, easing) {
      if(chart.data.off != "undefined" && chart.data.off != null) {
        let index = 0;
        Object.keys(chart.data.off).sort().forEach((daysInFuture, i) => {
          if(daysInFuture < chart.data.labels.length) {
            chart.data.off[daysInFuture].forEach((text, j) => {
              this.renderVerticalLine(chart, daysInFuture, text, index);
              index += 1;
            });
          }
        });
      }
    }
  };

  Chart.register(shutOffLinesPlugin);
}
