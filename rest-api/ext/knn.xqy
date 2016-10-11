xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/knn";

import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace knn="http://marklogic.com/datascience/nn-k" at "/datascience/nn-k.xqy";

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
  let $preftype := "application/xml" (: if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json" :)

  let $out := <output><result><name>knn</name>
    <parameters>
      <parameter name="k" type="xs:int" />
      <parameter name="collection" type="xs:uri" />
      <parameter name="treatedQuery" type="cts:query" />
      <parameter name="untreatedQuery" type="cts:query" />
      <parameter name="nsarray" type="xs:string" cardinality="*" />
      <parameter name="fieldpaths" type="xs:string" cardinality="*" />
    </parameters></result></output>
  return
  (
    map:put($context, "output-types", "text/xml"),
    xdmp:set-response-code(200, "OK"),

    document {

            if ("application/xml" = $preftype) then
              $out
            else
              let $config := json:config("custom")
              let $cx := map:put($config, "text-value", "label" )
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
 :  <treatedQuery><cts:collection-query>...</cts:collection-query></treatedQuery>
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
  let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

  let $_ := xdmp:log($params)
  let $_ := xdmp:log($context)
  let $_ := xdmp:log($input)

  let $nsarray :=
    for $nspair in fn:tokenize($input/invoke/nsarray," ")
    return fn:tokenize($nspair,"=")
  let $fields := fn:tokenize($input/invoke/fieldpaths," ")

  let $ticketid := knn:nn-k-spawn(xs:int($input/invoke/k),xs:string($input/invoke/collection),
    cts:query($input/invoke/treatedQuery/element()),cts:query($input/invoke/untreatedQuery/element()),$nsarray,$fields)

  let $out := <output><result><ticket>{$ticketid}</ticket></result></output>

  return
  (
    map:put($context, "output-types", "application/json"),
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
