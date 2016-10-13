# REST Stored Procedure Pattern

The REST Stored procedure pattern is a simple MarkLogic REST extension pattern that allows
a REST extension to be created that is self describing.

The GET request (no parameters) to the extension returns a simple description of the input and output parameters
of the extension's POST function.

The POST function carries out (calls) the stored procedure.

## Data Format

A GET has a simple input and output format. Calling GET returns something like this:-

```xml
<output>
    <result><name>collection</name><reference>IN</reference><type>xs:uri</type><cardinality>1</cardinality></result>
    <result><name>query</name><reference>IN</reference><type>cts:query</type><cardinality>1</cardinality></result>
    <result><name>nsarray</name><reference>IN</reference><type>xs:uri</type><cardinality>*</cardinality></result>
    <result><name>fieldpaths</name><reference>IN</reference><type>xs:string</type><cardinality>+</cardinality></result>

    <result><name>intercept</name><reference>OUT</reference><type>xs:double</type><cardinality>1</cardinality></result>
    <result><name>gradient</name><reference>OUT</reference><type>xs:double</type><cardinality>1</cardinality></result>
    <result><name>formula</name><reference>OUT</reference><type>xs:string</type><cardinality>1</cardinality></result>
    <result><name>count</name><reference>OUT</reference><type>xs:long</type><cardinality>1</cardinality></result>
  </output>
```

The first 4 fields here are input fields to be sent to the extension's POST parameters. The last 4 fields describe
the output fields that can be expected in each row of the result. There may be zero, one, or multiple result rows.

An example invocation of this POST function can be seen here:-

```xml
<invoke>
 <collection>zoo</collection>
<query><cts:and-query xmlns:cts="http://marklogic.com/cts">
  <cts:json-property-value-query>
    <cts:property>family</cts:property>
    <cts:value xml:lang="en">Malfoys</cts:value>
  </cts:json-property-value-query>
  <cts:json-property-range-query operator="&lt;">
    <cts:property>age</cts:property>
    <cts:value xsi:type="xs:integer" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">10</cts:value>
  </cts:json-property-range-query>
</cts:and-query></query>
  <nsarray></nsarray>
  <fieldpaths>age weight</fieldpaths>
 </invoke>
```

Here is some example output of the POST function, this time in JSON format:-
```json
{
  "output": {
    "result": [
      {
        "formula": "y = 98.462 + 2.457 ln(x)",
        "intercept": "98.4626209631363",
        "count": "900",
        "gradient": "2.4574597369982"
      }
    ]
  }
}
```

## Advanced output format

If the POST function return format is highly variable (such as the ticketing output function) then the return type
will be described as follows:-

```xml
<output>
    <result>
        <name>ticket</name>
        <reference>IN</reference>
        <type>xs:string</type>
        <cardinality>1</cardinality>
    </result>
    <result>
        <name>document</name>
        <reference>OUT</reference>
        <type>application/xml</type>
        <cardinality>1</cardinality>
    </result>
</output>
```

An output name of document with type application/xml or application/json basically instructs the invoker that it should
'sniff' (test) the output format after the call, and not rely upon a pre-determined output format. This is sometimes
unavoidable.

## Motivation

This REST Stored Procedure pattern was created to satisfy legacy relational Stored Procedure invocation style
integration, hence the name. The pattern also allows a nice basic format for statistical and other informational
extensions.

This project uses the pattern extensively for all data science REST API extensions. This is to ensure maximum
integration with legacy RDBMS style tools.
