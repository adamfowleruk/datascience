xquery version "1.0-ml";
(: Ticketing functions that do not require a document update :)
module namespace m="http://marklogic.com/datascience/ticketing";

declare function m:ticket-create() {
  xs:string(xdmp:current-dateTime() || "-" || xdmp:random())
};

declare function m:ticket-progress($ticket as xs:string) as xs:double {
  let $map := map:map()
  let $_ := (
    map:put($map,"total",0),
    map:put($map,"complete",0)
  )
  let $_ :=
    for $doc in fn:collection("/datascience/tickets")/ticket[id=$ticket]
    return (
      map:put($map,"total",map:get($map,"total") + $doc/total),
      map:put($map,"complete",map:get($map,"complete") + $doc/complete)
    )
  return map:get($map,"complete") div map:get($map,"total")
};
