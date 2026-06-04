#!/bin/bash

apt-get update -o Acquire::Check-Valid-Until=false
apt-get install -y curl

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="--node-ip 192.168.56.110 --flannel-iface eth1 --write-kubeconfig-mode 644" \
  K3S_TOKEN="MyToken" sh -

sleep 30 #use loop to wait till k3s is ready
sudo systemctl status k3s

sudo mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube/config

echo "alias k='kubectl'" >> /home/vagrant/.bashrc

echo "Master ready"