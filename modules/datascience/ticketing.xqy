xquery version "1.0-ml";
(: Ticketing functions that do not require a document update :)
module namespace m="http://marklogic.com/datascience/ticketing";

declare function m:ticket-create() {
  xs:string(fn:current-dateTime() || "-" || xdmp:random())
};

declare function m:ticket-progress($ticket as xs:string) as node() {
  let $map := map:map()
  let $_ := (
    map:put($map,"total",0),
    map:put($map,"complete",0),
    map:put($map,"rate",0.0)
  )
  let $tickets := fn:collection("/datascience/tickets")/ticket[./id eq $ticket]
  let $count := fn:count($tickets)
  let $_ :=
    for $doc in $tickets
    return (
      map:put($map,"total",map:get($map,"total") + $doc/total),
      map:put($map,"complete",map:get($map,"complete") + $doc/complete),
      map:put($map,"rate",map:get($map,"rate") + (if (fn:not(fn:empty($doc/rate-per-second))) then $doc/rate-per-second else 0.0))
    )
  return
  <ticket-progress>
   <total>{map:get($map,"total")}</total>
   <complete>{map:get($map,"complete")}</complete>
   <rate-per-second>{xs:double(map:get($map,"rate"))}</rate-per-second>
   <percent-complete>{(math:floor(
    if (0 eq map:get($map,"total")) then
      0.0
    else
      xs:double(map:get($map,"complete")) div xs:double(map:get($map,"total"))
    * 100 * 1000)) div 1000.0
   }</percent-complete>
  </ticket-progress>
};

declare function m:ticket-list($ticket as xs:string) as node()* {
  fn:collection("/datascience/tickets")/ticket[./id eq $ticket]
};

(: TODO warning if still running :)
declare function m:ticket-output($ticket as xs:string) as node() {
  <output>
  {
    for $ticket in m:ticket-list($ticket)
    return $ticket/return-value/*
  }
  </output>
};
