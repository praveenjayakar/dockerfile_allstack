#!/bin/bash

set -euo pipefail

# Function to handle dpkg lock issue
wait_for_dpkg_lock() {
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Waiting for dpkg lock to be released..."
    sleep 5
  done
}

# Disable swap
sudo swapoff -a
echo "Swap disabled."

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
echo "Kernel modules loaded."

# Configure sysctl for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
sysctl net.ipv4.ip_forward
echo "Sysctl parameters configured."

# Install prerequisites
wait_for_dpkg_lock
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg apt-transport-https
echo "Prerequisites installed."

# Set up Docker repository and install containerd
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

wait_for_dpkg_lock
sudo apt-get update
sudo apt-get install -y containerd.io
echo "Containerd installed."

# Configure containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sed 's/sandbox_image = "registry.k8s.io\/pause:3.6"/sandbox_image = "registry.k8s.io\/pause:3.9"/' | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "Containerd configured."

# Install Kubernetes components
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

wait_for_dpkg_lock
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
echo "Kubernetes components installed."

# Initialize the Kubernetes cluster
kubeip=$(ip -o -4 addr show eth0 | awk '{print $4}' | cut -d "/" -f1)
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${kubeip}
echo "Kubernetes cluster initialized."

wait_for_dpkg_lock

# Configure kubectl for the root user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "kubectl configured for root user."

# Untaint the control-plane node to allow scheduling workloads
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
echo "Control-plane node untainted."

wait_for_dpkg_lock

# Install Flannel network
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
echo "Flannel network installed."


# Wait for node readiness
echo "Waiting for nodes to be ready..."
sleep 30
kubectl get nodes -o wide

# Add an alias for kubectl
if ! grep -q "alias k=" ~/.bashrc; then
  echo "alias k=kubectl" >> ~/.bashrc
  source ~/.bashrc
fi

# Display success message
echo "Cluster setup complete! Use 'kubectl' (or 'k' if you use the alias) to manage your cluster."
