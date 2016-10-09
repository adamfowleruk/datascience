xquery version "1.0-ml";
(: Ticketing functions that do require a document update :)
module namespace m="http://marklogic.com/datascience/ticketing-update";

declare function m:ticket-update($ticket as xs:string,$pid as xs:positiveInteger,
  $total as xs:positiveInteger,$complete as xs:positiveInteger) {
  xdmp:spawn-function(function() {
    (xdmp:document-insert(
      "/datascience/tickets/" || $ticket || "/" || xs:string($pid || ".xml"),
      <ticket><id>{$ticket}</id><pid>{$pid}</pid><total>{$total}</total><complete>{$complete}</complete>
      <finished>{
        if ($total eq $complete) then fn:true() else fn:false()
        }</finished></ticket>,
      xdmp:default-permissions(),(xdmp:default-collections(),"/datascience/tickets")
    ),
    xdmp:commit()
    )
  },
    <options xmlns="xdmp:eval">
      <database>{xdmp:database()}</database>
      <transaction-mode>update</transaction-mode>
      <isolation>different-transaction</isolation>
    </options>
  )
};
