# platform/aws — EKS(dev) 전용 플랫폼 앱

kind(local/, platform-e2e)에는 없는, AWS 계정에 묶인 구성만 둔다. Nebula-Platform 의 `nebula-aws` 앱
(`enable_aws_platform_apps = true`)이 이 디렉터리를 동기화한다.

| 파일 | 내용 |
|---|---|
| `monitoring.yaml` | kube-state-metrics + OTel Collector(agent/gateway/cluster). 차트·기본값은 Nebula-Monitoring, 계정 값은 아래 파일 |
| `values-monitoring.yaml` | 계정·워크스페이스 고유 값 (클러스터 이름, AMP 주소, IRSA 역할) |
| `analysis-slo-canary.yaml` | service-order 카나리 분석: AMP 의 canary/stable 에러율·P99 비교 |

## 순서

1. Nebula-Platform `terraform apply` (EKS, ArgoCD, Argo Rollouts IRSA)
2. Nebula-Monitoring `terraform apply -var enable_target_monitoring=true` (AMP, AMG, 알람, collector IRSA)
3. Nebula-Monitoring `scripts/render-gitops-values.sh dev <nebula-gitops 경로>` → 이 디렉터리의 두 파일에 output 값 기록 → PR
4. Nebula-Platform `enable_aws_platform_apps = true` 로 apply → ArgoCD 가 모니터링 스택 동기화

값이 비어 있으면 otel-collector 앱은 Helm `required` 오류로 동기화되지 않는다(의도된 동작).
분석 템플릿이 없거나 AMP 에 접근할 수 없으면 service-order 카나리는 승격되지 않고 중단된다(안전한 기본값).
