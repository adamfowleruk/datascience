xquery version "1.0-ml";
(: k Nearest Neighbour algorithm :)

module namespace m="http://marklogic.com/datascience/nn-k";


import module namespace t="http://marklogic.com/datascience/ticketing" at "/datascience/ticketing.xqy";
import module namespace tu="http://marklogic.com/datascience/ticketing-update" at "/datascience/ticketing-update.xqy";

declare function m:nn-k($col as xs:string?,$treatedQuery as cts:query,$untreatedQuery as cts:query,$nsarray as xs:string*,$fieldpaths as xs:string+) as map:map {
map:map()
};

(: This implementation does not use range indexes, but does parallelise the work, with
 : each of 4 threads processing 1/4 of the 'treated' results to match
 :)
declare function m:nn-k-spawn($k as xs:positiveInteger,$col as xs:string,
  $treatedQuery as cts:query,$untreatedQuery as cts:query,
  $nsarray as xs:string*,$fieldpaths as xs:string+) as xs:string {

  (: create ticket :)
  let $ticket := t:ticket-create()
  (: Set up function :)
  let $maxThreads := 4 (: TODO discover this from the current system itself :)
  let $max := xdmp:estimate(cts:search($col,$treatedQuery))
  let $size := math:ceil($max div $maxThreads)
  (: spawn function :)
  let $spawns :=
    for $pid in (1 to $maxThreads)
    return xdmp:spawn-function(
      function() {(
        xdmp:log("findNearestNeighbourEuclideanSpawned:spawn-begin:" || xs:string($pid)),
        xdmp:log(m:findKNearestNeighbourEuclideanBegin($ticket,$pid,$k,1 + ($pid * $size),$size,$max,$col,$treatedQuery,$untreatedQuery)),
        xdmp:log("findNearestNeighbourEuclideanSpawned:spawn-end:" || xs:string($pid))
      )}
    )
  (: return ticket :)
  return $ticket
};

declare function m:findKNearestNeighbourEuclideanBegin($ticket as xs:string,$pid as xs:positiveInteger,
  $k as xs:positiveInteger,
  $start as xs:positiveInteger,$size as xs:positiveInteger,$max as xs:positiveInteger,
  $col as xs:string,$treatedQuery as cts:query,$untreatedQuery as cts:query) {
  if ($start gt $max) then () else
    let $calcIndex := $size + $start - 1
    let $lastIndex :=
      if ($calcIndex gt $max) then $max else $calcIndex

    let $initLog := tu:ticket-update($ticket,$pid,$max - $start + 1,0)

    let $output :=
      for $candidate at $idx in cts:search(fn:collection($col),$treatedQuery)[(1 + $start) to ($lastIndex)]
      let $candidateUri := fn:base-uri($candidate)
      let $status :=
        if (($idx mod 10000) eq 0) then
          (: Log status :)
          (
            xdmp:log($ticket || ":" || $pid || ":status: at index " || xs:string($idx) || " of " || xs:string($size)),
            (: TODO also update progress document in database :)
            (: WARNING if we do this, this entire module will be an update module... :)
            tu:ticket-update($ticket,$pid,$max - $start + 1,$start + $idx - 2) (: -2 as we've not done this one yet :)
          )
        else ()
      return ($candidateUri,m:findKNearestNeighbourEuclidean($candidate,$k,$col,$untreatedQuery,$nsarray,$fieldpaths))

    let $finishLog := tu:ticket-update($ticket,$pid,$max - $start + 1,$max - $start + 1)

    (: TODO log progress regularly and at the end of the run :)
    return ()
};

(:
 : Finds the nearest neigbour for a given document, using the specified fields.
 : Uses simple euclidean distance, no weighting, no caliper.
 :
 : TODO expand this for N fields, rather than hardcoded, and fix for new invocation mechanism
 :)
declare function m:findKNearestNeighbourEuclideanRI($doc as node(),$col as xs:string,$queryUntreated as cts:query,
  $nsarray as xs:string*,$fieldpaths as xs:string+) as xs:string? {

  (: For given document and specified parameters, find it's nearest neighbour in the provided query set :)
  for $res in cts:search(fn:collection($col),
    cts:and-query((
      $queryUntreated ,
      cts:or-query(( (: Maximises matches even if some data missing. Can enforce this to an and-query if all records must have all fields :)
        cts:or-query((
          cts:json-property-range-query("age","<=",$doc/age,("score-function=reciprocal","slope-factor=1")),
          cts:json-property-range-query("age",">",$doc/age,("score-function=reciprocal","slope-factor=1"))
        ))

        ,
        cts:or-query((
          cts:json-property-range-query("iq","<=",$doc/iq,("score-function=reciprocal","slope-factor=1")),
          cts:json-property-range-query("iq",">",$doc/iq,("score-function=reciprocal","slope-factor=1"))
        )) (: Add as many other fields here as you like :)

      ))
    ))
  ,("unfiltered","score-logtf","unfaceted"))[1 to $max]
  return (fn:base-uri($res) (: ,cts:score($res) :) (:,xs:double($res/age):) )
};

(:
 : Performs a nearest neighbour search for a single candidate document ($doc), against all records
 : in MarkLogic that match the untreated query.
 :)
declare function m:findKNearestNeighbourEuclidean($doc as node(),$k as xs:positiveInteger,
  $col as xs:string,$untreatedQuery as cts:query,
  $nsarray as xs:string*,$fieldpaths as xs:string+) as xs:string? {
  (: For given document and specified parameters, find it's nearest neighbour in the provided query set :)
  let $map := map:map()
  let $_ := map:put($map,"bestinversedistance",0.0) (: larger distance is bad (inverse) :)
  let $_ := map:put($map,"besturi","")
  let $_ :=
    for $res in cts:search(fn:collection($col),
      $untreatedQuery
    ,("unfiltered","score-zero","unfaceted")) (: manual score calculation = no range indexes required :)
    let $score := math:pow(
      fn:fold-left(function($z, $a) { $z * $a } ,
        for $field in $fieldpaths
        let $fieldVal := xs:double(xdmp:with-namespaces($nsarray,"$res" || $field))
        let $docVal := xs:double(xdmp:with-namespaces($nsarray,"$doc" || $field))
        return 1.0 + (math:fabs($fieldVal - $docVal))
      ), (-1.0 * fn:count($fields)))

(:
      ((1.0 + math:fabs( xs:double($res/age) - xs:double($doc/age))) *
      (1.0 + math:fabs(xs:double($res/weight) - xs:double($doc/weight)))) , -2)
:)
      (: Just two fields for now, using euclidean distance :)

    return
      if (map:get($map,"bestinversedistance") lt $score) then
        (map:put($map,"bestinversedistance",$score), map:put($map,"besturi",fn:base-uri($res)) )
      else ()
  return (map:get($map,"besturi") (:,map:get($map,"bestinversedistance") :) (:,xs:double($res/age):) )
};