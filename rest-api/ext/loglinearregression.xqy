xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/loglinearregression";

import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace reg="http://marklogic.com/datascience/regression" at "/datascience/regression.xqy";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace map = "http://marklogic.com/xdmp/map";
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

  let $out := <output>
      <result><name>collection</name><reference>IN</reference><type>xs:uri</type><cardinality>1</cardinality></result>
      <result><name>query</name><reference>IN</reference><type>cts:query</type><cardinality>1</cardinality></result>
      <result><name>nsarray</name><reference>IN</reference><type>xs:uri</type><cardinality>*</cardinality></result>
      <result><name>fieldpaths</name><reference>IN</reference><type>xs:string</type><cardinality>+</cardinality></result>

      <result><name>intercept</name><reference>OUT</reference><type>xs:double</type><cardinality>1</cardinality></result>
      <result><name>gradient</name><reference>OUT</reference><type>xs:double</type><cardinality>1</cardinality></result>
      <result><name>formula</name><reference>OUT</reference><type>xs:string</type><cardinality>1</cardinality></result>
      <result><name>count</name><reference>OUT</reference><type>xs:long</type><cardinality>1</cardinality></result>
    </output>
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
 : Invoke a log linear regression, not using range indexes.
 :
 : Parameters as post body
 : <invoke>
 :  <collection>mydataset</collection>
 :  <query><cts:collection-query>...</cts:collection-query></query>
 :  <nsarray>ns1=http://some/ns ns2=http://some/other/ns</nsarray>
 :  <fieldpaths>age weight</fieldpaths>
 : </invoke>
 :
 : Returns the linear regression result. (HTTP 200 OK)
 : <output><result><intercept>1.0</intercept><gradient>0.34</gradient><rsquared>123.4</rsquared></result></output>
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

  let $results := reg:regression-log-linear(xs:string($input/invoke/collection),
    cts:query($input/invoke/query/element()),$nsarray,$fields[1],$fields[2])

  let $out := <output><result>{
    for $entry in <xml>{$results}</xml>/map:map/map:entry
    return
      element {xs:string($entry/@key)} {
        xs:string($entry/map:value)
      }
    }</result></output>

  return
  (
    map:put($context, "output-types", "application/json"),
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

(: TODO delete for clearing out a ticket of this type :)
