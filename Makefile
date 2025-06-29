CLUSTER=flink
HELM_FLINK_NAME=flink

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-cluster.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl apply -f flink-nodeports.yaml
	@kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml

load-flink:
	@docker pull ghcr.io/apache/flink-kubernetes-operator:0d40e65
	@kind load docker-image ghcr.io/apache/flink-kubernetes-operator:0d40e65 --name ${CLUSTER} --nodes ${CLUSTER}-worker &

load-minio:
	@docker pull minio/minio:latest
	@kind load docker-image minio/minio:latest --name ${CLUSTER} --nodes ${CLUSTER}-worker &

load-jobs:
	@docker pull flink:1.20-java17
	@kind load docker-image flink:1.20-java17 --name ${CLUSTER} --nodes ${CLUSTER}-worker &
	@kind load docker-image decodable-examples/hello-world-job:1.0 --name ${CLUSTER} --nodes ${CLUSTER}-worker

load: load-flink load-minio load-jobs

helm:
	@helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.12.0/
	@helm repo update

install-flink:
	@helm upgrade -i ${HELM_FLINK_NAME} flink-operator-repo/flink-kubernetes-operator -f helm-values.yaml 

install-minio:
	@kubectl apply -f storage/

install: helm install-flink install-minio

basic:
	@kubectl apply -f flink/basic.yaml

custom:
	@kubectl apply -f flink/custom-job.yaml

uninstall:
	@helm uninstall ${HELM_FLINK_NAME}
	
destroy:
	@kind delete cluster --name ${CLUSTER}

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh

resource-capacity:
	kubectl resource-capacity -u -p -n default -l "app.kubernetes.io/instance=flink" --pod-count
