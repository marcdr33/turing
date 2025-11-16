set the cluster subscription:
az account set --subscription XXX

download cluster credentials:
az aks get-credentials --resource-group rg-XXX-pre-spc --name aks-XXX-pre-spc --overwrite-existing

Authentication using kubelogin:
kubelogin convert-kubeconfig -l azurecli

How to list all nodes:
kubectl get nodes

How to list all deployments:
kubectl get deployments --all-namespaces

How to list all pods:
kubectl get pods --all-namespaces

