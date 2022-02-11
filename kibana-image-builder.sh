#!/bin/bash
printf "Building Kibana Docker Image...\n"
KIBANA_IMAGE_TAG=tqp-kibana:7.17.0
docker build -f kibana-dockerfile . -t ${KIBANA_IMAGE_TAG}