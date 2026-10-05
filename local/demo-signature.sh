#!/usr/bin/env bash
# Kyverno 이미지 정책 검증. --dry-run=server로 실제 파드는 만들지 않고 승인 여부만 확인한다.
set -uo pipefail
cd "$(dirname "$0")/.."
NS=backend

check() { # $1 설명, $2 이미지, $3 기대(allow|deny)
  local out
  if out=$(kubectl -n "$NS" run "demo-$RANDOM" --image="$2" --restart=Never --dry-run=server 2>&1); then
    got=allow
  else
    got=deny
  fi
  [ "$got" = "$3" ] && mark="✅" || mark="❌"
  echo "$mark $1"
  echo "   image: $2"
  echo "   기대: $3 / 결과: $got"
  [ "$got" = deny ] && echo "   사유: $(echo "$out" | tail -1)"
  echo
}

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

signed=$(grep -h -m1 -o 'ghcr.io/shashax42/service-product[^[:space:]]*' service-product/deployment.yaml)

check "외부 레지스트리 이미지 (docker.io)"         "nginx:1.27"   deny
check "파이프라인이 서명한 이미지 (gitops 기준)"   "$signed"      allow
if [ -n "${UNSIGNED_IMAGE:-}" ]; then
  check "같은 레지스트리지만 서명 없는 이미지"     "$UNSIGNED_IMAGE" deny
fi
