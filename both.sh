#!/bin/bash

echo "### STEP 1: Disable Swap ###"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sleep 2

echo "### STEP 2: Load Required Kernel Modules ###"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
sleep 2

echo "### STEP 3: Optimize Sysctl for Networking ###"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sleep 2

echo "### STEP 4: Install Lightweight containerd ###"
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list

sudo apt-get update
sudo apt-get install -y containerd.io

# Minimal containerd config to save RAM
sudo mkdir -p /etc/containerd
containerd config default | sed \
  -e 's/SystemdCgroup = false/SystemdCgroup = true/' \
  -e 's/sandbox_image = "registry.k8s.io\/pause:3.6"/sandbox_image = "registry.k8s.io\/pause:3.9"/' \
  | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

echo "### STEP 5: Install Kubernetes components (small footprint) ###"
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Reduce kubelet memory eviction threshold for low-RAM
sudo mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/20-memory-limit.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--eviction-hard=memory.available<50Mi,nodefs.available<5%"
EOF

sudo systemctl daemon-reexec
sudo systemctl restart kubelet

echo "Node preparation DONE!"
