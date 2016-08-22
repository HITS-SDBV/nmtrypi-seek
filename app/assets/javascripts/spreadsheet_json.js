
/*
 Input: json object which might have the "selected" attribute on <cell> records
 Output: json_object with the title row + all selected cells. object structure is kept.
 */
function get_selected_json(json_obj) {
    if ((workbook_arr = json_obj["workbook"]) != null) {
        var sheet_arr = [];
        //Workbook objects loop
        for (var w = 0; w < workbook_arr.length; w++) {
            if ((sheet_arr = workbook_arr[w]["sheet"]) != null) {
                //Sheet objects loop
                for (var s =0; s<sheet_arr.length; s++) {
                    console.log("in sheet: ", s)
                    if (sheet_arr[s].rows.row != null) {
                        //Rows loop 1
                        for (var r = 0 ; r < sheet_arr[s].rows["@last_row"]; r++) {
                            //descending order to enable quick and painless deletions.
                            var cell_arr_len = sheet_arr[s].rows.row[r].cell.length -1
                            ///Cell loop to filter selections
                            for (var c = cell_arr_len; c > -1; c--) {
                                if (!sheet_arr[s].rows.row[r].cell[c]["@selected"]) {
                                    //if (s == 0)
                                       //console.log("removing in sheet, row, cell", s, r,c)
                                    json_obj["workbook"][w]["sheet"][s].rows.row[r].cell.splice(c, 1)
                                }
                            }
                        }
                    }
                } //End Sheet loop
            }
        } // End Workbook loop
    }
    return json_obj;
}

/*
 Input: json object, workbook number, sheet number
 Output: json_object with added "selected" attributes on cells
 */
function add_selected_to_json(json_obj, wb=0) {
    var selected = $j(".selected_cell")
    for (var sel=0; sel<selected.length; sel++) {
        var row = selected[sel].attributes.row.value-1;
        var col = selected[sel].attributes.col.value-1;
        var sheet = selected[sel].ancestors()[3].id.split('_')[1]-1;
        json_obj["workbook"][wb]["sheet"][sheet].rows.row[row].cell[col]["@selected"] = "1";
    }
    return json_obj;
}

/*
 Merge JSON objects
 Input: array of JSON objects with workbook as top level
        obj = {workbook: [...]}
 Output: merged json object with the joint array of workbooks
 */
function merge_json_workbooks(json_wb_obj_array) {
    var super_obj = [];
    for (var i in json_wb_obj_array) {
        if (json_wb_obj_array[i]["workbook"] != null)
            super_obj = super_obj.concat(json_wb_obj_array[i]["workbook"]);
    }
    return {workbook: super_obj};
}

/*
 GET XML data file
  TO DO: worry about credentials?
 */
function get_xml_file(url) {
    var connect;
    if (window.XMLHttpRequest) connect = new XMLHttpRequest(); 		// all browsers except IE
    else connect = new ActiveXObject("Microsoft.XMLHTTP"); 		// for IE
    console.log(connect);

    /* (async: false) makes it a synchronous request, bringing up a warning (deprecated).
       (async: true) fails because we don't get the answer on time.
       in principle works if all request-dependent actions were done here, by defining:
       connect.onreadystatechange = function() {
            if (connect.readyState === 4 && connect.status === 200) {
              //do everything
            .....} }; (essentially forcing it to be synchronious)
        but currently, plotting is done outside, and we need to wait.
    */
    connect.open('GET', url, false); //async: false
    connect.setRequestHeader("Content-Type", "text/xml");
    connect.send(null);
    if (connect.readyState === 4 && connect.status === 200) {
        var xmlDocument = connect.responseXML;
        console.log("read with http request: ", xmlDocument);
        return xmlDocument;
    } else {
        console.log("Error in getting XML file, readyState, status: ", connect.readyState, connect.status);
    }

}

/*
 Other functions expect all sheets to be in a sheet array under workbook.
 If there is only one sheet, the array might not exist and instead we get a single sheet object.
*/
function fix_sheet_in_json(json_obj) {
    console.log(json_obj);
    var sheets = json_obj["sheet"];
    if (! Array.isArray(sheets)) {
        json_obj["sheet"] = [sheets];
    }
    return json_obj;
}
//http://goessner.net/download/prj/jsonxml/
/*	This work is licensed under Creative Commons GNU LGPL License.

 License: http://creativecommons.org/licenses/LGPL/2.1/
 Version: 0.9
 Author:  Stefan Goessner/2006
 Web:     http://goessner.net/
 */
function xml2json(xml, tab) {
    var X = {
        toObj: function(xml) {
            var o = {};
            if (xml.nodeType==1) {   // element node ..
                if (xml.attributes.length)   // element with attributes  ..
                    for (var i=0; i<xml.attributes.length; i++)
                        o["@"+xml.attributes[i].nodeName] = (xml.attributes[i].nodeValue||"").toString();
                if (xml.firstChild) { // element has child nodes ..
                    var textChild=0, cdataChild=0, hasElementChild=false;
                    for (var n=xml.firstChild; n; n=n.nextSibling) {
                        if (n.nodeType==1) hasElementChild = true;
                        else if (n.nodeType==3 && n.nodeValue.match(/[^ \f\n\r\t\v]/)) textChild++; // non-whitespace text
                        else if (n.nodeType==4) cdataChild++; // cdata section node
                    }
                    if (hasElementChild) {
                        if (textChild < 2 && cdataChild < 2) { // structured element with evtl. a single text or/and cdata node ..
                            X.removeWhite(xml);
                            for (var n=xml.firstChild; n; n=n.nextSibling) {
                                if (n.nodeType == 3)  // text node
                                    o["#text"] = X.escape(n.nodeValue);
                                else if (n.nodeType == 4)  // cdata node
                                    o["#cdata"] = X.escape(n.nodeValue);
                                else if (o[n.nodeName]) {  // multiple occurence of element ..
                                    if (o[n.nodeName] instanceof Array)
                                        o[n.nodeName][o[n.nodeName].length] = X.toObj(n);
                                    else
                                        o[n.nodeName] = [o[n.nodeName], X.toObj(n)];
                                }
                                else  // first occurence of element..
                                    o[n.nodeName] = X.toObj(n);
                            }
                        }
                        else { // mixed content
                            if (!xml.attributes.length)
                                o = X.escape(X.innerXml(xml));
                            else
                                o["#text"] = X.escape(X.innerXml(xml));
                        }
                    }
                    else if (textChild) { // pure text
                        if (!xml.attributes.length)
                            o = X.escape(X.innerXml(xml));
                        else
                            o["#text"] = X.escape(X.innerXml(xml));
                    }
                    else if (cdataChild) { // cdata
                        if (cdataChild > 1)
                            o = X.escape(X.innerXml(xml));
                        else
                            for (var n=xml.firstChild; n; n=n.nextSibling)
                                o["#cdata"] = X.escape(n.nodeValue);
                    }
                }
                if (!xml.attributes.length && !xml.firstChild) o = null;
            }
            else if (xml.nodeType==9) { // document.node
                o = X.toObj(xml.documentElement);
            }
            else
                alert("unhandled node type: " + xml.nodeType);
            return o;
        },
        toJson: function(o, name, ind) {
            var json = name ? ("\""+name+"\"") : "";
            if (o instanceof Array) {
                for (var i=0,n=o.length; i<n; i++)
                    o[i] = X.toJson(o[i], "", ind+"\t");
                json += (name?":[":"[") + (o.length > 1 ? ("\n"+ind+"\t"+o.join(",\n"+ind+"\t")+"\n"+ind) : o.join("")) + "]";
            }
            else if (o == null)
                json += (name&&":") + "null";
            else if (typeof(o) == "object") {
                var arr = [];
                for (var m in o)
                    arr[arr.length] = X.toJson(o[m], m, ind+"\t");
                json += (name?":{":"{") + (arr.length > 1 ? ("\n"+ind+"\t"+arr.join(",\n"+ind+"\t")+"\n"+ind) : arr.join("")) + "}";
            }
            else if (typeof(o) == "string")
                json += (name&&":") + "\"" + o.toString() + "\"";
            else
                json += (name&&":") + o.toString();
            return json;
        },
        innerXml: function(node) {
            var s = ""
            if ("innerHTML" in node)
                s = node.innerHTML;
            else {
                var asXml = function(n) {
                    var s = "";
                    if (n.nodeType == 1) {
                        s += "<" + n.nodeName;
                        for (var i=0; i<n.attributes.length;i++)
                            s += " " + n.attributes[i].nodeName + "=\"" + (n.attributes[i].nodeValue||"").toString() + "\"";
                        if (n.firstChild) {
                            s += ">";
                            for (var c=n.firstChild; c; c=c.nextSibling)
                                s += asXml(c);
                            s += "</"+n.nodeName+">";
                        }
                        else
                            s += "/>";
                    }
                    else if (n.nodeType == 3)
                        s += n.nodeValue;
                    else if (n.nodeType == 4)
                        s += "<![CDATA[" + n.nodeValue + "]]>";
                    return s;
                };
                for (var c=node.firstChild; c; c=c.nextSibling)
                    s += asXml(c);
            }
            return s;
        },
        escape: function(txt) {
            return txt.replace(/[\\]/g, "\\\\")
                .replace(/[\"]/g, '\\"')
                .replace(/[\n]/g, '\\n')
                .replace(/[\r]/g, '\\r');
        },
        removeWhite: function(e) {
            e.normalize();
            for (var n = e.firstChild; n; ) {
                if (n.nodeType == 3) {  // text node
                    if (!n.nodeValue.match(/[^ \f\n\r\t\v]/)) { // pure whitespace text node
                        var nxt = n.nextSibling;
                        e.removeChild(n);
                        n = nxt;
                    }
                    else
                        n = n.nextSibling;
                }
                else if (n.nodeType == 1) {  // element node
                    X.removeWhite(n);
                    n = n.nextSibling;
                }
                else                      // any other node
                    n = n.nextSibling;
            }
            return e;
        }
    };
    if (xml.nodeType == 9) // document node
        xml = xml.documentElement;

    return fix_sheet_in_json(X.toObj(X.removeWhite(xml)));
    //the following will return a json string
    //var json = X.toJson(X.toObj(X.removeWhite(xml)), xml.nodeName, "\t");
    //return "{\n" + tab + (tab ? json.replace(/\t/g, tab) : json.replace(/\t|\n/g, "")) + "\n}";
}

// Converts XML to JSON
// shorter and cleaner - but need to change it to remove empty text elements. 
//var jsonText = JSON.stringify(xmlToJson(xmlDoc));
function xmlToJson(xml) {

    // Create the return object
    var obj = {};

    if (xml.nodeType == 1) { // element
        // do attributes
        if (xml.attributes.length > 0) {
            obj["@attributes"] = {};
            for (var j = 0; j < xml.attributes.length; j++) {
                var attribute = xml.attributes.item(j);
                obj["@attributes"][attribute.nodeName] = attribute.nodeValue;
            }
        }
    } else if (xml.nodeType == 3) { // text
        obj = xml.nodeValue;
    }

    // do children
    if (xml.hasChildNodes()) {
        for(var i = 0; i < xml.childNodes.length; i++) {
            var item = xml.childNodes.item(i);
            var nodeName = item.nodeName;
            if (typeof(obj[nodeName]) == "undefined") {
                obj[nodeName] = xmlToJson(item);
            } else {
                if (typeof(obj[nodeName].push) == "undefined") {
                    var old = obj[nodeName];
                    obj[nodeName] = [];
                    obj[nodeName].push(old);
                }
                obj[nodeName].push(xmlToJson(item));
            }
        }
    }
    return obj;
}
