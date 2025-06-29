CLUSTER=flink
HELM_FLINK_NAME=flink

cluster:
	@kind create cluster --name ${CLUSTER} --config kind-cluster.yaml
	@kubectl cluster-info --context kind-${CLUSTER}
	@kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml

helm:
	@helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.12.0/
	@helm repo update

install-flink:
	@helm upgrade -i ${HELM_FLINK_NAME} flink-operator-repo/flink-kubernetes-operator -f helm-values.yaml 

install: helm install-flink

uninstall:
	@helm uninstall ${HELM_FLINK_NAME}
	

destroy:
	@kind delete cluster --name ${CLUSTER}

curl:
	kubectl run curl --image=curlimages/curl -i --tty -- sh

resource-capacity:
	kubectl resource-capacity -u -p -n default -l "app.kubernetes.io/instance=flink" --pod-count
