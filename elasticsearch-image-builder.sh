#!/bin/bash
printf "Building Elasticseach Docker Image...\n"
ELASTICSEARCH_IMAGE_TAG=tqp-elasticsearch:7.17.0
docker build -f elasticsearch-dockerfile . -t ${ELASTICSEARCH_IMAGE_TAG}
