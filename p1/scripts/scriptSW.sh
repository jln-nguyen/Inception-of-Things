#! /bin/bash

apt-get update -o Acquire::Check-Valid-Until=false
apt-get install -y curl

# MASTER_IP=$1

echo "installing k3s"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.8+k3s1 \
  K3S_URL="https://192.168.56.110:6443" \
  K3S_TOKEN="MyToken" \
  INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=eth1" \
  sh -

echo "agent ready"