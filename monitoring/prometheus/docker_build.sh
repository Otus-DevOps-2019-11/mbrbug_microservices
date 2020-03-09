#!/bin/bash

docker build -t ${USER_NAME}/prometheus .
docker push ${USER_NAME}/prometheus
