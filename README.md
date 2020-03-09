# mbrbug_microservices
mbrbug microservices repository

### №21 Мониторинг приложения и инфраструктуры

Разворачиваем через docker-machine виртуалку

##### cAdvisor
cAdvisor собирает информацию о ресурсах потребляемых
контейнерами и характеристиках их работы
docker-compose
```
services:
...
cadvisor:
image: google/cadvisor:v0.29.0
volumes:
- '/:/rootfs:ro'
- '/var/run:/var/run:rw'
- '/sys:/sys:ro'
- '/var/lib/docker/:/var/lib/docker:ro'
ports:
- '8080:8080'
```
prometheus.yml
```
scrape_configs:
...
- job_name: 'cadvisor'
static_configs:
- targets:
- 'cadvisor:8080'
```
и пересборка образа prometheus_net
`docker build -t $USER_NAME/prometheus .`

##### Grafana
Визуализация метрик
```
services:
...
grafana:
image: grafana/grafana:5.0.0
volumes:
- grafana_data:/var/lib/grafana
environment:
- GF_SECURITY_ADMIN_USER=admin
- GF_SECURITY_ADMIN_PASSWORD=secret
depends_on:
- prometheus
ports:
- 3000:3000
...
volumes:
grafana_data:
```
добавляем источники данных, дашборды
сбор метрик
rate()
histogram_quantile()

##### Alerting
Alertmanager в Prometheus
```
FROM prom/alertmanager:v0.14.0
ADD config.yml /etc/alertmanager/
```
config.yml
```
global:
slack_api_url:
'https://hooks.slack.com/services/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'
#Заменяем на свои значения
route:
receiver: 'slack-notifications'
receivers:
- name: 'slack-notifications'
slack_configs:
- channel: '#userchannel' #Заменяем на свои значения
```
docker-compose
```
services:
...
alertmanager:
image: ${USER_NAME}/alertmanager
command:
- '--config.file=/etc/alertmanager/config.yml'
ports:
- 9093:9093
```
##### alert rules
monitoring/prometheus/alerts.yml
```
groups:
- name: alert.rules
rules:
- alert: InstanceDown
expr: up == 0 # любое PromQL выражение
for: 1m # В течении какого времени, по умолчанию 0
labels: # Дополнительные метки
severity: page
annotations:
description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for
more than 1 minute'
summary: 'Instance {{ $labels.instance }} down'
```

правила в настройках
```
rule_files:
- "alerts.yml"
alerting:
alertmanagers:
- scheme: http
static_configs:
- targets:
- "alertmanager:9093"
```
##### Метрики через настройки Docker
docker daemon.json
```
{
  "metrics-addr" : "127.0.0.1:9323",
  "experimental" : true
}
```
prometheus job
```
- job_name: 'docker'
    static_configs:
      - targets: ['10.132.0.21:9323']
```
##### Telegraf от InfluxDB
docker-compose
```
telegraf:
  image: ${USERNAME1}/telegraf
  volumes:
   - '/var/run/docker.sock:/var/run/docker.sock'
  networks:
   - prometheus_net

 influxdb:
  image: influxdb
  volumes:
   - 'influxdb_data:/var/lib/influxdb'
  networks:
   - prometheus_net
```
job
```
- job_name: 'telegraf'
  static_configs:
    - targets: ['telegraf:9126']
```
##### импорт источников и дашбордов в Grafana
provisioning/dashboards/my_dashboards.yml
provisioning/datasources/my_datasource.yml

##### Сбор метрик со Stackdriver c помощью образа Docker
```
stackdriver-exporter:
  image: andrewmbr/stackdriver
  ports:
   - 9255:9255
  networks:
   - prometheus_net
  environment:
   - GOOGLE_APPLICATION_CREDENTIALS=/opt/gcp-key/gcp-key.json
   - STACKDRIVER_EXPORTER_GOOGLE_PROJECT_ID=docker-266911
   - STACKDRIVER_EXPORTER_MONITORING_METRICS_TYPE_PREFIXES=compute.googleapis.com/instance/cpu,compute.googleapis.com/instance/disk
```
##### proxy trickster
```
trickster:
 image: tricksterio/trickster
 networks:
  - prometheus_net
 environment:
  - TRK_ORIGIN=http://prometheus:9090
  - TRK_ORIGIN_TYPE=prometheus
  - TRK_PROXY_PORT=8000
  - TRK_METRICS_PORT=8001
 ports:
   - '8000:8000'
   - '8001:8001'
```
а в графане указываем порт 8000


### №20 Введение в мониторинг. Системы мониторинга.
<details>
  <summary>Введение в мониторинг. Системы мониторинга.</summary>

Запуск prometheus
```
docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus:v2.1.0
```
Targets (цели) - представляют собой системы или процессы, за
которыми следит Prometheus конфиг файл Prometheus
```
--- global:
  scrape_interval: '5s' scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets:
        - 'localhost:9090'
  - job_name: 'ui'
    static_configs:
      - targets:
        - 'ui:9292'
  - job_name: 'comment'
    static_configs:
      - targets:
        - 'comment:9292'
  - job_name: 'node'
    static_configs:
     - targets:
       - 'node-exporter:9100'
  - job_name: 'mongodb'
    static_configs:
     - targets:
       - 'mongodb-exporter:9216'
  - job_name: 'cloudprober'
    scrape_interval: 10s
    static_configs:
     - targets:
       - 'cloudprober-exporter:9313'
       ```
       Создаем "свой" Prometheus
       ```
       FROM prom/prometheus:v2.1.0 ADD prometheus.yml /etc/prometheus/
       ```
       prometheus в docker-compose
```
services: ...
  prometheus:
    image: ${USERNAME}/prometheus
    ports:
      - '9090:9090'
    volumes:
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d' volumes:
  prometheus_data: ```
##### Сбор метрик хоста
###### Node exporter
образ docker ``` node-exporter:
 image: prom/node-exporter:v0.15.2
 user: root
 volumes:
 - /proc:/host/proc:ro
 - /sys:/host/sys:ro
 - /:/rootfs:ro
 command:
 - '--path.procfs=/host/proc'
 - '--path.sysfs=/host/sys'
 - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"' ``` в конфиг самого prometheus ``` scrape_configs: ...
 - job_name: 'node'
 static_configs:
 - targets:
 - 'node-exporter:9100' ```
##### mongodb_exporter
в конфиг docker-compose ``` mongodb-exporter:
    image: bitnami/mongodb-exporter:${MONGO_EXP_VER}
    networks:
      - prometheus_net
      - back_net
    environment:
      MONGODB_URI: "mongodb://post_db:27017" ``` в конфиг самого prometheus ``` - job_name: 'mongodb'
  static_configs:
   - targets:
     - 'mongodb-exporter:9216' ```
##### cloudprober
###### Dockerfile
``` FROM cloudprober/cloudprober COPY cloudprober.cfg /etc/cloudprober.cfg ENTRYPOINT ["/cloudprober", "--logtostderr"] ```
###### /etc/cloudprober.cfg конфиг в образе
``` probe {
  name: "google_homepage"
  type: HTTP
  targets {
    host_names: "www.google.com"
  }
  interval_msec: 5000 # 5s
  timeout_msec: 1000 # 1s
}
probe {
    name: "ui_page"
    type: HTTP
    targets {
        host_names: "35.205.115.90"
    }
    http_probe {
      protocol: HTTP
      port: 9292
    }
    interval_msec: 5000 # Probe every 5s
    }
probe {
    name: "comment"
    type: HTTP
    targets {
        host_names: "comment"
    }
    http_probe {
      protocol: HTTP
      port: 9292
    }
    interval_msec: 5000 # Probe every 5s
    }
```
###### docker-compose
``` cloudprober-exporter:
  image: ${USERNAME1}/cloudprober
  networks:
    - prometheus_net
    - back_net
    - front_net ```
###### prometheus.yml
``` cloudprober-exporter:
  image: ${USERNAME1}/cloudprober
  networks:
    - prometheus_net
    - back_net
    - front_net ```
##### Makefile
``` .DEFAULT_GOAL := help REGISTRY = andrewmbr help:
        echo Build docker images and pushing them to hub. Example: make 'docker-all' docker-all: docker-ui docker-comment docker-post docker-prometheus
docker-cloudprober docker-all-push docker-ui:
        cd ../src/ui && docker build -t ${REGISTRY}/ui . docker-comment:
        cd ../src/comment && docker build -t ${REGISTRY}/comment . docker-post:
        cd ../src/post-py && docker build -t ${REGISTRY}/post . docker-cloudprober:
        cd ../monitoring/cloudprober && docker build -t ${REGISTRY}/cloudprober . docker-mongodb-exporter:
        cd ../monitoring/mongodb-exporter && docker build -t ${REGISTRY}/mongodb-exporter . docker-prometheus:
        cd ../monitoring/prometheus && docker build -t ${REGISTRY}/prometheus . docker-all-push: docker-ui-push docker-comment-push docker-post-push
docker-cloudprober-push docker-prometheus-push docker-ui-push:
        docker push andrewmbr/ui:latest docker-comment-push:
        docker push andrewmbr/comment:latest docker-post-push:
        docker push andrewmbr/post:latest
docker-cloudprober-push:
        docker push andrewmbr/cloudprober:latest

docker-prometheus-push:
        docker push andrewmbr/ui:latest ```

</details>

### №19
<details>
  <summary>Gitlab CI</summary>

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
</details>

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
