var heatmap_data;

//var colorScale;
//var colors = colorbrewer.YlGnBu[9];  //["#ffffd9","#edf8b1","#c7e9b4","#7fcdbb","#41b6c4","#1d91c0","#225ea8","#253494","#081d58"]; // alternatively colorbrewer.YlGnBu[9]
var heatMap = d3.select("#heatmap").selectAll(".col");


function set_heatmap_data(data){
    heatmap_data = data;
}


function update_heatmap(values) {
    var colorScale = d3.scale.quantile()
        .domain(values)
        .range(colors);
    heatMap.style("fill", function (d) {
        //console.log("cell value: " + d.value);
        return colorScale(d.value);
    });
}
function draw_heatmap(data) {
    set_heatmap_data(data);
    var rows = new Array(),
        cols = new Array(),
        col_labels = new Array(),
        row_labels= new Array();
    $j.each(data, function (i, json) {
        $j.each(json, function (key, val) {
            if (key === "row" && rows.indexOf(val) === -1) {
                if (val === 0 && col_labels.indexOf(val) === -1) {
                    col_labels.push(json.value);
                    //remove first row-header
                    data = $j.grep(data, function (jjson) {
                        return jjson != json
                    });
                    //data.splice(i,1)
                } else {
                    rows.push(val);
                    row_labels.push(json["row_label"]);
                }
            }
            if (key === "col" && cols.indexOf(val) === -1) {
                cols.push(val)
            }
        });
    });
    var margin = { top: 10, right: 0, bottom: 100, left: 100 },
        gridSize = 38,
        legendElementWidth = gridSize * 2,
        buckets = 3,
        legendWidth = legendElementWidth * buckets,
        allGridWidth = gridSize * cols.length,
        heatMapWidth = allGridWidth < legendWidth ? legendWidth : allGridWidth,
        heatMapHeight = gridSize * rows.length,
        width = heatMapWidth + margin.left + margin.right,
        height = heatMapHeight + margin.top + margin.bottom;


    //remove old svg
    d3.select("svg.grid")
        .remove();
    var svg = d3.select("#heatmap").append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .attr("class", "grid")
        .append("g")
        .attr("id", "heatmap_matrix")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ") " + "scale(1,1)");

    var rowLabels = svg.selectAll(".rowLabel")
       .data(row_labels)
        .enter().append("text")
        .text(function (d) {
            return d;
        })
        .attr("x", 0)
        .attr("y", function (d, i) {
            return (i + 1.5) * gridSize;
        })
        .style("text-anchor", "end")
        .attr("transform", "translate(-6," + gridSize / 1.5 + ")")
        .attr("class", function (d, i) {
            return ((i >= 0 && i <= rows.length) ? "rowLabel mono axis axis-workweek" : "rowLabel mono axis");
        })
        .append("title")
         .text(function(d,i){
           return  d;
            });

    var colLabels = svg.selectAll(".colLabel")
        //.data(col_labels)
        .data(cols)
        .enter().append("text")
        .text(function (d) {
            return "Col_" + num2alpha(d);
        })
        .attr("x", function (d, i) {
            return (i) * gridSize;
        })
        .attr("y", 1 * gridSize)

        .style("text-anchor", "middle")
        .attr("transform", "translate(" + gridSize / 2 + ", -6)")
        .attr("class", "colLabel mono axis axis-worktime")
        .append("title")
        .text(function(d,i){
            return  "Column "+ num2alpha(d) + ": "+col_labels[i];
        });
//        .attr("dy",".78em")
//        .call(wrap, x.rangeBand());


     heatMap = svg.selectAll(".col")
        .data(data)
        .enter().append("rect")
        .attr("x", function (d) {
            return (cols.indexOf(d.col)) * gridSize;
        }) //d.col >0? d.col-1 : 1
        .attr("y", function (d) {
            return (rows.indexOf(d.row) + 1.5) * gridSize;
        })
        .attr("rx", 4)
        .attr("ry", 4)
        .attr("class", "col bordered")
        .attr("width", gridSize)
        .attr("height", gridSize)
        .style("fill", colors[0]);


   var min =  d3.min(data, function (d) {
        return parseFloat(d.value);
    }),
       max = d3.max(data, function (d) {
        return parseFloat(d.value);
    });

    //$j('#slide1').slider("option",{min: (Number(min.toFixed(1))-0.1), max: (Number(max.toFixed(1))+0.1)});
    //$j("#slide1").slider('values',0,min+1); // sets first handle (index 0) to 50
    //$j("#slide1").slider('values',1,max-1);
    //doUpdate();
    update_heatmap( $j('#slide1').slider.limits());

    heatMap.append("title").text(function (d,i) {

        return (d.row_label + "( " + col_labels[i%col_labels.length] + ": " + d.value) +" )";
    });


}

function draw_slider(){
    // script for slider
    //var margin = {top: 200, right: 50, bottom: 200, left: 50},
    var margin = {top: 2, right: 5, bottom: 2, left: 20},
        width = 850 - margin.left - margin.right,
        height = 50 - margin.bottom - margin.top;

    var x = d3.scale.linear()
        .domain([0, 100])
        .range([0, width])
        .clamp(true);

    var brush = d3.svg.brush()
        .x(x)
        .extent([0, 0])
        .on("brush", brushed);

    d3.select("svg.slider")
        .remove();

    var svg = d3.select("#slider").append("svg")
        .attr("width", width + margin.left + margin.right+30)
        .attr("height", height + margin.top + margin.bottom)
        .attr("class", "slider")
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height / 2 + ")")
        .call(d3.svg.axis()
            .scale(x)
            .orient("bottom")
            .tickFormat(function(d) { return d+"%"; })
            .tickSize(0)
            .tickPadding(12))
        .select(".domain")
        .select(function() { return this.parentNode.appendChild(this.cloneNode(true)); })
        .attr("class", "halo");

    var slider = svg.append("g")
        .attr("class", "slider")
        .call(brush);

    slider.selectAll(".extent,.resize")
        .remove();

    slider.select(".background")
        .attr("height", height);

    var handle = slider.append("circle")
        .attr("class", "handle")
        .attr("transform", "translate(0," + height / 2 + ")")
        .attr("r", 9);

    slider.call(brush.event)
        .transition() // gratuitous intro!
        .duration(750)
        .call(brush.extent([70, 70]))
        .call(brush.event);

    function brushed() {
        var value = brush.extent()[0];

        if (d3.event.sourceEvent) { // not a programmatic event
            value = x.invert(d3.mouse(this)[0]);
            brush.extent([value, value]);
        }
        console.log(" brush value: "+ value)
        filter_heatmap_data(value);
        handle.attr("cx", x(value));
        //d3.select("#slider").style("background-color", d3.hsl(value, .8, .8));
        //colorHigh = d3.hsl(value, .8, .8);
    }
}
function filter_heatmap_data(threshold){

    var filtered_data = new Array();
   for(var i in heatmap_data){
     var value = parseFloat(heatmap_data[i]["value"]);
       //console.log("value: "+ value + ", threshold: "+ threshold)
     if(value != NaN && value <= parseFloat(threshold)){
         filtered_data.push(heatmap_data[i]);
     }
   }
   // console.log(filtered_data)
   draw_heatmap(filtered_data)
}
function wrap(text, width) {
    console.log("text=" + text + ", width=" + width)
    text.each(function () {
        console.log(d3.select(this))
        var text = d3.select(this),
            words = text.text().split(/\s+/).reverse(),
            word,
            line = [],
            lineNumber = 0,
            lineHeight = 1.1, // ems
            x = text.attr("x"),
            y = text.attr("y"),
            dy = parseFloat(text.attr("dy")),
            tspan = text.text(null).append("tspan").attr("x", x).attr("y", y).attr("dy", dy + "em");
        while (word = words.pop()) {
            line.push(word);
            tspan.text(line.join(" "));
            console.log("compute text length: " + tspan.node().getComputedTextLength())
            console.log("width: " + width)
            if (tspan.node().getComputedTextLength() > width) {
                line.pop();
                tspan.text(line.join(" "));
                line = [word];
                tspan = text.append("tspan").attr("x", 0).attr("y", y).attr("dy", ++lineNumber * lineHeight + dy + "em").text(word);
            }
        }
    });
}


