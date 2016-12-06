xquery version "1.0-ml";
(: k Nearest Neighbour algorithm :)

module namespace m="http://marklogic.com/datascience/snippeting/extract-flatten";

(: A custom snippeting function to extract just the elements required, and flatten the XML or JSON output :)

(: Needed for efficient CSV style data extraction of complex documents :)

(:
 : Done:-
 : - Restrict top level elements to only those selected in an <element name="name" /> specification
 :
 : TODO:-
 : - Namespace support
 : - JSON result support
 : - Nested structure flattening
 :)

import module namespace search =
  "http://marklogic.com/appservices/search"
  at "/MarkLogic/appservices/search/search.xqy";


declare function m:snippet(
   $result as node(),
   $ctsquery as schema-element(cts:query),
   $options as element(search:transform-results)?
) as element(search:snippet)
{
  let $_ := xdmp:log($result)
  let $_ := xdmp:log($ctsquery)
  let $_ := xdmp:log($options)
  let $default-snippet := search:snippet($result, $ctsquery, $options)
  let $root := fn:doc($result/fn:base-uri(.))/element()
  let $rootjson := fn:doc($result/fn:base-uri(.))/node()
  return
  element
    { fn:QName(fn:namespace-uri($default-snippet),
               fn:name($default-snippet)) }
    {
      if (fn:empty($root) and fn:not(fn:empty($rootjson))) then
        (: Got a JSON result :)
        xdmp:to-json-string($rootjson)
        (: TODO replace full thing with just the requested properties :)
      else
        (: Got an XML result :)
      element {fn:QName(fn:namespace-uri($root),fn:name($root))} {
        for $child in $root/element()[fn:name(.) = $options/search:extract/search:element/@name]

        (: return ($options/search:extract/search:element,$child) :)

        return
          (: for $elconfig in $options/search:extract/search:element[@name = $child/fn:name(.)]
          return :)
              $child

      }
    }
};
