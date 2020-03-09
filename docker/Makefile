.DEFAULT_GOAL := help

REGISTRY = andrewmbr

help:
	echo Build docker images and pushing them to hub. Example: make 'docker-all'

docker-all: docker-ui docker-comment docker-post docker-prometheus docker-cloudprober docker-alertmanager docker-all-push

docker-ui:
	cd ../src/ui && docker build -t ${REGISTRY}/ui .

docker-comment:
	cd ../src/comment && docker build -t ${REGISTRY}/comment .

docker-post:
	cd ../src/post-py && docker build -t ${REGISTRY}/post .

docker-cloudprober:
	cd ../monitoring/cloudprober && docker build -t ${REGISTRY}/cloudprober .

docker-mongodb-exporter:
	cd ../monitoring/mongodb-exporter && docker build -t ${REGISTRY}/mongodb-exporter .

docker-prometheus:
	cd ../monitoring/prometheus && docker build -t ${REGISTRY}/prometheus .

docker-alertmanger:
        cd ../monitoring/alertmanger && docker build -t ${REGISTRY}/alertmanger .

docker-all-push: docker-ui-push docker-comment-push docker-post-push docker-cloudprober-push docker-prometheus-push

docker-ui-push:
	docker push andrewmbr/ui:latest

docker-comment-push:
	docker push andrewmbr/comment:latest

docker-post-push:
	docker push andrewmbr/post:latest

docker-cloudprober-push:
	docker push andrewmbr/cloudprober:latest

docker-prometheus-push:
	docker push andrewmbr/ui:latest

docker-alertmanger-push:
        docker push andrewmbr/alertmanger:latest
