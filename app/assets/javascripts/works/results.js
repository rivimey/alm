/**
 * ALMViz
 * See https://github.com/lagotto/almviz for more details
 * Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
 *
 * @brief Article level metrics visualization controller.
 */

/*global d3 */

var options = {
  baseUrl: '',
  minItemsToShowGraph: {
    minEventsForYearly: 1,
    minEventsForMonthly: 1,
    minEventsForDaily: 1,
    minYearsForYearly: 1,
    minMonthsForMonthly: 1,
    minDaysForDaily: 1
  },
  vizDiv: "#panel-results",
  work: {},
  sources: [],
  groups: []
};

var params = d3.select("#api_key");
if (!params.empty()) {
  var api_key = params.attr('data-api-key');
  var work_id = params.attr('data-pid');
  var query = encodeURI("/api/works/" + pathForWork(work_id) + "/results");
}

// asynchronously load data from the Lagotto API
queue()
  .defer(d3.json, encodeURI("/api/works/" + pathForWork(work_id)))
  .defer(d3.json, encodeURI("/api/sources"))
  .defer(d3.json, encodeURI("/api/groups"))
  .defer(d3.json, query)
  .await(function(error, w, s, g, r) {
    if (error) { return console.warn(error); }
    options.work = w.work;
    options.sources = s.sources;
    options.groups = g.groups;
    options.almStatsJson = r.results;
    var almviz = new AlmViz(options);
    almviz.initViz();
});

function AlmViz(options) {
  // allow jQuery object to be passed in
  // in case a different version of jQuery is needed from the one globally defined
  $ = options.jQuery || $;

  // Init data
  // remove group not needed for the following visualizations
  var work_ = options.work;
  var groups_ = options.groups.filter(function(d) { return d.id !== "other"; });
  var sources_ = options.sources;
  var data = options.almStatsJson;

  // Abort if data are missing
  if (!data || !data[0]) {
    console.log('Error: missing data');

    d3.select("#loading-results").remove();

    d3.select("#content-results").text("")
      .insert("div")
      .attr("class", "alert alert-info")
      .text("There are currently no results");
    return;
  }

  // Init basic options
  var baseUrl_ = options.baseUrl;
  var minItems_ = options.minItemsToShowGraph;
  var formatNumber_ = d3.format(",d");

  // extract publication date
  // Construct date object from date parts, using "1" for missing day and month
  var timestamp = Date.parse(work_["issued"]);
  if (work_["issued"] === "0000") { timestamp = Date.parse("2000"); }
  var pub_date = new Date(timestamp);

  var vizDiv;
  // Get the Div where the viz should go (default to one with ID "alm')
  if (options.vizDiv) {
    vizDiv = d3.select(options.vizDiv);
  } else {
    vizDiv = d3.select("#alm");
  }

  // look to make sure browser support SVG
  var hasSVG_ = document.implementation.hasFeature("http://www.w3.org/TR/SVG11/feature#BasicStructure", "1.1");

  // to track if any metrics have been found
  var metricsFound_;

  /**
   * Initialize the visualization.
   * NB: needs to be accessible from the outside for initialization
   */
  this.initViz = function() {
    vizDiv.select("#loading-results").remove();

    // loop through groups
    groups_.forEach(function(group) {
      addGroup_(vizDiv, group, sources_, data);
    });

    if (!metricsFound_) {
      vizDiv.append("p")
        .attr("class", "text-muted")
        .text("No results found.");
    }
  };

  /**
   * Build each article level statistics group.
   * @param {Object} canvas d3 element
   * @param {Array} group Information about the group.
   * @param {Object} data Statistics.
   * @return {JQueryObject|boolean}
   */
  var addGroup_ = function(canvas, group, sources_, data) {
    var $groupRow = false;

    // Loop through sources to add statistics data to the group.
    sources_.forEach(function(source) {
      if (source.group_id !== group.id) { return; }

      results = data.filter(function(d) { return d.source_id === source.id; })[0];
      if (typeof results === "undefined" || results.total === 0) { return; }

      // Only add the group row the first time
      if (!$groupRow) {
        $groupRow = getgroupRow_(canvas, group);
      }

      // Flag that there is at least one metric
      metricsFound_ = true;

      var label = source.title;
      addSource_(source, label, results, results.total, group, "total", $groupRow);
    });
  };


  /**
   * Get group row d3 HTML element. It will automatically
   * add the element to the passed canvas.
   * @param {d3Object} canvas d3 HTML element
   * @param {Array} group group information.
   * @param {d3Object}
   */
  var getgroupRow_ = function(canvas, group) {
    var groupRow, groupTitle, tooltip;

    // Build group html objects.
    groupRow = canvas.append("div")
      .attr("class", "alm-group")
      .attr("id", "group-" + group.id);

    return groupRow;
  };


  /**
   * Add source information to the passed group row element.
   * @param {Object} source
   * @param {integer} sourceTotalValue
   * @param {Object} group
   * @param {JQueryObject} $groupRow
   * @return {JQueryObject}
   */
  var addSource_ = function(source, label, results, sourceTotalValue, group, subgroup, $groupRow) {
    var $row, $countLabel, $count,
        total = sourceTotalValue;

    $row = $groupRow
      .append("div")
      .attr("class", "alm-source")
      .attr("id", "source-" + source.id + "-" + subgroup);
    $countLabel = $row.append("div")
      .attr("class", "alm-label " + group.id);
    $count = $countLabel.append("p")
      .attr("class", "alm-count")
      .attr("id", "alm-count-" + source.id + "-" + group.id);
    $count
      .text(formatNumber_(total));

    if (source.id === 'pkpTimedViews') {
      $countLabel.append("p")
        .text(label);
    } else {
      // link the source name
      $countLabel.append("p").append("a")
        .attr("href", baseUrl_ + "/sources/" + source.id)
        .text(label);
    }

    // Only add a chart if the browser supports SVG
    if (hasSVG_) {
      var level = false;

      // check what levels we can show
      var showDaily = false;
      var showMonthly = false;
      var showYearly = false;

      if (results.by_year) {
        var level_data = getData_('year', results);
        var yearTotal = level_data.reduce(function(i, d) { return i + d[subgroup]; }, 0);
        var numYears = d3.time.year.utc.range(pub_date, new Date()).length;

        if (yearTotal >= minItems_.minEventsForYearly &&
          numYears >= minItems_.minYearsForYearly) {
          showYearly = true;
          level = 'year';
        }
      }

      if (results.by_month) {
        var level_data = getData_('month', results);
        var monthTotal = level_data.reduce(function(i, d) { return i + d[subgroup]; }, 0);
        var numMonths = d3.time.month.utc.range(pub_date, new Date()).length;

        if (monthTotal >= minItems_.minEventsForMonthly &&
            numMonths >= minItems_.minMonthsForMonthly) {
            showMonthly = true;
            level = 'month';
        }
      }

      // The level and level_data should be set to the finest level
      // of granularity that we can show
      timeInterval = getTimeInterval_(level);

      // check there is data for
      if (showDaily || showMonthly || showYearly) {
        $row
          .attr('class', 'alm-source with-chart');

        var $chartDiv = $row.append("div")
          .attr("class", "alm-chart");

        var viz = getViz_($chartDiv, source, group, subgroup, results);
        loadData_(viz, level);

        var update_controls = function(control) {
            control.siblings('.alm-control').removeClass('active');
            control.addClass('active');
        };

        var $levelControlsDiv = $chartDiv.append("div")
          .attr("class", "alm-control-label")
          .attr("style", "width: " + (viz.margin.left + viz.width) + "px;");

        if (showDaily) {
          $levelControlsDiv.append("a")
            .attr("href", "javascript:void(0)")
            .classed("alm-control", true)
            .classed("disabled", !showDaily)
            .classed("active", (level === 'day'))
            .text("daily (first 30)")
            .on("click", function() {
              if (showDaily && !$(this).hasClass('active')) {
                loadData_(viz, 'day');
                update_controls($(this));
              }
            }
          );

          $levelControlsDiv.append("text").text(" | ");
        }

        if (showMonthly) {
          $levelControlsDiv.append("a")
            .attr("href", "javascript:void(0)")
            .classed("alm-control", true)
            .classed("disabled", !showMonthly || !showYearly)
            .classed("active", (level === 'month'))
            .text("monthly")
            .on("click", function() { if (showMonthly && !$(this).hasClass('active')) {
              loadData_(viz, 'month');
              update_controls($(this));
            } });

          if (showYearly) {
            $levelControlsDiv.append("text")
              .text(" | ");
          }

        }

        if (showYearly) {
          $levelControlsDiv.append("a")
            .attr("href", "javascript:void(0)")
            .classed("alm-control", true)
            .classed("disabled", !showYearly || !showMonthly)
            .classed("active", (level === 'year'))
            .text("yearly")
            .on("click", function() {
              if (showYearly && !$(this).hasClass('active')) {
                loadData_(viz, 'year');
                update_controls($(this));
              }
            }
          );
        }
      }
    }

    return $row;
  };


  /**
   * Extract the date from the source
   * @param level (day|month|year)
   * @param d the datum
   * @return {Date}
   */
  var getDate_ = function(level, d) {
    switch (level) {
      case 'year':
        return new Date(d.year, 0, 1);
      case 'month':
        // js Date indexes months at 0
        return new Date(d.year, d.month - 1, 1);
      case 'day':
        // js Date indexes months at 0
        return new Date(d.year, d.month - 1, d.day);
    }
  };


  /**
   * Format the date for display
   * @param level (day|month|year)
   * @param d the datum
   * @return {String}
   */
  var getFormattedDate_ = function(level, d) {
    switch (level) {
      case 'year':
        return d3.time.format("%Y")(getDate_(level, d));
      case 'month':
        return d3.time.format("%b %y")(getDate_(level, d));
      case 'day':
        return d3.time.format("%d %b %y")(getDate_(level, d));
    }
  };


  /**
   * Extract the data from the source.
   * @param {string} level (day|month|year)
   * @param {Object} source
   * @return {Array} Metrics
   */
  var getData_ = function(level, results) {
    switch (level) {
      case 'year':
        return results.by_year;
      case 'month':
        return results.by_month;
    }
  };

  /**
   * Returns a d3 timeInterval for date operations.
   * @param {string} level (day|month|year
   * @return {Object} d3 time Interval
   */
  var getTimeInterval_ = function(level) {
    switch (level) {
      case 'year':
        return d3.time.year.utc;
      case 'month':
        return d3.time.month.utc;
      case 'day':
        return d3.time.day.utc;
    }
  };

  /**
   * The basic general set up of the graph itself
   * @param {JQueryElement} chartDiv The div where the chart should go
   * @param {Object} source
   * @param {Array} group The group for 86 chart
   * @return {Object}
   */
  var getViz_ = function(chartDiv, source, group, subgroup, results) {
    var viz = {};

    // size parameters
    viz.margin = {top: 10, right: 20, bottom: 5, left: 50};
    viz.width = 760 - viz.margin.left - viz.margin.right;
    viz.height = 115 - viz.margin.top - viz.margin.bottom;

    // div where everything goes
    viz.chartDiv = chartDiv;

    // source data and which group
    viz.group = group;
    viz.subgroup = subgroup;
    viz.source = source;
    viz.results = results;

    // just for record keeping
    viz.name = source.id + '-' + group.id + '-' + viz.subgroup;

    viz.x = d3.time.scale();
    viz.x.range([0, viz.width]);

    viz.y = d3.scale.linear();
    viz.y.range([viz.height, 0]);

    viz.z = d3.scale.ordinal();
    viz.z.range([group.id, group.id + '-alt']);

    // the chart
    viz.svg = viz.chartDiv.append("svg")
      .attr("width", viz.width + viz.margin.left + viz.margin.right)
      .attr("height", viz.height + viz.margin.top + viz.margin.bottom + 1)
      .append("g")
      .attr("transform", "translate(" + viz.margin.left + "," + viz.margin.top + ")");

    // draw the bars g first so it ends up underneath the axes
    viz.bars = viz.svg.append("g");

    // and the shadow bars on top for the tooltips
    viz.barsForTooltips = viz.svg.append("g");

    viz.svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + viz.height + ")");

    viz.svg.append("g")
      .attr("class", "y axis");

    return viz;
  };


  /**
   * Takes in the basic set up of a graph and loads the data itself
   * @param {Object} viz AlmViz object
   * @param {string} level (day|month|year)
   */
  var loadData_ = function(viz, level) {
    var group = viz.group;
    var subgroup = viz.subgroup;
    var level_data = getData_(level, viz.results);
    var timeInterval = getTimeInterval_(level);

    var end_date = new Date();
    // use only first 29 days if using day view
    // close out the year otherwise
    if (level === 'day') {
      end_date = timeInterval.offset(pub_date, 29);
    } else {
      end_date = d3.time.year.utc.ceil(end_date);
    }

    //
    // Domains for x and y
    //
    // a time x axis, between pub_date and end_date
    viz.x.domain([timeInterval.floor(pub_date), end_date]);

    // a linear axis from 0 to max value found
    viz.y.domain([0, d3.max(level_data, function(d) { return d[subgroup]; })]);

    //
    // Axis
    //
    // a linear axis between publication date and current date
    viz.xAxis = d3.svg.axis()
      .scale(viz.x)
      .tickSize(0)
      .ticks(0);

    // a linear y axis between 0 and max value found in data
    viz.yAxis = d3.svg.axis()
      .scale(viz.y)
      .orient("left")
      .tickSize(0)
      .tickValues([d3.max(viz.y.domain())])   // only one tick at max
      .tickFormat(d3.format(",d"));

    //
    // The chart itself
    //

    // TODO: these transitions could use a little work

    // add more padding to wider bars
    var rawWidth = (viz.width/(timeInterval.range(pub_date, end_date).length + 1));
    var barWidth = Math.max(rawWidth - rawWidth/5, 1);

    var barsForTooltips = viz.barsForTooltips.selectAll(".barsForTooltip")
      .data(level_data, function(d) { return getDate_(level, d); });

    barsForTooltips
      .exit()
      .remove();

    var bars = viz.bars.selectAll(".bar")
      .data(level_data, function(d) { return getDate_(level, d); });

    bars
      .enter().append("rect")
      .attr("class", function(d) { return "bar " + viz.z((level === 'day' ? d3.time.weekOfYear(getDate_(level, d)) : d.year)); })
      .attr("y", viz.height)
      .attr("height", 0);

    bars
      .attr("x", function(d) { return viz.x(getDate_(level, d)) + 2; })
      .attr("width", barWidth);

    bars.transition()
      .duration(1000)
      .attr("width", barWidth)
      .attr("y", function(d) { return viz.y(d[subgroup]); })
      .attr("height", function(d) { return viz.height - viz.y(d[subgroup]); });

    bars
      .exit().transition()
      .attr("y", viz.height)
      .attr("height", 0);

    bars
      .exit()
      .remove();

    viz.svg
      .select(".x.axis")
      .call(viz.xAxis);

    viz.svg
      .transition().duration(1000)
      .select(".y.axis")
      .call(viz.yAxis);

    barsForTooltips
      .enter().append("rect")
      .attr("class", function(d) { return "barsForTooltip " + viz.z((level === 'day' ? d3.time.weekOfYear(getDate_(level, d)) : d.year)); });

    barsForTooltips
      .attr("width", barWidth + 2)
      .attr("x", function(d) { return viz.x(getDate_(level, d)) + 1; })
      .attr("y", function(d) { return viz.y(d[subgroup]) - 1; })
      .attr("height", function(d) { return viz.height - viz.y(d[subgroup]) + 1; });

    // add in some tool tips
    viz.barsForTooltips.selectAll("rect").each(
      function(d){
        $(this).tooltip('destroy'); // need to destroy so all bars get updated
        $(this).tooltip({title: formatNumber_(d[subgroup]) + " in " + getFormattedDate_(level, d), container: "body"});
      }
    );
  };
}
