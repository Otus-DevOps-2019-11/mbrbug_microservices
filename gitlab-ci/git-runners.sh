#!/bin/bash

for (( i=1; i <= $1; i++ ))
do
echo "number is $i"

docker run -d --name gitlab-runner$i --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest

docker exec -it gitlab-runner$i gitlab-runner \
register -n   --url http://35.205.115.90/ \
--registration-token XAgp1z_JS7sJXbsaKJyF \
--executor docker \
--description "My Docker Runner$i" \
--docker-image "docker:19.03.1" \
--docker-volumes /var/run/docker.sock:/var/run/docker.sock
done
