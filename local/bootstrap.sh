#!/usr/bin/env bash
# 로컬 kind 클러스터에 EKS(dev)와 같은 플랫폼 구성을 올린다.
#   ArgoCD → nebula-root(App of Apps) → 서비스 ApplicationSet + Kyverno 정책 + 분석 템플릿
# 사용: GITOPS_TOKEN=<nebula-gitops 읽기 토큰> ./local/bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")"

ARGOCD_VERSION=10.9.6
ROLLOUTS_VERSION=2.43.5
KYVERNO_VERSION=3.9.1

if ! kind get clusters | grep -qx nebula; then
  kind create cluster --config kind-config.yaml
fi
kubectl config use-context kind-nebula

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null
helm repo update >/dev/null

echo "▶ ArgoCD"
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --version "$ARGOCD_VERSION" --wait
echo "▶ Argo Rollouts"
helm upgrade --install argo-rollouts argo/argo-rollouts -n argo-rollouts --create-namespace --version "$ROLLOUTS_VERSION" --wait
echo "▶ Kyverno"
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --version "$KYVERNO_VERSION" --wait

if [ -n "${GITOPS_TOKEN:-}" ]; then
  echo "▶ nebula-gitops 접근 토큰 등록"
  kubectl -n argocd create secret generic nebula-gitops-repo \
    --from-literal=type=git \
    --from-literal=url=https://github.com/shashax42/nebula-gitops.git \
    --from-literal=username=x-access-token \
    --from-literal=password="$GITOPS_TOKEN" \
    --dry-run=client -o yaml \
    | kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml \
    | kubectl apply -f -
else
  echo "⚠ GITOPS_TOKEN이 없습니다. nebula-gitops가 private이면 ArgoCD가 레포를 읽지 못합니다."
fi

echo "▶ nebula-root 적용"
kubectl apply -f ../platform/root.yaml

echo
echo "ArgoCD 비밀번호: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo "UI 열기: kubectl -n argocd port-forward svc/argocd-server 8080:443  → https://localhost:8080 (admin)"
