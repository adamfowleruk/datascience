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
  let $maxThreads := 8 (: TODO discover this from the current system itself :)
  let $max := xdmp:estimate(cts:search(fn:collection($col),$treatedQuery))
  let $size := xs:positiveInteger(math:ceil($max div $maxThreads))
  (: spawn function :)
  let $spawns :=
    for $pid in (1 to $maxThreads)
    return xdmp:spawn-function(
      function() {(
        xdmp:log("findNearestNeighbourEuclideanSpawned:spawn-begin:" || xs:string($pid)),
        xdmp:log(m:findKNearestNeighbourEuclideanBegin($ticket,$pid,$k,xs:positiveInteger(1 + (($pid - 1) * $size)),$size,$max,$col,$treatedQuery,$untreatedQuery,$nsarray,$fieldpaths)),
        xdmp:log("findNearestNeighbourEuclideanSpawned:spawn-end:" || xs:string($pid))
      )},
        <options xmlns="xdmp:eval">
          <database>{xdmp:database()}</database>
          <transaction-mode>update</transaction-mode>
        </options>

    )
  (: return ticket :)
  return $ticket
};

declare function m:findKNearestNeighbourEuclideanBegin($ticket as xs:string,$pid as xs:positiveInteger,
  $k as xs:positiveInteger,
  $start as xs:positiveInteger,$size as xs:int,$max as xs:int,
  $col as xs:string,$treatedQuery as cts:query,$untreatedQuery as cts:query,$nsarray as xs:string*,$fieldpaths as xs:string+) {
  if ($start gt $max) then () else
    let $calcIndex := $size + $start - 1
    let $lastIndex :=
      if ($calcIndex gt $max) then $max else $calcIndex

    let $_ := xdmp:log("thread " || xs:string($pid) || " of ticket " || $ticket || ":start=" || xs:string($start) ||
      ",size=" || xs:string($size) || ",max=" || xs:string($max) || ",calcIndex=" || xs:string($calcIndex) ||
      ",lastIndex(now)=" || xs:string($lastIndex))

    let $initLog := tu:ticket-update($ticket,$pid,$size,$lastIndex - $start + 1,0,())

    let $sr := cts:search(fn:collection($col),
      $untreatedQuery
    ,("unfiltered","score-zero","unfaceted")) (: Cache query output - saves n times time :)

    let $output :=
      for $candidate at $idx in cts:search(fn:collection($col),$treatedQuery)[$start to ($lastIndex)]
      let $candidateUri := fn:base-uri($candidate)
      let $status :=
        if (($idx mod 1000) eq 0) then
          (: Log status :)
          (
            xdmp:log($ticket || ":" || $pid || ":status: at index " || xs:string($idx) || " of " || xs:string($size))


            ,
            (: TODO also update progress document in database :)
            (: WARNING if we do this, this entire module will be an update module... :)
            tu:ticket-update($ticket,$pid,$size,$lastIndex - $start + 1,$idx  (:$lastIndex - $start + $idx - 2:),()) (: -2 as we've not done this one yet :)

          )
        else ()
      return (
        <result>
          <candidate>{$candidateUri}</candidate>
          <matches>{fn:string-join(m:findKNearestNeighbourEuclidean($candidate,$k,$sr,$nsarray,$fieldpaths)," ")}</matches>
        </result>
        )


    let $finishLog := tu:ticket-update($ticket,$pid,$size,$lastIndex - $start + 1,$lastIndex - $start + 1,$output)

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
  ,("unfiltered","score-logtf","unfaceted"))[1] (: TODO support up to $k matches :)
  return (fn:base-uri($res) (: ,cts:score($res) :) (:,xs:double($res/age):) )
};

declare function m:abs($in as xs:double) as xs:double {
  if ($in lt 0.0) then -1.0 * $in else $in
};

(:
 : Performs a nearest neighbour search for a single candidate document ($doc), against all records
 : in MarkLogic that match the untreated query.
 :)
declare function m:findKNearestNeighbourEuclidean($doc as node(),$k as xs:positiveInteger,
  $sr,
  $nsarray as xs:string*,$fieldpaths as xs:string+) as xs:string* {
  (: For given document and specified parameters, find it's nearest neighbour in the provided query set :)
  let $map := map:map()
  let $_ := map:put($map,"bestinversedistance",0.0) (: larger distance is bad (inverse) :)
  let $_ := map:put($map,"besturi","")
  let $count := fn:count($fieldpaths)
  let $denominator := -1.0 * $count
  let $_ :=
    for $res in $sr (: manual score calculation = no range indexes required :)
    let $score := math:pow(
      fn:fold-left(function($z, $a) { $z * $a } ,1,
        for $field in $fieldpaths
        let $fp := xs:QName($field)
        let $fieldVali := $res/*[node-name(.) eq $fp]
        let $docVali := $doc/*[node-name(.) eq $fp]
        let $fieldVal := xs:double($fieldVali)
        let $docVal := xs:double($docVali)
        (:
        let $fieldVal := xs:double(xdmp:with-namespaces($nsarray,xdmp:unpath("$res" || $field)))
        let $docVal := xs:double(xdmp:with-namespaces($nsarray,xdmp:unpath("$doc" || $field)))
        :)
        return 1.0 + (fn:abs($fieldVal - $docVal))
      ), $denominator)

(:
      ((1.0 + math:fabs( xs:double($res/age) - xs:double($doc/age))) *
      (1.0 + math:fabs(xs:double($res/weight) - xs:double($doc/weight)))) , -2)
:)
      (: Just two fields for now, using euclidean distance :)

    return
      if (map:get($map,"bestinversedistance")[1] lt $score) then
        (: Below is commented out as it only works for k=1 :)
        (: (map:put($map,"bestinversedistance",$score), map:put($map,"besturi",fn:base-uri($res)) ) :)
        let $distances := map:get($map,"bestinversedistance")
        return
          if (fn:count($distances) lt $k) then
            (
              map:put($map,"bestinversedistance",($distances,$score) ),
              map:put($map,"besturi",(map:get($map,"besturi"),fn:base-uri($res)) )
            )
          else (: Already filled the map to $k size :)
            (
              map:put($map,"bestinversedistance",($distances[2 to $k],$score) ),
              map:put($map,"besturi",(map:get($map,"besturi")[2 to $k],fn:base-uri($res)) )
            )

      else ()
  return (map:get($map,"besturi") (:,map:get($map,"bestinversedistance") :) (:,xs:double($res/age):) )
};




(: UDF FUNCTIONS :)







(: This implementation does not use range indexes, but does parallelise the work, with
 : each of 4 threads processing 1/4 of the 'treated' results to match
 :)
declare function m:nn-k-spawn-udf($k as xs:positiveInteger,$col as xs:string,
  $treatedQuery as cts:query,$untreatedQuery as cts:query,
  $nsarray as xs:string*,$fieldpaths as xs:string+) as xs:string {

  (: create ticket :)
  let $ticket := t:ticket-create()
  (: Set up function :)
  let $maxThreads := 8 (: TODO discover this from the current system itself :)
  let $max := xdmp:estimate(cts:search(fn:collection($col),$treatedQuery))
  let $size := xs:positiveInteger(math:ceil($max div $maxThreads))
  (: spawn function :)
  let $spawns :=
    for $pid in (1 to $maxThreads)
    return xdmp:spawn-function(
      function() {(
        xdmp:log("findNearestNeighbourEuclideanSpawned:spawn-begin:" || xs:string($pid)),
        xdmp:log(m:findKNearestNeighbourEuclideanUDFBegin($ticket,$pid,$k,xs:positiveInteger(1 + (($pid - 1) * $size)),$size,$max,$col,$treatedQuery,$untreatedQuery,$nsarray,$fieldpaths)),
        xdmp:log("findNearestNeighbourEuclideanSpawned:spawn-end:" || xs:string($pid))
      )},
        <options xmlns="xdmp:eval">
          <database>{xdmp:database()}</database>
          <transaction-mode>update</transaction-mode>
        </options>

    )
  (: return ticket :)
  return $ticket
};

declare function m:findKNearestNeighbourEuclideanUDFBegin($ticket as xs:string,$pid as xs:positiveInteger,
  $k as xs:positiveInteger,
  $start as xs:positiveInteger,$size as xs:int,$max as xs:int,
  $col as xs:string,$treatedQuery as cts:query,$untreatedQuery as cts:query,$nsarray as xs:string*,$fieldpaths as xs:string+) {
  if ($start gt $max) then () else
    let $calcIndex := $size + $start - 1
    let $lastIndex :=
      if ($calcIndex gt $max) then $max else $calcIndex

          let $_ := xdmp:log("thread " || xs:string($pid) || " of ticket " || $ticket || ":start=" || xs:string($start) ||
            ",size=" || xs:string($size) || ",max=" || xs:string($max) || ",calcIndex=" || xs:string($calcIndex) ||
            ",lastIndex(now)=" || xs:string($lastIndex))

    let $initLog := tu:ticket-update($ticket,$pid,$size,$lastIndex - $start + 1,0,())
(:
    let $sr := cts:search(fn:collection($col),
      $untreatedQuery
    ,("unfiltered","score-zero","unfaceted")) (: Cache query output - saves n times time :)
:)
    let $output :=
      for $candidate at $idx in cts:search(fn:collection($col),$treatedQuery)[$start to ($lastIndex)]
      let $candidateUri := fn:base-uri($candidate)
      let $status :=
        if (($idx mod 1000) eq 0) then
          (: Log status :)
          (
            xdmp:log($ticket || ":" || $pid || ":status: at index " || xs:string($idx) || " of " || xs:string($size))


            ,
            (: TODO also update progress document in database :)
            (: WARNING if we do this, this entire module will be an update module... :)
            tu:ticket-update($ticket,$pid,$size,$lastIndex - $start + 1,$idx (: no minus as assume we will finish :) (:$lastIndex - $start + $idx - 2:),()) (: -2 as we've not done this one yet :)

          )
        else ()
      return (
        <result>
          <candidate>{$candidateUri}</candidate>
          <matches>{fn:string-join(m:findKNearestNeighbourEuclideanUDF($candidate,$col,$k,$untreatedQuery,$nsarray,$fieldpaths)," ")}</matches>
        </result>
        )


    let $finishLog := tu:ticket-update($ticket,$pid,$size,$lastIndex - $start + 1,$lastIndex - $start + 1,$output)

    (: TODO log progress regularly and at the end of the run :)
    return ()
};

declare function m:findKNearestNeighbourEuclideanUDF($doc as node(),$col as xs:string,$k as xs:positiveInteger,
  $queryUntreated as cts:query,$nsarray as xs:string*,$fieldpaths as xs:string+) as xs:string* {
  let $docValues := (
    fn:base-uri($doc),
    $k,
    for $field in $fieldpaths
    let $fp := xs:QName($field)
    let $val := $doc/*[node-name(.) eq $fp]
    return xs:double($val)
  )
  (:
  let $_ := xdmp:log("DOC VALUES FOR KNN UDF:-")
  let $_ := xdmp:log($docValues)
  :)
  let $references :=
    for $field in $fieldpaths
    let $fp := xs:QName($field)
    return cts:element-reference(xdmp:with-namespaces($nsarray,$fp))

  let $udfResult := cts:aggregate(
    "native/knn",
    "knn",
    (
      (: uri lexicon reference first :)
      cts:uri-reference()
      ,
      $references
    ),  $docValues, ("fragment-frequency"),
    cts:and-query((cts:collection-query($col),$queryUntreated))
  )
  let $uris := $udfResult (: result only - is a list of URIs anyway :)
  return $uris
};
