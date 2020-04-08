# mbrbug_microservices
mbrbug microservices repository

### №28 CI/CD в Kubernetes
#### Helm - пакетный менеджер для Kubernetes
Серверная часть
1) tiller.yml
```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
```
2) `helm init --service-account tiller`

проверка
`kubectl get pods -n kube-system --selector app=helm`

#### Chart - это пакет в Helm
Chart.yaml
```
name: ui
version: 1.0.0
description: OTUS reddit application UI
maintainers:
- name: Someone
email: my@mail.com
appVersion: 1.0
```
установка Chart
`helm install --name test-ui-1 ui/`

#### Шаблонизация Chart
```
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-{{ .Chart.Name }}
  labels:
    app: reddit
    component: ui
    release: {{ .Release.Name }}
spec:
  type: NodePort
  ports:
  - port: {{ .Values.service.externalPort }}
    protocol: TCP
    targetPort: 9292
  selector:
    app: reddit
    component: ui
    release: {{ .Release.Name }}
```
name: {{ .Release.Name }}-{{ .Chart.Name }}
Здесь мы используем встроенные переменные
.Release - группа переменных с информацией о релизе
(конкретном запуске Chart’а в k8s)
.Chart - группа переменных с информацией о Chart’е (содержимое
файла Chart.yaml)
Также еще есть группы переменных:
.Template - информация о текущем шаблоне ( .Name и .BasePath)
.Capabilities - информация о Kubernetes (версия, версии API)
.Files.Get - получить содержимое файла

#### Переменные
```
service:
internalPort: 9292
externalPort: 9292
image:
repository: chromko/ui
tag: latest
```
`"{{ .Values.image.repository }}:{{ .Values.image.tag }}`


##### helpers
```
{{- define "comment.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name }}
{{- end -}}
```
которая в результате выдаст то же, что и:
```
{{ .Release.Name }}-{{ .Chart.Name }}
```
вставлять
`{{ template "comment.fullname" . }}`

#### Управление зависимостями
requirements.yaml
```
dependencies:
- name: ui
version: "1.0.0"
repository: "file://../ui"
- name: post
version: "1.0.0"
repository: file://../post
- name: comment
version: “1.0.0"
repository: file://../comment
```
`helm dep update`

#### Chart repo
`helm search mongo`

#### helm2 tiller plugin
```
helm init --client-only
helm plugin install https://github.com/rimusz/helmtiller
helm tiller run -- helm upgrade --install --wait --namespace=reddit-ns reddit reddit/
```

#### GitLab + Kubernetes
Gitlab Helm Chart
`helm repo add gitlab https://charts.gitlab.io`
скачать локально
`helm fetch gitlab/gitlab-omnibus --version 0.1.37 --untar`
установка
`helm install --name gitlab . -f values.yaml`

```
$ git init
$ git remote add origin http://gitlab-gitlab/chromko/ui.git
$ git add .
$ git commit -m “init”
$ git push origin master
```



### №27 Kubernetes. Networks ,Storages
<details>
  <summary>Kubernetes. Networks ,Storages</summary>

Service и способ коммуникации
- ClusterIP - дойти до сервиса можно только изнутри кластера
- nodePort - клиент снаружи кластера приходит на опубликованный порт
- LoadBalancer - клиент приходит на облачный (aws elb, Google gclb) ресурс балансировки
- ExternalName - внешний ресурс по отношению к кластеру

`kubectl get services -n dev`
`kubectl scale deployment --replicas 0 -n kube-system kube-dnsautoscaler`

LoadBalancer
```
spec:
 type: LoadBalancer
 ports:
 - port: 80
 nodePort: 32092
 protocol: TCP
 targetPort: 9292
 selector:
 app: reddit
 component: ui
```

Ingress
```
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
 name: ui
spec:
 backend:
 serviceName: ui
 servicePort: 80
```
`kubectl get ingress -n dev`

```
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
 name: ui
spec:
 rules:
 - http:
 paths:
 - path: /*
 backend:
 serviceName: ui
 servicePort: 9292
```

Secret
`openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=35.190.66.90"`
`kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev`

```
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
 name: ui
 annotations:
 kubernetes.io/ingress.allow-http: "false"
spec:
 tls:
 - secretName: ui-ingress
 backend:
 serviceName: ui
 servicePort: 9292
```

`gcloud beta container clusters list`
`gcloud beta container clusters update <cluster-name> \
 --zone=us-central1-a --update-addons=NetworkPolicy=ENABLED
`
`gcloud beta container clusters update <cluster-name> \
 --zone=us-central1-a --enable-network-policy`

```
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
 name: deny-db-traffic
 labels:
 app: reddit
spec:
 podSelector:
 matchLabels:
 app: reddit
 component: mongo
 policyTypes:
 - Ingress
 ingress:
 - from:
 - podSelector:
 matchLabels:
 app: reddit
 component: comment
```

Хранилище

```
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
 name: mongo
…
 spec:
 containers:
 - image: mongo:3.2
 name: mongo
 volumeMounts:
 - name: mongo-persistent-storage
 mountPath: /data/db
 volumes:
 - name: mongo-persistent-storage
 emptyDir: {}
```
Volume gcePersistentDisk
PersistentVolume
PersistentVolumeClaim


` kubectl describe storageclass standard -n dev`

```
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
 name: mongo
…
 spec:
 containers:
 - image: mongo:3.2
 name: mongo
 volumeMounts:
 - name: mongo-persistent-storage
 mountPath: /data/db
 volumes:
 - name: mongo-persistent-storage
 persistentVolumeClaim:
 claimName: mongo-pvc
```

StorageFast

```
---
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
 name: fast
provisioner: kubernetes.io/gce-pd
parameters:
 type: pd-ssd
```
</details>

### №26 Основные модели безопасности и контроллеры в Kubernetes

<details>
  <summary>Основные модели безопасности и контроллеры в Kubernetes</summary>
Установка kubectl
https://kubernetes.io/docs/tasks/tools/install-kubectl/

Установка Minikube
https://kubernetes.io/docs/tasks/tools/install-minikube/

`minikube start`

Информацию о контекстах kubectl сохраняет в файле
`~/.kube/config`

Обычно порядок конфигурирования kubectl следующий:
Создать cluster:
`kubectl config set-cluster … cluster_name`
Создать данные пользователя (credentials)
`kubectl config set-credentials … user_name`
Создать контекст
```
kubectl config set-context context_name \
--cluster=cluster_name \
--user=user_name
```
Использовать контекст
`kubectl config use-context context_name`

Текущий контекст
`kubectl config current-context`
Список всех контекстов
`kubectl config get-contexts`

Запуск в Minikube
`kubectl apply -f ui-deployment.yml`
`kubectl get deployment`
`kubectl get pods`

```
kubectl get pods --selector component=ui
kubectl port-forward <pod-name> 8080:9292
```

###### Монтирование стандартного Volume для хранения данных вне контейнера
```
apiVersion: apps/v1beta2
kind: Deployment
…
 containers:
 - image: mongo:3.2
 name: mongo
 volumeMounts:
 - name: mongo-persistent-storage
 mountPath: /data/db
 volumes:
 - name: mongo-persistent-storage
 emptyDir: {}
```

##### Services
comment-service.yml
```
---
apiVersion: v1
kind: Service
metadata:
 name: comment
 labels:
 app: reddit
 component: post
spec:
 ports:
 - port: 9292
 protocol: TCP
 targetPort: 9292
 selector:
 app: reddit
 component: comment
```

`kubectl describe service comment `
`kubectl exec -ti <pod-name> nslookup comment`
`kubectl port-forward <pod-name> 9292:9292`
`kubectl logs post-56bbbf6795-7btnm`

```
---
apiVersion: v1
kind: Service
metadata:
 name: comment-db
 labels:
 app: reddit
 component: mongo
 comment-db: "true"
spec:
 ports:
 - port: 27017
 protocol: TCP
 targetPort: 27017
 selector:
 app: reddit
 component: mongo
 comment-db: "true"
```

nodePort
```
spec:
 type: NodePort
 ports:
- nodePort: 32092
 port: 9292
 protocol: TCP
 targetPort: 9292
 selector:

```

`minikube services list`
` minikube addons list`

##### Namespaces
`kubectl get all -n kube-system --selector k8s-app=kubernetes-dashboard`
`minikube service kubernetes-dashboard -n kube-system`

dev-namespace.yml
```
---
apiVersion: v1
kind: Namespace
metadata:
 name: dev
```
`kubectl apply -f dev-namespace.yml`
`minikube service ui -n dev`
</details>

### #25 Введение в Kubernetes

<details>
  <summary>Введение в Kubernetes</summary>

##### пример Deployment манифест
```
apiVersion: apps/v1
kind: Deployment
metadata:
name: post-deployment
spec:
replicas: 1
# Указатель на то, какие поды нужно поддерживать в нужном количестве
selector:
matchLabels:
app: post
template:
metadata:
name: post-pod
labels:
app: post
spec:
containers:
- image: andrewmbr/post
name: post
```

```
apiVersion: apps/v1beta2
kind: Deployment
metadata:
 name: comment
…
 containers:
 - image: chromko/comment
 name: comment
 env:
 - name: COMMENT_DATABASE_HOST
 value: comment-db
```

`gcloud container clusters get-credentials cluster-1 --zone us-central1-a --project docker-182408`
`kubectl get nodes -o wide`
`kubectl describe service ui -n dev | grep NodePort`

##### Kubernetes The Hard Way
https://github.com/kelseyhightower/kubernetes-the-hard-way

</details>


### №23 Логирование и распределенная трассировка

<details>
  <summary>Логирование и распределенная трассировка</summary>

ветка logging-1
#### Elastic Stack
EFK и ELK
- ElasticSearch (TSDB и поисковый движок для хранения данных)
- Logstash (для агрегации и трансформации данных)
- Kibana (для визуализации)
или вместо Logstash - fluentd

##### docker/docker-compose-logging.yml
```
version: '3'
services:

fluentd:
build: ./fluentd
ports:
- "24224:24224"
- "24224:24224/udp"

elasticsearch:
image: elasticsearch
expose:
- 9200
ports:
- "9200:9200"

kibana:
image: kibana
ports:
- "5601:5601"
```

##### fluentd Dockerfile
```
FROM fluent/fluentd:v0.12
RUN gem install fluent-plugin-elasticsearch --no-rdoc --no-ri --version 1.9.5
RUN gem install fluent-plugin-grok-parser --no-rdoc --no-ri --version 1.0.0
ADD fluent.conf /fluentd/etc
```

fluentd.conf
```
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<filter service.post>
  @type parser
  format json
  key_name log
</filter>

<filter service.ui>
  @type parser
  key_name log
  format grok
  grok_pattern %{RUBY_LOGGER}
</filter>

<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message='%{GREEDYDATA:message}'
  key_name message
  reserve_data true
</filter>

<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{GREEDYDATA:request_id} \| remote_addr=%{IPORHOST:remote_add$
  key_name message
  reserve_data false
</filter>

<match *.**>
  @type copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>
  <store>
    @type stdout
  </store>
</match>
```

##### Структурированные логи
docker драйвер fluentd
```
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.ui

```

#### Kibana

индекс fluentd
`fluentd-*`
##### фильтры Kibana
```
<filter service.post>
@type parser
format json
key_name log
</filter>
```
```
<match *.**>
  @type copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>
  <store>
    @type stdout
  </store>
</match>
```

##### Неструктурированные логи
###### Парсинг
```
<filter service.post>
@type parser
format json
key_name log
</filter>
<filter service.ui>
@type parser
format /\[(?<time>[^\]]*)\] (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*
(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method=
(?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
key_name log
</filter>
```

##### Распределенный трейсинг
```
services:
zipkin:
image: openzipkin/zipkin
ports:
- "9411:9411"
networks:
- front_net
- back_net
networks:
back_net:
front_net:
```
</details>

### №21 Мониторинг приложения и инфраструктуры

<details>
  <summary>Введение в мониторинг. Системы мониторинга.</summary>

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
</details>

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
  prometheus_data:
```
##### Сбор метрик хоста
###### Node exporter
образ docker
```
node-exporter:
 image: prom/node-exporter:v0.15.2
 user: root
 volumes:
 - /proc:/host/proc:ro
 - /sys:/host/sys:ro
 - /:/rootfs:ro
 command:
 - '--path.procfs=/host/proc'
 - '--path.sysfs=/host/sys'
 - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
 ```
 в конфиг самого prometheus
 ```
 scrape_configs: ...
 - job_name: 'node'
 static_configs:
 - targets:
 - 'node-exporter:9100'
 ```
##### mongodb_exporter
в конфиг docker-compose
```
mongodb-exporter:
    image: bitnami/mongodb-exporter:${MONGO_EXP_VER}
    networks:
      - prometheus_net
      - back_net
    environment:
      MONGODB_URI: "mongodb://post_db:27017"
```
в конфиг самого prometheus
```
- job_name: 'mongodb'
  static_configs:
   - targets:
     - 'mongodb-exporter:9216'
```
##### cloudprober
###### Dockerfile
```
FROM cloudprober/cloudprober COPY cloudprober.cfg /etc/cloudprober.cfg ENTRYPOINT ["/cloudprober", "--logtostderr"]
```
###### /etc/cloudprober.cfg конфиг в образе
```
probe {
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
```
cloudprober-exporter:
  image: ${USERNAME1}/cloudprober
  networks:
    - prometheus_net
    - back_net
    - front_net
```
###### prometheus.yml
```
cloudprober-exporter:
  image: ${USERNAME1}/cloudprober
  networks:
    - prometheus_net
    - back_net
    - front_net
```
##### Makefile
```
.DEFAULT_GOAL := help REGISTRY = andrewmbr help:
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
        docker push andrewmbr/ui:latest
```

</details>

### №19 Gitlab CI
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
```
docker run -d --name gitlab-runner --restart always \
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

```
only:
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
