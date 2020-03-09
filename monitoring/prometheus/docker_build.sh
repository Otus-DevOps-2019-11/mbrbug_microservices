#!/bin/bash

docker build -t  ${USERNAME1}/prometheus .
docker push  ${USERNAME1}/prometheus
