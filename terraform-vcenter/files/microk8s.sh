#!/bin/bash

set -e

K8S_VERSION="1.29"

echo "📌 Installing MicroK8s version: %s\n" "$K8S_VERSION"
echo "-----------------------------------\n"
apt-get update -y
apt-get install -y snapd

echo "-----------------------------------\n"
snap install microk8s --classic --channel="${K8S_VERSION}"
echo "✅ Installed MicroK8s!\n"
echo "-----------------------------------\n"

echo "🔧 Configuring MicroK8s...\n"
echo "-----------------------------------\n"
microk8s enable rbac ingress hostpath-storage metallb:192.168.145.180-192.168.145.199
echo "🎉 MicroK8s setup completed!\n"
echo "-----------------------------------\n"
