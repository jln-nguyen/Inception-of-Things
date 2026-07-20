#!/bin/bash
apt-get update -o Acquire::Check-Valid-Until=false
apt-get install -y curl

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="--node-ip 192.168.56.110 --flannel-iface eth1 --write-kubeconfig-mode 644" \
  sh -

until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  echo "Waiting for K3s..."
  sleep 5
done

mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube/config
echo "alias k='kubectl'" >> /home/vagrant/.bashrc

kubectl apply -f /vagrant/confs/app-one.yaml

echo "Master ready"