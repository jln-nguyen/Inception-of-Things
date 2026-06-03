#!/bin/sh
apt-get update -o Acquire::Check-Valid-Until=false
apt-get install -y curl

curl -sfL https://get.k3s.io | sh -

# Attendre que K3s soit prêt
sleep 30
systemctl status k3s