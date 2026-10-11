#!/usr/bin/env bash
# 환경 오버레이 구조 검사 (validate 워크플로가 실행, 로컬에서도 그대로 실행 가능)
#   1) 최상위 서비스 디렉터리의 kustomization.yaml 이 그 디렉터리의 매니페스트를 빠짐없이 나열하는가
#      (빠지면 dev 를 포함한 모든 환경에서 조용히 배포되지 않는다)
#   2) 배포 대상 디렉터리마다 envs/staging, envs/prod 오버레이가 있고, 짝 없는 오버레이는 없는가
#   3) staging/prod 오버레이의 이미지가 태그와 다이제스트로 고정돼 있는가
# 필요: mikefarah yq v4
set -euo pipefail
cd "$(dirname "$0")/.."

# platform/apps/services.yaml 의 exclude 목록과 같아야 한다
excluded=" .github platform scripts local lab envs "
envs="staging prod"
err=0
fail() { echo "✗ $*"; err=1; }

deployable=()
for d in */; do
  d=${d%/}
  [[ "$excluded" == *" $d "* ]] && continue
  deployable+=("$d")
done

for d in "${deployable[@]}"; do
  k="$d/kustomization.yaml"
  if [ ! -f "$k" ]; then fail "$k 가 없습니다"; continue; fi
  listed=$(yq '.resources[]' "$k")
  for f in "$d"/*.yaml "$d"/*.yml; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    [ "$b" = kustomization.yaml ] && continue
    grep -qx -- "$b" <<< "$listed" || fail "$k 의 resources 에 $b 가 없습니다"
  done
  for e in $envs; do
    o="envs/$e/$d/kustomization.yaml"
    [ -f "$o" ] || fail "$o 가 없습니다 ($e 에 $d 가 배포되지 않음)"
  done
done

for e in $envs; do
  for o in envs/"$e"/*/; do
    [ -d "$o" ] || continue
    d=$(basename "$o")
    [ -d "$d" ] || fail "envs/$e/$d 에 대응하는 최상위 디렉터리가 없습니다"
    k="${o%/}/kustomization.yaml"
    [ -f "$k" ] || continue
    unpinned=$(yq '.images // [] | .[] | select((.newTag // "") == "" or ((.digest // "") | test("^sha256:[0-9a-f]{64}$") | not)) | .name' "$k")
    [ -z "$unpinned" ] || fail "$k: 태그+다이제스트로 고정되지 않은 이미지: $unpinned"
  done
done

[ "$err" -eq 0 ] && echo "✓ 환경 오버레이 구조 정상 (${#deployable[@]}개 디렉터리 × dev/staging/prod)"
exit "$err"
