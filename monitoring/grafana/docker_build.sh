#!/bin/bash

docker build -t  ${USERNAME1}/grafana .
docker push  ${USERNAME1}/grafana
