xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/knn";

import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace knn="http://marklogic.com/datascience/nn-k" at "/datascience/nn-k.xqy";

import module namespace config-query = "http://marklogic.com/rest-api/models/config-query"
    at "/MarkLogic/rest-api/models/config-query-model.xqy";
import module namespace search="http://marklogic.com/appservices/search"
    at "/MarkLogic/appservices/search/search.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare namespace rapi = "http://marklogic.com/rest-api";


(:
 : Get the description of this stored procedure, its parameters, and return values
 :  ?BLANK
 :)
declare
%roxy:params("")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  let $preftype :=
    if (fn:not(fn:empty(map:get($params,"format")))) then
      if ("json" = map:get($params,"format")) then
        "application/json"
      else
        "application/xml"
    else
      if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  (: if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json" :)
  let $_ := xdmp:log("knn REST extension called")
  let $out := <output>
    <result><name>k</name><reference>IN</reference><type>xs:int</type><cardinality>1</cardinality></result>
    <result><name>collection</name><reference>IN</reference><type>xs:uri</type><cardinality>1</cardinality></result>
    <result><name>treatedQuery</name><reference>IN</reference><type>search:query</type><cardinality>1</cardinality></result>
    <result><name>untreatedQuery</name><reference>IN</reference><type>search:query</type><cardinality>1</cardinality></result>
    <result><name>nsarray</name><reference>IN</reference><type>xs:uri</type><cardinality>*</cardinality></result>
    <result><name>fieldpaths</name><reference>IN</reference><type>xs:string</type><cardinality>+</cardinality></result>

    <result><name>ticket</name><reference>OUT</reference><type>xs:string</type><cardinality>1</cardinality></result>
    </output>

  return
  (
    map:put($context, "output-types", $preftype),
    xdmp:set-response-code(200, "OK"),

    document {

            if ("application/xml" = $preftype) then
              $out
            else
              let $config := json:config("custom")
              let $cx := map:put($config, "text-value", "label" )
              let $cx := map:put($config, "array-element-names", ("result") )
              let $cx := map:put($config , "camel-case", fn:true() )
              return
                json:transform-to-json($out, $config)

    }
  )
};



(:
 : Add a new process model version.
 : Parameters as post body
 : <invoke>
 :  <k>1</k>
 :  <collection>mydataset</collection>
 :  <treatedQuery>family:Malfoys AND age LT 10</treatedQuery>
 :  <untreatedQuery>...</untreatedQuery>
 :  <nsarray>ns1=http://some/ns ns2=http://some/other/ns</nsarray>
 :  <fieldpaths>age weight iq</fieldpaths>
 : </invoke>
 :
 : Returns a string of the ticket for the job submitted. (HTTP 200 OK)
 : <output><result><ticket>TICKETID</ticket></result></output>
 :)
declare
%roxy:params("")
%rapi:transaction-mode("update")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  let $preftype :=
    if (fn:not(fn:empty(map:get($params,"format")))) then
      if ("json" = map:get($params,"format")) then
        "application/json"
      else
        "application/xml"
    else
      if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  let $_ := xdmp:log($params)
  let $_ := xdmp:log($context)
  let $_ := xdmp:log($input)

  let $nsarray :=
    for $nspair in fn:tokenize($input/invoke/nsarray," ")
    return fn:tokenize($nspair,"=")
  let $fields := fn:tokenize($input/invoke/fieldpaths," ")

  let $opts := config-query:get-options(xs:string($input/invoke/collection))
  let $_ := xdmp:log($opts)

  let $treatedQuery := cts:query(search:parse(xs:string($input/invoke/treatedQuery),$opts,"cts:query"))
  let $untreatedQuery := cts:query(search:parse(xs:string($input/invoke/untreatedQuery),$opts,"cts:query"))

  let $_ := xdmp:log($treatedQuery)
  let $_ := xdmp:log($untreatedQuery)

  let $ticketid := knn:nn-k-spawn-udf(xs:int($input/invoke/k),xs:string($input/invoke/collection),
    (:cts:query($input/invoke/treatedQuery/element()),cts:query($input/invoke/untreatedQuery/element()):)
    $treatedQuery,$untreatedQuery
    ,$nsarray,$fields)

  let $out := <output><result><ticket>{$ticketid}</ticket></result></output>

  return
  (
    map:put($context, "output-types", $preftype),
    xdmp:set-response-code(200, "OK"),
    document {

        if ("application/xml" = $preftype) then
          $out
        else
          let $config := json:config("custom")
          let $cx := map:put($config, "array-element-names", ("result") )
          let $cx := map:put($config, "text-value", "label" )
          let $cx := map:put($config , "camel-case", fn:true() )
          return
            json:transform-to-json($out, $config)
    }

  )
};

(: TODO delete for clearing out a ticket of this type :)
