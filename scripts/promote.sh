#!/usr/bin/env bash
# 검증된 이미지를 다음 환경으로 승격한다: dev → staging, staging → prod
#   사용: scripts/promote.sh <서비스|all> <staging|prod>
#   예:   scripts/promote.sh service-order staging
#
# - dev 이미지는 최상위 서비스 디렉터리(CI 가 쓰는 곳)에서, staging 이미지는 envs/staging 오버레이에서 읽는다.
# - 대상 오버레이(envs/<target>/<서비스>/kustomization.yaml)의 images 항목만 바꾼다. 다시 빌드하지 않고 같은 다이제스트를 옮긴다.
# - 커밋·PR 은 하지 않는다. 바뀐 내용은 표로 PROMOTE_SUMMARY(기본 /tmp/promote-summary.md)에 남긴다.
# 필요: mikefarah yq v4
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { echo "사용: $0 <서비스|all> <staging|prod>" >&2; exit 2; }
[ $# -eq 2 ] || usage
target=$2
case "$target" in
  staging) source=dev ;;
  prod)    source=staging ;;
  *) usage ;;
esac
yq --version 2>/dev/null | grep -q mikefarah || { echo "mikefarah yq v4 가 필요합니다" >&2; exit 1; }

registry=ghcr.io/shashax42
summary=${PROMOTE_SUMMARY:-/tmp/promote-summary.md}

# 이미지가 있는 서비스 = 최상위 디렉터리 중 자기 이름의 GHCR 이미지를 쓰는 곳
image_services() {
  for d in */; do
    d=${d%/}
    grep -rqs "image: ${registry}/${d}[:@]" "$d" && echo "$d"
  done
}

# 환경별 현재 이미지 (이름:태그@다이제스트)
current_image() {
  local env=$1 svc=$2
  if [ "$env" = dev ]; then
    grep -rhoE "image: ${registry}/${svc}:[^@[:space:]]+@sha256:[0-9a-f]{64}" "$svc" | head -1 | sed 's/^image: //'
  else
    local k="envs/${env}/${svc}/kustomization.yaml"
    [ -f "$k" ] || return 0
    N="${registry}/${svc}" yq '.images[] | select(.name == strenv(N)) | .name + ":" + .newTag + "@" + .digest' "$k"
  fi
}

if [ "$1" = all ]; then
  services=$(image_services)
else
  services=$1
  # 파이프 대신 here-string: grep -q 가 일찍 끝나면 pipefail 이 SIGPIPE 를 실패로 본다
  grep -qx -- "$services" <<< "$(image_services)" || { echo "이미지가 있는 서비스가 아닙니다: $services" >&2; exit 1; }
fi

{
  echo "| 서비스 | ${target} 현재 | ${source} → ${target} |"
  echo "|---|---|---|"
} > "$summary"

changed=0
for svc in $services; do
  from=$(current_image "$source" "$svc")
  to=$(current_image "$target" "$svc")
  k="envs/${target}/${svc}/kustomization.yaml"
  if [ -z "$from" ]; then echo "⚠ ${svc}: ${source} 이미지를 찾지 못해 건너뜀" >&2; continue; fi
  if [ ! -f "$k" ]; then echo "⚠ ${svc}: ${k} 가 없어 건너뜀" >&2; continue; fi
  if [ "$from" = "$to" ]; then echo "= ${svc}: 이미 같은 이미지"; continue; fi

  tag=${from#*:}; tag=${tag%@*}
  digest=${from#*@}
  N="${registry}/${svc}" T="$tag" D="$digest" yq -i '
    (.images[] | select(.name == strenv(N))) |= (.newTag = strenv(T) | .digest = strenv(D))
  ' "$k"
  echo "↑ ${svc}: ${to#*:} → ${tag}"
  echo "| ${svc} | \`${to#*:}\` | \`${from#*:}\` |" >> "$summary"
  changed=$((changed + 1))
done

echo "승격 대상 ${changed}개 (${source} → ${target}). 요약: ${summary}"
