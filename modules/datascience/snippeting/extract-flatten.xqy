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

declare function m:path($ctxnode,$tokens,$depth) {
  let $newctx := $ctxnode/element()[fn:local-name(.) = $tokens[$depth]][1]

  return
    if ($depth = fn:count($tokens)) then
      if (fn:empty($tokens[$depth])) then
        ()
      else
        element {fn:QName("",$tokens[$depth])} {xs:string($newctx)}
    else
      element {fn:QName("",$tokens[$depth])} {
        m:path($newctx,$tokens,$depth + 1)
      }
};

declare function m:snippet(
   $result as node(),
   $ctsquery as schema-element(cts:query),
   $options as element(search:transform-results)?
) as element(search:snippet)
{
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
      element {fn:QName("",fn:local-name($root))} {
        for $name in $options/search:extract/search:element/@name
        let $namestr := xs:string($name)
        let $tokens := fn:tokenize($namestr,"/")
        return
          if (fn:count($tokens) = 1) then
            for $child in $root/element()[fn:local-name(.) = $namestr]
            (: return ($options/search:extract/search:element,$child) :)
            return
              (: for $elconfig in $options/search:extract/search:element[@name = $child/fn:local-name(.)]
              return :)
              (: $child :)
              if (fn:empty($namestr)) then
                ()
              else
                element {fn:QName("",$namestr)} {xs:string($child)}
          else
            (: xdmp:unpath for now :)
            m:path($root,$tokens,1)

      }
    }
};
