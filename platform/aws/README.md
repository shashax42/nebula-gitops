# platform/aws — AWS(EKS) 전용 플랫폼 앱

kind(local/, platform-e2e)에는 없는, AWS 계정에 묶인 구성만 둔다.
환경마다 계정 값(클러스터 이름, AMP 주소, IRSA 역할)이 다르므로 kustomize 오버레이로 나눈다.
Nebula-Platform 의 `nebula-aws` 앱(`enable_aws_platform_apps = true`)이 `envs/<env>` 를 동기화한다.

```
kustomization.yaml            이전 진입점 호환 (리팩토링 전 클러스터의 nebula-aws 앱용) → envs/dev
base/                         환경 공통
  monitoring.yaml             kube-state-metrics + OTel Collector(agent/gateway/cluster). 차트·기본값은 Nebula-Monitoring
  analysis-slo-canary.yaml    service-order 카나리 분석: AMP 의 canary/stable 에러율·P99 비교
envs/<dev|staging|prod>/
  kustomization.yaml          base + otel-collector 값 파일(values-<env>.yaml + 아래 파일) + 분석 인자 패치
  values-monitoring.yaml      이 환경의 계정 값
  analysis-args.yaml          이 환경의 AMP 주소
```

## 순서 (환경마다)

1. Nebula-Platform `environments/<env>` `terraform apply` (EKS, ArgoCD, Argo Rollouts IRSA, 서비스 ConfigMap/Secret)
2. Nebula-Monitoring `terraform apply -var environment=<env> -var enable_target_monitoring=true` (workspace = env)
3. Nebula-Monitoring `scripts/render-gitops-values.sh <env> <nebula-gitops 경로>` → `envs/<env>` 의 두 파일에 output 값 기록 → PR
4. Nebula-Platform `enable_aws_platform_apps = true` 로 apply → ArgoCD 가 `envs/<env>` 동기화

값이 비어 있으면 otel-collector 앱은 Helm `required` 오류로 동기화되지 않는다(의도된 동작).
분석 템플릿이 없거나 AMP 에 접근할 수 없으면 service-order 카나리는 승격되지 않고 중단된다(안전한 기본값).

```bash
kubectl kustomize platform/aws/envs/prod   # 렌더링 결과 확인 (CI validate 가 같은 결과를 검증)
```
