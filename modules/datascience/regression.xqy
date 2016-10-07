xquery version "1.0-ml";
(: linear, log-linear, logistic and other regression functions :)

module namespace m="http://marklogic.com/datascience/regression";

declare namespace math="http://marklogic.com/xdmp/math";

declare function m:regression-linear($col as xs:string?,$query as cts:query?,$nsarray as xs:string*,$fieldpathx as xs:string,$fieldpathy as xs:string) {
  map:map() (: TODO fill this out :)
};

declare function m:regression-linear-udf($col as xs:string?,$query as cts:query?,$nsarray as xs:string*,$fieldpathx as xs:string,$fieldpathy as xs:string) {
  (: actually call linear-model :)

  let $output := <xml>{cts:linear-model(
    (
      cts:element-reference(xdmp:with-namespaces($nsarray,xs:QName($fieldpathy)), ("type=double")), (: x and y are inverted with linear-model compared to later comparison calculations :)
      cts:element-reference(xdmp:with-namespaces($nsarray,xs:QName($fieldpathx)), ("type=double"))
    ),
    ("item-frequency"),
    cts:and-query((cts:collection-query($col),$query))
  )}</xml>/*
  let $results := map:map()
  let $_ := (
    map:put($results,"intercept",xs:double($output/@intercept)),
    map:put($results,"gradient",xs:double($output/@coefficients)),
    map:put($results,"rsquared",xs:double($output/@rsquared))
  )
  return $results
};

declare function m:regression-log-linear($col as xs:string?,$query as cts:query?,$nsarray as xs:string*,$fieldpathx as xs:string,$fieldpathy as xs:string) {
  let $sr := cts:search(fn:collection($col),$query)
  let $results := map:map()

  let $map := map:map()
  let $_ := map:put($map,"sum0",0.0)
  let $_ := map:put($map,"sum1",0.0)
  let $_ := map:put($map,"sum2",0.0)
  let $_ := map:put($map,"sum3",0.0)
  let $count := fn:count($sr)
  let $_ :=
    for $doc in $sr
    (:
    let $n0 := xs:double(xdmp:unpath(xdmp:path($uri) || $xpathx))
    let $n1 := xs:double(xdmp:unpath(xdmp:path($uri) || $xpathy))
    :)
    (:)
    let $n0 := xs:double($doc/age) (: Using this here is much, much quicker. May want to pass in two functions to fetch this data rather than use unpath :)
    let $n1 := xs:double($doc/weight)
    :)
    (:
    let $n0 := xs:double(xdmp:with-namespaces($nsarray,xdmp:unpath("$doc" || $fieldpathx)))
    let $n1 := xs:double(xdmp:with-namespaces($nsarray,xdmp:unpath("$doc" || $fieldpathy)))
    :)
    (:
    let $n0 := xs:double(xdmp:with-namespaces($nsarray,xdmp:unpath("fn:doc(""" || fn:base-uri($doc) || """)" || $fieldpathx)))
    let $n1 := xs:double(xdmp:with-namespaces($nsarray,xdmp:unpath("fn:doc(""" || fn:base-uri($doc) || """)" || $fieldpathy)))

    :)
    (:
    let $n0 := xs:double($doc/node()[local-name(.)=$fieldpathx])
    let $n1 := xs:double($doc/node()[local-name(.)=$fieldpathy])
    :)
    let $fpx := xs:QName($fieldpathx)
    let $fpy := xs:QName($fieldpathy)
    let $n0 := xs:double($doc/*[node-name(.) eq $fpx])
    let $n1 := xs:double($doc/*[node-name(.) eq $fpy])

    (:
    let $n0 := xs:double(xdmp:value("$doc" || $fieldpathx))
    let $n1 := xs:double(xdmp:value("$doc" || $fieldpathy))
    :)
    (: TODO sanity check of $n0 too :)
    let $logn0 := math:log($n0)
    let $check :=
      if (fn:not(fn:empty($n1))) then
        (
          map:put($map,"sum0",map:get($map,"sum0") + $logn0),
          map:put($map,"sum1",map:get($map,"sum1") + ($n1 * $logn0)),
          map:put($map,"sum2",map:get($map,"sum2") + $n1),
          map:put($map,"sum3",map:get($map,"sum3") + ($logn0 * $logn0))
        )
      else ()
    return ()
  let $B := (($count * map:get($map,"sum1")) - (map:get($map,"sum2") * map:get($map,"sum0"))) div (($count * map:get($map,"sum3")) - (map:get($map,"sum0") * map:get($map,"sum0")))
  let $A := (map:get($map,"sum2") - ($B * map:get($map,"sum0"))) div $count
  let $str := "y = " || xs:string(math:floor($A * 1000) div 1000) || " + " || xs:string(math:floor($B * 1000) div 1000) || " ln(x)"
  (: return ($count,$A,$B,$str) :)
  let $_ :=
    (
      map:put($results,"intercept",$A),
      map:put($results,"gradient",$B),
      map:put($results,"formula",$str),
      map:put($results,"count",$count)
    )
  return $results
};

declare function m:regression-log-linear-udf($col as xs:string?,$query as cts:query?,$nsarray as xs:string*,$fieldpathx as xs:string,$fieldpathy as xs:string) as map:map {
  cts:aggregate(
    "native/lnreg",
    "lnreg",
    (
      cts:element-reference(xdmp:with-namespaces($nsarray,xs:QName($fieldpathx)),()),
      cts:element-reference(xdmp:with-namespaces($nsarray,xs:QName($fieldpathy)),())
    ),  (), ("fragment-frequency"),
    cts:and-query((cts:collection-query($col),$query))
  )
};
