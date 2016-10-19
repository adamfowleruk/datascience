# Readme for the k Nearest Neighbour (kNN) UDF

This UDF performs k nearest neighbour search for a set of indexes, and provided sample values.

a kNN comparison involves looping over a set of 'treated' records, and for each treated record, loop over
the set of 'untreated' records, and find the best k matches (k typically between 1 and 5).

Any number of fields can be provided as the comparison fields. Typically it is at least 2, else a simple linear
regression can be used.

This UDF aims to perform the inner loop. I.e. given a set of fields and the values of those fields for one specific
'treated' record, loop over the untreated records and return the best k matches.

Note: This UDF requires range indexes over all fields used for comparison.

Note: This UDF requires the URI lexicon to be the first 'field' used, so as to provide a list of matches.

## Installation

Run make in the folder with the cpp and Makefile files. This generates a zip file for your UDF.

Then run the following in QConsole, substituting the folder for the location on MarkLogic Server
where the zip file is located:-

```xquery
xquery version "1.0-ml";
import module namespace plugin = "http://marklogic.com/extension/plugin" at "MarkLogic/plugin/plugin.xqy";
plugin:install-from-zip("native", xdmp:document-get("/mnt/hgfs/adamfowler/Documents/marklogic/git/datascience/udfs/cppknn/knn.zip")/node())
```

## Running the UDF

Against from QConsole, run something like the below:-

```xquery
xquery version "1.0-ml";
cts:aggregate(
  "native/knn",
  "knn",
  (
    cts:lexicon-reference(xs:QName("uri"),()), (: TODO validate this :)
    cts:element-reference(xs:QName("age"),()),
    cts:element-reference(xs:QName("iq"),())
  ),  ("/my/sample/doc.xml",13,143), ("fragment-frequency"),
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

The UDF configuration above requires a two double range indexes over the fields to be compared, and the URI lexicon
to be enabled.
