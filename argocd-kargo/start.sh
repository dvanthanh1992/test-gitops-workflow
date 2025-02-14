#!/bin/bash

load_env() {
    if [ -f "local.env" ]; then
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^# && "$line" =~ = ]]; then
                export "$line"
            fi
        done < "local.env"
        echo "✅ Loaded environment variables. K8S_PROJECT_NAME=$K8S_PROJECT_NAME"
    else
        echo "⚠️  local.env file not found. Skipping environment loading."
    fi
}

install_all() {
    echo "${K8S_PROJECT_NAME}"
    echo "🚀 Installing ArgoCD and Kargo Applications..."
    echo "-----------------------------------------------"

    echo "🔹 Installing ArgoCD Application..."
    envsubst < argocd-application-set.yml | kubectl apply -f -

    echo "-----------------------------------------------"

    echo "🔹 Installing Kargo Application..."
    envsubst < kargo.yml | kubectl apply -f -

    echo "-----------------------------------------------"

    echo "✅ Installation completed!"
}

delete_all() {
    echo "🗑️  Deleting ArgoCD and Kargo Applications..."
    echo "-----------------------------------------------"

    echo "🔹 Deleting Kargo Application..."
    envsubst < kargo.yml | kubectl delete -f -

    echo "-----------------------------------------------"

    echo "🔹 Deleting ArgoCD Application..."
    kubectl delete applications    --all -n argocd --force --grace-period=0
    kubectl delete applicationsets --all -n argocd --force --grace-period=0
    kubectl delete appprojects     --all -n argocd --force --grace-period=0
    echo "✅ Deletion completed!"

    sleep 5
    kubectl get applications -n argocd
    kubectl get applicationsets -n argocd
}

usage() {
    echo "Usage: $0 {install|delete}"
    exit 1
}

main() {
    if [ "$#" -ne 1 ]; then
        usage
    fi

    ACTION=$1
    load_env

    case "$ACTION" in
        install)
            install_all
            ;;
        delete)
            delete_all
            ;;
        *)
            echo "❌ Invalid action: $ACTION"
            usage
            ;;
    esac
}

main "$@"
