xquery version "1.0-ml";
(: Simple aggregates library :)

module namespace m="http://marklogic.com/datascience/aggregates";

declare function m:mean($col as xs:string?,$query as cts:query?,$nsarray as xs:string*,$fieldpath as xs:string) as map:map {
  let $map := map:map()
  (: let $_ := map:put($map,"count",0) :)
  let $_ := map:put($map,"total",0.0)
  let $fullcount := xdmp:estimate(cts:search(fn:collection($col),$query))
  let $_work :=
    for $doc in cts:search(fn:collection($col),$query)
    return (
      (:map:put($map,"count",map:get($map,"count") + 1),:) (: we could reduce processing overhead by running xdmp:estimate(fn:collection("zoo")) instead of counting :)
      map:put($map,"total",map:get($map,"total") +
        xs:double(xdmp:with-namespaces($nsarray,xdmp:unpath("$doc" || $fieldpath))) )
        (: xs:double($animal/weight)) :) (: replace 'weight' with 'age' to see impact of a range index :)
    )
  let $_ :=
    (
      map:put($map,"mean",map:get($map,"total") div $fullcount),
      map:put($map,"count", $fullcount)
    )
  return
    $map

  (:
  (
    "Count: ", (:map:get($map,"count"):) $fullcount,
    "Total: ", map:get($map,"total"),
    "Mean Average: ", map:get($map,"total") div $fullcount (: map:get($map,"count") :)
  )
  :)
};
