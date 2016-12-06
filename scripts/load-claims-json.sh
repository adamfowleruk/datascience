#!/bin/sh

. ../config/settings.sh

# THIS DOES NOT WORK - ONLY LINE DELIMITED JSON IS SUPPORTED!

$MLCP import -host $HOST -port $PORT -username $USER -password $PASS -mode local -output_uri_prefix /test/claimsjson/ \
-aggregate_record_element claim  \
-input_file_path ../data/claims.json -input_file_type aggregates \
-output_uri_suffix .json -output_collections claimsjson
