xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/extract";

import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace config-query = "http://marklogic.com/rest-api/models/config-query"
    at "/MarkLogic/rest-api/models/config-query-model.xqy";
import module namespace search="http://marklogic.com/appservices/search"
    at "/MarkLogic/appservices/search/search.xqy";

declare namespace roxy = "http://marklogic.com/roxy";
declare namespace map = "http://marklogic.com/xdmp/map";
declare namespace rapi = "http://marklogic.com/rest-api";

(:
 : Get the data extract as CSV/JSON/XML
 :  ?collection=col&q=querytext
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
      if ("application/xml" = map:get($context,"accept-types")) then
        "application/xml"
      else if ("text/csv" = map:get($context,"accept-types")) then
        "text/csv"
      else "application/json"

  let $opts := config-query:get-options(xs:string(map:get($params,"collection")))
  let $_ := xdmp:log($opts)

  let $query := cts:query(search:parse(xs:string(map:get($params,"q")),$opts,"cts:query"))
  let $col := xs:string(map:get($params,"collection"))
  let $nl := "&#10;"

  return
  (
    map:put($context, "output-types", $preftype),
    xdmp:set-response-code(200, "OK"),

    document {

            if ("text/csv" = $preftype) then

            fn:string-join((
              for $record at $idx in cts:search(fn:collection($col),
                $query)
              return
                (
                  if (1 eq $idx) then
                    (
                    for $name at $colidx in $record/node()/node()
                    return
                      (
                        if (1 eq $colidx) then
                          xs:string(name($name))
                        else
                          ("," || xs:string(name($name)))

                      )
                      ,
                      $nl
                    )
                  else ()
                  ,
                  for $el at $colidx in $record/node()/node()
                  return
                  (
                    if (1 eq $colidx) then
                      xs:string($el)
                    else
                      ("," || xs:string($el))
                  )
                  ,
                  $nl
                )
                ))
            else if ("application/xml" = $preftype) then
              <results>{
              for $record at $idx in cts:search(fn:collection($col),
                $query)
              return
                <result>{$record}</result>
              }</results>
            else
              let $config := json:config("custom")
              let $cx := map:put($config, "text-value", "label" )
              let $cx := map:put($config, "array-element-names", ("result") )
              let $cx := map:put($config , "camel-case", fn:true() )
              return
                json:transform-to-json(<somexml>value</somexml>, $config)

    }
  )
};
