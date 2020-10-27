/*global d3 */

var params = d3.select("#api_key");

if (!params.empty()) {
  var api_key = params.attr('data-api-key');
  var page = params.attr('data-page');
  if (page === null) { page = 1; }
  var per_page = params.attr('data-per-page');
  var contributor_id = params.attr('data-contributor-id');
  var source_id = params.attr('data-source-id');
  var contributor_role_id = params.attr('data-contributor-role-id');

  var query = encodeURI("/api/contributors/" + contributor_id + "/contributions?page=" + page);
  if (per_page !== null) { query += "&per_page=" + per_page; }
  if (source_id !== null) { query += "&source_id=" + source_id; }
   if (contributor_role_id !== null) { query += "&contributor_role_id=" + contributor_role_id; }
}

// asynchronously load data from the Lagotto API
queue()
  .defer(d3.json, encodeURI("/api/sources"))
  .defer(d3.json, encodeURI("/api/contributor_roles"))
  .defer(d3.json, encodeURI("/api/work_types"))
  .defer(d3.json, query)
  .await(function(error, s, cr, wt, c) {
    if (error) { return console.warn(error); }
    contributionsViz(c, s.sources, cr.contributor_roles, wt.work_types);
    paginate(c, "#content");
});

// add data to page
function contributionsViz(json, sources, contributor_roles, work_types) {
  data = json.contributions;

  json.href = "?page={{number}}";
  if (source_id !== "") { json.href += "&source_id=" + source_id; }

  d3.select("#loading-results").remove();

  if (typeof data === "undefined" || data.length === 0) {
    d3.select("#content").text("")
      .insert("div")
      .attr("class", "alert alert-info")
      .text("There are currently no contributions");
    return;
  }

  if (json.meta.total > 1) {
    d3.select("#content").insert("h4")
      .attr("class", "results")
      .text(numberWithDelimiter(json.meta.total) + " Contributions");
  }

  for (var i=0; i<data.length; i++) {
    var work = data[i];
    var contributor_role = contributor_roles.filter(function(d) { return d.id === work.contributor_role_id; })[0];
    if (typeof contributor_role === "undefined") { contributor_role = { "title": "Contribution" }};
    var source = sources.filter(function(d) { return d.id === work.source_id; })[0];

    d3.select("#content").insert("div")
      .attr("class", "panel panel-default")
      .attr("id", "panel-" + i).insert("div")
      .attr("class", "panel-body")
      .attr("id", "panel-body-" + i);

    d3.select("#panel-body-" + i).append("h4")
      .attr("class", "work")
      .append("a")
      .attr("href", function() { return "/works/" + pathForWork(work.obj_id); })
      .html(work.title);
    d3.select("#panel-body-" + i).append("div")
      .attr("class", "author")
      .html(formattedAuthorList(work.author));
    d3.select("#panel-body-" + i).append("div")
      .attr("class", "metadata")
      .html(metadataToString(work, work_types));
    d3.select("#panel-body-" + i).append("div")
      .attr("class", "contribution")
      .text(contributor_role.title);

    var signposts = signpostsFromWork(work, sources);
    if (typeof signposts !== "undefined" && signposts.length > 0)  {
      for (var j=0; j<signposts.length; j++) {
        d3.select("#panel-" + i).insert("div")
          .attr("class", "panel-footer")
          .attr("id", "panel-signpost-" + i + j).append("a")
          .attr("href", function() { return "/works/" + pathForWork(work.obj_id); })
          .text(signposts[j].count);
        d3.select("#panel-signpost-" + i + j).append("a")
          .attr("class", "pull-right")
          .attr("href", function() { return "/works?source_id=" + signposts[j].name; })
          .text(signposts[j].title);
      }
    }

    d3.select("#panel-" + i).insert("div")
      .attr("class", "panel-footer")
      .attr("id", "panel-footer-" + i).append("a")
      .attr("href", function() { return work.obj_id; })
      .html('<i class="fa fa-external-link"/>').append('span')
      .text(work.obj_id);
    d3.select("#panel-footer-" + i).append("a")
      .attr("class", "pull-right")
      .attr("href", function() { return "/contributors/" + pathForWork(work.subj_id) + "?source_id=" + work.source_id; })
      .text(source.title);
  }
}
