#! /bin/bash

echo "Installing docker..."

apt-get update
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

docker version

echo "Docker installed !"

echo "Installing K3d..."

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

k3d version

echo "k3d installed !"

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

echo "Creating K3d cluster..."
k3d cluster create mycluster
kubectl get nodes
echo "Cluster ready !"

mkdir -p /home/$SUDO_USER/.kube
k3d kubeconfig get mycluster > /home/$SUDO_USER/.kube/config
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.kube

echo "Creating namespaces..."
kubectl create namespace argocd
kubectl create namespace dev
kubectl get namespaces
echo "Namespaces created !"

echo "Installing Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.14.11/manifests/install.yaml

echo "Waiting for Argo CD pods..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

kubectl get pods -n argocd
echo "Argo CD installed !"

kubectl apply -f ../confs/argocd-app.yaml

kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo

while true; do kubectl port-forward svc/argocd-server -n argocd 8080:443; done > /dev/null 2>&1 &
while true; do kubectl port-forward svc/wil-playground -n dev 8888:8888; done > /dev/null 2>&1 &