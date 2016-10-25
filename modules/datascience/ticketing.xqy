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
    map:put($map,"rate",0.0),
    map:put($map,"numendtimes",0),
    map:put($map,"numtickets",0)
  )
  let $tickets := fn:collection("/datascience/tickets")/ticket[./id eq $ticket]
  let $count := fn:count($tickets)
  let $_ :=
    for $doc in $tickets
    return (
      map:put($map,"numtickets",map:get($map,"numtickets") + 1),
      map:put($map,"total",map:get($map,"total") + $doc/total),
      map:put($map,"complete",map:get($map,"complete") + $doc/complete),
      map:put($map,"rate",map:get($map,"rate") + (if (fn:not(fn:empty($doc/rate-per-second))) then $doc/rate-per-second else 0.0)),
      if (fn:empty(map:get($map,"starttime")) or (xs:dateTime(map:get($map,"starttime")) gt xs:dateTime($doc/started))) then
        map:put($map,"starttime",xs:dateTime($doc/started))
      else (),
      if (fn:not(fn:empty($doc/finished))) then
        (: Add to end time count :)
        map:put($map,"numendtimes",map:get($map,"numendtimes") + 1)
      else (),
      if (fn:empty(map:get($map,"endtime")) or (xs:dateTime(map:get($map,"endtime")) lt xs:dateTime($doc/finished))) then
        map:put($map,"endtime",xs:dateTime($doc/finished))
      else (),
      if (fn:empty(map:get($map,"durationseconds")) or (xs:double(map:get($map,"durationseconds")) lt xs:double($doc/duration-seconds))) then
        map:put($map,"durationseconds",xs:double($doc/duration-seconds))
      else ()
    )
  return
  <ticket-progress>
   <total>{map:get($map,"total")}</total>
   <complete>{map:get($map,"complete")}</complete>
   <started>{map:get($map,"starttime")}</started>
   { if (map:get($map,"numtickets") eq map:get($map,"numendtimes") and fn:not(fn:empty(map:get($map,"endtime")))) then
     (<finished>{map:get($map,"endtime")}</finished>,
     <duration>{xs:dateTime(map:get($map,"endtime")) - xs:dateTime(map:get($map,"starttime")) }</duration>)
    else () }
   <duration-seconds>{map:get($map,"durationseconds")}</duration-seconds>
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
