#!/usr/bin/env bash
# Kyverno 이미지 정책 검증. --dry-run=server로 실제 파드는 만들지 않고 승인 여부만 확인한다.
# 기대와 다른 결과가 하나라도 있으면 exit 1.
set -uo pipefail
cd "$(dirname "$0")/.."
NS=backend
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
failed=0

check() { # $1 설명, $2 이미지, $3 기대(allow|deny)
  local out got mark
  if out=$(kubectl -n "$NS" run "demo-$RANDOM" --image="$2" --restart=Never --dry-run=server 2>&1); then
    got=allow
  else
    got=deny
  fi
  if [ "$got" = "$3" ]; then mark="✅"; else mark="❌"; failed=1; fi
  echo "$mark $1"
  echo "   image: $2"
  echo "   기대: $3 / 결과: $got"
  [ "$got" = deny ] && echo "   사유: $(echo "$out" | tail -1)"
  echo
  echo "| $mark | $1 | \`$2\` | $3 | $got |" >> "$SUMMARY"
}

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

# gitops에 기록된 서명 이미지 중 하나 (파이프라인이 tag@digest로 갱신한 것)
signed=$(grep -rhoE 'ghcr\.io/shashax42/[a-z-]+:sha-[0-9a-f]+@sha256:[0-9a-f]{64}' --include='*.yaml' . | head -1)

{
  echo "### 이미지 서명 검증 (Kyverno)"
  echo
  echo "| | 케이스 | 이미지 | 기대 | 결과 |"
  echo "|---|---|---|---|---|"
} >> "$SUMMARY"

check "외부 레지스트리 이미지 (docker.io)"       "nginx:1.27" deny
if [ -n "$signed" ]; then
  check "파이프라인이 서명한 이미지 (gitops 기준)" "$signed" allow
else
  echo "⚠ gitops에 서명된 이미지가 아직 없습니다 (CI 성공 후 다시 실행)"
fi
if [ -n "${UNSIGNED_IMAGE:-}" ]; then
  check "같은 레지스트리지만 서명 없는 이미지"   "$UNSIGNED_IMAGE" deny
fi

exit $failed
