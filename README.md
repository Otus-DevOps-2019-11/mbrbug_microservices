M# mbrbug_microservices
mbrbug microservices repository

### №19

Gitlab CI Omnibus
```
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'http://35.205.115.90/'
      # Add any other gitlab.rb configuration here, each on its own line
  ports:
    - '80:80'
    - '443:443'
    - '22:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'
```
Регистация первого пользователя, создание проекта
добавление еще одного удаленного репо и push в него  
`git remote add gitlab http://<your-vm-ip>/homework/example.git`
`git push gitlab gitlab-ci-1`

создание файла .gitlab-ci.yml  
создание runner
```docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```
```
 docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false
```

Директива only описывает список условий, которые должны быть
истинны, чтобы job мог запуститься.
Регулярное выражение слева означает, что должен стоять
semver тэг в git, например, 2.4.10

```only:
 - /^\d+\.\d+\.\d+/
```
```
git tag 2.4.10
git push gitlab gitlab-ci-1 --tags
```
### №17 Docker: сети, docker-compose
<details>
  <summary>Docker: сети, docker-compose</summary>
Базовое имя проекта задается именем папки. Возможно переопределить ключем
```
-p, --project-name NAME     Specify an alternate project name
                              (default: directory name)
```
##### Сети в Docker
- none (только loopback)
- host (доступ к собственному пространству хоста)
- bridge (у контейнеров, которые используют одинаковую сеть, есть своя собственная подсеть, и они могут передавать данные друг другу по умолчанию)

```
--name <name> (можно задать только 1 имя)
--network-alias <alias-name> (можно задать множество алиасов)
```
по алиасу можно обращаться к контейнеру

`docker network connect <network> <container>`
подключение контейнера к сети

##### Docker-compose

docker-compose.yml
```
version: '3.3'
services:
  post_db:
    image: mongo:3.2
    volumes:
      - post_db:/data/db
    networks:
      - reddit
  ui:
    build: ./ui
    image: ${USERNAME}/ui:1.0
    ports:
      - 9292:9292/tcp
    networks:
      - reddit
  post:
    build: ./post-py
    image: ${USERNAME}/post:1.0
    networks:
      - reddit
  comment:
    build: ./comment
    image: ${USERNAME}/comment:1.0
    networks:
      - reddit

volumes:
  post_db:

networks:
  reddit:
```
несколько сетей
```
networks:
  - front_net
  - back_net
```

##### docker-compose.override.yml
Файл для переопределения существующих сервисов или определения новых
```
services:
 ui:
   command: puma --debug -w 2
```
переоределяем параметры запуска приложения в контейнере ui
</details>

### №16 Docker-образы. Микросервисы

<details>
  <summary>Docker-образы. Микросервисы</summary>

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
</details>

### №15 Технология контейнеризации. Введение в Docker

<details>
  <summary>Технология контейнеризации. Введение в Docker</summary>

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
</details>
