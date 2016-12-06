#!/bin/sh

. ../config/settings.sh

$MLCP import -host $HOST -port $PORT -username $USER -password $PASS -mode local -output_uri_prefix /imported/csv/zoo/ \
-input_file_path ../data/import.csv -input_file_type delimited_text -document_type json -delimiter "," \
-output_collections import,csv,zoo \
-output_uri_suffix .json -data_type "age,number,weight,number,iq,number" -generate_uri
