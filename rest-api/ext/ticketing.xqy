xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/ticketing";

import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";

import module namespace t="http://marklogic.com/datascience/ticketing" at "/datascience/ticketing.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

declare namespace rapi = "http://marklogic.com/rest-api";


(: Retrieve a ticket's results.
 : GET ?ticket=ticketid
 :)
 declare
 %roxy:params("ticket=xs:string")
 function ext:get(
   $context as map:map,
   $params  as map:map
 ) as document-node()*
 {
   let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

     let $_ := xdmp:log($params)
     let $_ := xdmp:log($context)

  let $out := <output>
      <result><name>ticket</name><reference>IN</reference><type>xs:string</type><cardinality>1</cardinality></result>

      <result><name>document</name><reference>OUT</reference><type>application/xml</type><cardinality>1</cardinality></result>
    </output>

   let $_ := xdmp:log($out)

   return
   (
     map:put($context, "output-types", "text/xml"),
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


(: Retrieve a ticket's results.
 : GET ?ticket=ticketid
 :)
 declare
 %roxy:params("")
 function ext:post(
   $context as map:map,
   $params  as map:map,
   $input   as document-node()*
 ) as document-node()*
 {
   let $preftype := if ("application/xml" = map:get($context,"accept-types")) then "application/xml" else "application/json"

     let $_ := xdmp:log($params)
     let $_ := xdmp:log($context)

   let $ticket := xs:string($input/invoke/ticket) (:map:get($params,"ticket"):)

   let $_ := xdmp:log("Ticket: " || $ticket)

   let $out := t:ticket-output($ticket)

   let $_ := xdmp:log($out)

   return
   (
     map:put($context, "output-types", "text/xml"),
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
