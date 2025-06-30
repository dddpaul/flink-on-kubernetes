CLUSTER=flink
HELM_FLINK_NAME=flink
KAFKA_NAMESPACE=kafka

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-cluster.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f metrics-server.yaml
	@kubectl apply -f flink-nodeports.yaml
	@kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml

load-flink:
	@docker pull ghcr.io/apache/flink-kubernetes-operator:0d40e65
	@kind load docker-image ghcr.io/apache/flink-kubernetes-operator:0d40e65 --name ${CLUSTER} --nodes ${CLUSTER}-worker &

load-minio:
	@docker pull minio/minio:latest
	@kind load docker-image minio/minio:latest --name ${CLUSTER} --nodes ${CLUSTER}-worker &

load-kafka:
	@docker pull quay.io/strimzi/operator:0.46.1
	@kind load docker-image quay.io/strimzi/operator:0.46.1 --name ${CLUSTER} --nodes ${CLUSTER}-worker &
	@docker pull quay.io/strimzi/kafka:0.46.1-kafka-4.0.0
	@kind load docker-image quay.io/strimzi/kafka:0.46.1-kafka-4.0.0 --name ${CLUSTER} --nodes ${CLUSTER}-worker &

load-jobs:
	@docker pull flink:1.20-java17
	@kind load docker-image flink:1.20-java17 --name ${CLUSTER} --nodes ${CLUSTER}-worker &
	@kind load docker-image decodable-examples/hello-world-job:1.0 --name ${CLUSTER} --nodes ${CLUSTER}-worker

load: load-flink load-minio load-kafka load-jobs

helm:
	@helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.12.0/
	@helm repo update

install-flink:
	@helm upgrade -i ${HELM_FLINK_NAME} flink-operator-repo/flink-kubernetes-operator -f helm-values.yaml 

install-minio:
	@kubectl apply -f storage/

install-kafka:
	@kubectl create namespace ${KAFKA_NAMESPACE}
	@kubectl apply -f flink-nodeports.yaml
	@kubectl create -n ${KAFKA_NAMESPACE} -f kafka/kafka-operator.yaml
	@kubectl apply -n ${KAFKA_NAMESPACE} -f kafka/kafka-single-node.yaml 
	@kubectl wait ${KAFKA_NAMESPACE}/my-cluster -n ${KAFKA_NAMESPACE} --for=condition=Ready --timeout=300s 

install: helm install-flink install-minio install-kafka

basic:
	@kubectl apply -f flink/basic.yaml

custom:
	@kubectl apply -f flink/custom-job.yaml

uninstall-kafka:
	@kubectl -n ${KAFKA_NAMESPACE} delete `kubectl get strimzi -o name -n kafka`
	@kubectl delete pvc -n ${KAFKA_NAMESPACE} -l strimzi.io/name=my-cluster-kafka 
	@kubectl -n ${KAFKA_NAMESPACE} delete -f kafka/kafka-operator.yaml
	@kubectl delete namespace ${KAFKA_NAMESPACE}

uninstall-jobs:
	@kubectl delete --ignore-not-found=true FlinkDeployment basic-example
	@kubectl delete --ignore-not-found=true FlinkDeployment custom-job

uninstall: uninstall-kafka uninstall-jobs
	@helm uninstall ${HELM_FLINK_NAME}
	
destroy:
	@kind delete cluster --name ${CLUSTER}

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh

resource-capacity:
	kubectl resource-capacity -u -p -n default -l "app.kubernetes.io/instance=flink" --pod-count

goflow-producer:
	@docker ps -a -q -f name=^goflow-producer$ | xargs -r docker rm -f
	@docker run --name goflow-producer --net kind -p 2055:2055/udp -d netsampler/goflow2:v2.2.3 -transport kafka -transport.kafka.brokers 172.18.0.3:30100 -transport.kafka.topic flow-messages

goflow-consumer:
	@docker ps -a -q -f name=^goflow-consumer$ | xargs -r docker rm -f
	@docker run --name goflow-consumer --net kind -d quay.io/strimzi/kafka:0.46.1-kafka-4.0.0 bin/kafka-console-consumer.sh --bootstrap-server 172.18.0.3:30100 --topic flow-messages --from-beginning

goflow: goflow-producer goflow-consumer
