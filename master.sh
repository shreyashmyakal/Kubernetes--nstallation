#!/bin/bash

echo "### INITIALIZING CLUSTER with low resources ###"

sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version v1.29.0 \
  --ignore-preflight-errors=NumCPU,Mem

# Wait a bit for control-plane to come up
sleep 10

echo "### Configuring kubectl ###"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "### Installing a LIGHT network plugin (Flannel instead of Calico) ###"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml --validate=false

echo "### Generate Join Command ###"
kubeadm token create --print-join-command
