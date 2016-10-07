# Readme for the logistic regression UDF

This UDF performs a logistic regression over exactly 2 range indexed fields of type double.

Note: This should not be confused with linear-log aka logarithmic regression in the cpplnregudf example.

## Installation

Run make in the folder with the cpp and Makefile files. This generates a zip file for your UDF.

Then run the following in QConsole, substituting the folder for the location on MarkLogic Server 
where the zip file is located:-

```xquery
xquery version "1.0-ml";
import module namespace plugin = "http://marklogic.com/extension/plugin" at "MarkLogic/plugin/plugin.xqy";
plugin:install-from-zip("native", xdmp:document-get("/mnt/hgfs/adamfowler/Documents/marklogic/git/mlcplusplus/release/samples/cpplogregudf/logreg.zip")/node())
```

## Running the UDF

Against from QConsole, run something like the below:-

```xquery
xquery version "1.0-ml";
cts:aggregate(
  "native/logreg",
  "logreg",
  (
    cts:element-reference(xs:QName("age"),()),
    cts:element-reference(xs:QName("iq"),())
  ),  (), ("fragment-frequency"), 
  cts:collection-query("zoo")
)
```

Note the above example assumes JSON data like the following, in the 'zoo' collection:-

```json
{
"name": "Fred", 
"summary": "Big scary cat", 
"age": 30, 
"animal": "Tiger",
"iq": 123, 
"family": "Flintstones"
}
```

The UDF requires a two double range indexes over the fields to be compared.
