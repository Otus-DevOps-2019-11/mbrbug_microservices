# mbrbug_microservices
mbrbug microservices repository

### №16 Docker-образы. Микросервисы

Разбиение приложения на 4 компонента: post, comment, ui и БД Mongo
Для каждого компонента создан Docker образ и Dockerfile
```
FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y ruby-full ruby-dev build-essential \
    && gem install bundler --no-ri --no-rdoc

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```
`docker run -d --network=reddit --network-alias=comment andrewmbr/comment:1.0`

##### Docker network
`docker network create reddit`
```
docker run -d --network=reddit \
--network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit \
--network-alias=post <your-dockerhub-login>/post:1.0
docker run -d --network=reddit \
--network-alias=comment <your-dockerhub-login>/comment:1.0
docker run -d --network=reddit \
-p 9292:9292 <your-dockerhub-login>/ui:1.0
```
##### Переменные в командной строке
формат -e или --env POST_SERVICE_HOST=post_al
```
docker run -d --network=reddit --network-alias=db_post --network-alias=db_comment mongo:latest \
...
docker run -d --network=reddit -p 9292:9292 --env POST_SERVICE_HOST=post_al --env COMMENT_SERVICE_HOST=comment_al andrewmbr/ui:1.0
```
##### Образ на основе Alpine Linux
`FROM alpine:3.7`

##### Создание томов
`docker volume create reddit_db`
```
docker run -d --network=reddit --network-alias=post_db \
--network-alias=comment_db -v reddit_db:/data/db mongo:latest
```

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
