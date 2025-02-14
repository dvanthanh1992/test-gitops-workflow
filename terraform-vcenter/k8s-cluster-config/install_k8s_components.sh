#!/bin/bash

set -euo pipefail

K8S_VERSION="1.29"
CERT_MANAGER_CHART_VERSION="1.16.1"
ARGO_CD_CHART_VERSION="7.7.3"          # APP VERSION v2.13.0
ARGO_ROLLOUTS_CHART_VERSION="2.38.2"   # APP VERSION v1.7.2
HARBOR_CHART_PATH="harbor/"
HARBOR_VALUES_FILE="harbor_values.yaml"

echo "🔧 Installing Harbor..."
if ! helm upgrade --install harbor "$HARBOR_CHART_PATH" \
  -n harbor \
  -f "$HARBOR_VALUES_FILE" \
  --create-namespace \
  --wait; then
    echo "❌ Harbor installation failed." >&2
    exit 1
fi
echo "✅ Harbor installed successfully!"
echo "----------------------------------------------"

echo "🔧 Installing Cert-Manager..."
if ! helm install cert-manager cert-manager \
  --repo https://charts.jetstack.io \
  --version "$CERT_MANAGER_CHART_VERSION" \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait; then
    echo "❌ Cert-Manager installation failed." >&2
    exit 1
fi
echo "✅ Cert-Manager installed successfully!"
echo "----------------------------------------------"

echo "🔧 Installing Argo CD..."
if ! helm install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version "$ARGO_CD_CHART_VERSION" \
  --namespace argocd \
  --create-namespace \
  --set 'configs.secret.argocdServerAdminPassword=$2a$10$5vm8wXaSdbuff0m9l21JdevzXBzJFPCi8sy6OOnpZMAG.fOXL7jvO' \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set server.service.type=LoadBalancer \
  --set server.extensions.enabled=true \
  --set 'server.extensions.contents[0].name=argo-rollouts' \
  --set 'server.extensions.contents[0].url=https://github.com/argoproj-labs/rollout-extension/releases/download/v0.3.3/extension.tar' \
  --wait; then
    echo "❌ Argo CD installation failed." >&2
    exit 1
fi
echo "✅ Argo CD installed successfully!"
echo "----------------------------------------------"

echo "🔧 Installing Argo Rollouts..."
if ! helm install argo-rollouts argo-rollouts \
  --repo https://argoproj.github.io/argo-helm \
  --version "$ARGO_ROLLOUTS_CHART_VERSION" \
  --create-namespace \
  --namespace argo-rollouts \
  --wait; then
    echo "❌ Argo Rollouts installation failed." >&2
    exit 1
fi
echo "✅ Argo Rollouts installed successfully!"
echo "----------------------------------------------"

echo "🔧 Installing Kargo..."
if ! helm install kargo \
  oci://ghcr.io/akuity/kargo-charts/kargo \
  --namespace kargo \
  --create-namespace \
  --set service.type=LoadBalancer \
  --set api.adminAccount.passwordHash='$2a$10$Zrhhie4vLz5ygtVSaif6o.qN36jgs6vjtMBdM6yrU1FOeiAAMMxOm' \
  --set api.adminAccount.tokenSigningKey="iwishtowashmyirishwristwatch" \
  --wait; then
    echo "❌ Kargo installation failed." >&2
    exit 1
fi

echo "🔄 Patching kargo-api service to LoadBalancer..."
if ! kubectl patch svc kargo-api -n kargo --type='merge' -p '{"spec":{"type":"LoadBalancer"}}'; then
    echo "❌ Failed to patch kargo-api service to LoadBalancer." >&2
    exit 1
fi

echo "✅ kargo-api service patched to LoadBalancer!"
echo "----------------------------------------------"
echo "✅ Kargo installed successfully!"
echo "----------------------------------------------"

echo "🎉 All components installed successfully!"
echo "----------------------------------------------"

REGISTRY="192.168.145.182/kargo/demo-app"
VERSIONS=("5.0.0" "4.0.0" "3.0.0" "2.0.0" "1.0.0")

for VERSION in "${VERSIONS[@]}"; do
    IMAGE="$REGISTRY:$VERSION"
    
    echo "Pushing image: $IMAGE"
    docker push "$IMAGE"

    if [ $? -eq 0 ]; then
        echo "Successfully pushed $IMAGE"
    else
        echo "Failed to push $IMAGE"
        exit 1
    fi
done

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ../1-terraform-vcenter/files/vcenter_ssh_key root@192.168.145.171 bash /root/images.sh

echo "----------------------------------------------"
echo "🎉 All images pushed successfully!"
echo "----------------------------------------------"