#!/bin/sh

. ../config/settings.sh

$MLCP import -host $HOST -port $PORT -username $USER -password $PASS -mode local -output_uri_prefix /test/claims/ \
-aggregate_record_element claim  \
-input_file_path ../data/claims.xml -input_file_type aggregates \
-output_uri_suffix .xml -output_collections claims
