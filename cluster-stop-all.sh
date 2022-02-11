#!/bin/bash

printf "Stopping all Elasticsearch Containers...\n"
docker stop tqp-elasticsearch-01
docker stop tqp-elasticsearch-02
docker stop tqp-elasticsearch-03
docker stop tqp-kibana-01
