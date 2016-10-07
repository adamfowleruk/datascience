#!/bin/sh

. ../config/settings.sh

$MLCP import -host $HOST -port $PORT -username $USER -password $PASS -mode local -output_uri_prefix /os/mastermap/adbp/ \
-aggregate_record_element basicLandPropertyUnitMember -aggregate_record_namespace "http://namespaces.geoplace.co.uk/addressbasepremium/2.0" \
-input_file_path ../data/sx9090.gml -input_file_type aggregates \
-output_uri_suffix .xml -output_collections osgb,gml,addressbasepremium,buildings
