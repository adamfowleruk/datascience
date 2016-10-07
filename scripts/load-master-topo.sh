#!/bin/sh

. ../config/settings.sh

$MLCP import -host $HOST -port $PORT -username $USER -password $PASS -mode local -output_uri_prefix /os/mastermap/topo/ \
-aggregate_record_element topographicMember -aggregate_record_namespace "http://www.ordnancesurvey.co.uk/xml/namespaces/osgb" \
-input_file_path ../data/os-mastermap-topography-layer-sample-data.gml -input_file_type aggregates \
-output_collections osgb,gml,topographic,buildings \
-output_uri_suffix .xml
