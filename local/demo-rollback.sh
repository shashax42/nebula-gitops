#!/usr/bin/env bash
# 자동 롤백 실험: 장애 버전을 N번 배포하고, 카나리 분석이 매번 롤백시키는지 기록한다.
# 사용: ./local/demo-rollback.sh 10
set -euo pipefail
cd "$(dirname "$0")/.."
N=${1:-10}
NS=rollback-lab
OUT=${OUT:-local/rollback-results.csv}

phase()  { kubectl -n "$NS" get rollout podinfo -o jsonpath='{.status.phase}'; }
stable() { kubectl -n "$NS" get rollout podinfo -o jsonpath='{.status.stableRS}'; }

wait_phase() { # $1 정규식, $2 타임아웃(초)
  local end=$((SECONDS + $2)) p
  while (( SECONDS < end )); do
    p=$(phase)
    if [[ $p =~ $1 ]]; then echo "$p"; return 0; fi
    sleep 3
  done
  echo timeout
}

deploy() { # $1 random-error(true|false), $2 구분값
  kubectl -n "$NS" patch rollout podinfo --type json -p "[
    {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env/0/value\",\"value\":\"$1\"},
    {\"op\":\"add\",\"path\":\"/spec/template/metadata/annotations\",\"value\":{\"lab/trial\":\"$2\"}}
  ]" >/dev/null
}

kubectl apply -f lab/rollback/podinfo.yaml >/dev/null
deploy false baseline
echo "기준 버전 배포 대기..."
[ "$(wait_phase '^Healthy$' 300)" = Healthy ] || { echo "기준 버전이 Healthy가 되지 않았습니다"; exit 1; }

echo "trial,result,seconds_to_rollback,stable_preserved" > "$OUT"
ok=0
for i in $(seq 1 "$N"); do
  before=$(stable)
  deploy true "bad-$i"
  start=$SECONDS
  sleep 5
  r=$(wait_phase '^(Degraded|Healthy)$' 300)
  t=$((SECONDS - start))
  [ "$(stable)" = "$before" ] && kept=yes || kept=no
  if [ "$r" = Degraded ] && [ "$kept" = yes ]; then res=rolled_back; ok=$((ok + 1)); else res=FAILED_$r; fi
  echo "$i,$res,$t,$kept" | tee -a "$OUT"

  deploy false "good-$i"
  [ "$(wait_phase '^Healthy$' 300)" = Healthy ] || { echo "정상 버전 복구 실패 (trial $i)"; exit 1; }
done

echo
echo "결과: 장애 버전 ${N}회 배포 → 자동 롤백 ${ok}회"
awk -F, 'NR>1 && $2=="rolled_back" {s+=$3; n++} END {if (n) printf "평균 롤백 소요: %.1f초\n", s/n}' "$OUT"
echo "기록: $OUT"
