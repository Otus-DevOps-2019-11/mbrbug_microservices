# mbrbug_microservices
mbrbug microservices repository

### №15 Технология контейнеризации. Введение в Docker
##### docker, docker-machine, docker-compose docker
run, info, diff, ps, image, images, start, attach, stop, exec, create, commit kill, system df, rm, rmi, inspect `docker rm $(docker ps -a -q)`

##### docker-machine:
`docker-machine create <имя>`
eval $(docker-machine env <имя>)
eval $(docker-machine env --unset)
'export GOOGLE_PROJECT=ваш-проект'
```
docker-machine create
--driver google \
 --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntuos-cloud/global/images/family/ubuntu-1604-lts \
 --google-machine-type n1-standard-1 \
 --google-zone europe-west1-b \
 docker-host
```
`docker-machine ls`

##### Dockerfile
```
FROM ubuntu:16.04
RUN apt-get update
COPY mongod.conf /etc/mongod.conf
CMD ["/start.sh"]
```
`docker build -t reddit:latest .`
`docker tag reddit:latest <your-login>/otus-reddit:1.0`
