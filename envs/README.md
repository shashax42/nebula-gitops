# 환경별 배포 (dev → staging → prod)

```
<서비스>/                     dev 트랙. CI(nebula-ci-templates)가 main 에 새 이미지를 쓰면 dev 클러스터에 바로 반영
envs/staging/<서비스>/        dev 트랙 매니페스트 + 이미지 고정 (dev 에서 승격된 버전)
envs/prod/<서비스>/           dev 트랙 매니페스트 + 이미지 고정 (staging 에서 승격된 버전) + prod 전용 패치
platform/envs/<env>/          각 클러스터의 App of Apps. Nebula-Platform 이 nebula-root 를 여기에 연결한다
```

- 클러스터가 자기 환경을 아는 방법: Nebula-Platform 이 `nebula-root` 의 경로를 `platform/envs/<environment>` 로 만든다.
  staging/prod 는 서비스 ApplicationSet 의 생성기를 `envs/<env>/*` 로 바꾼다. Application 이름은 환경과 상관없이 같다.
- **승격되는 것은 이미지뿐이다.** Deployment·HPA 같은 매니페스트 구조 변경은 dev 트랙을 고치는 PR 이 병합되는 순간
  모든 환경에 함께 들어간다. 환경마다 달라야 하는 값은 해당 오버레이에 패치로 둔다 (예: `envs/prod/data-kafka`).

## 승격

```bash
# GitHub Actions: promote 워크플로 실행 (service, target 선택) → 승격 PR 생성 → 리뷰 후 병합
# 로컬:
scripts/promote.sh service-order staging   # dev 의 이미지를 staging 오버레이로
scripts/promote.sh all prod                # staging 의 모든 이미지를 prod 오버레이로
```

같은 다이제스트를 옮기므로 다시 빌드하지 않고, Kyverno 서명 검증도 dev 와 같은 이미지에 대해 통과한다.

## 새 서비스 추가

1. 최상위에 `<서비스>/` 와 `kustomization.yaml` (매니페스트를 모두 `resources` 에 나열)
2. `envs/staging/<서비스>/kustomization.yaml`, `envs/prod/<서비스>/kustomization.yaml` (다른 서비스 것을 복사해 이름만 바꾼다)

`scripts/check-envs.sh` (validate 워크플로에서 실행)가 누락된 resources, 짝 없는 오버레이, 다이제스트 없는 이미지를 잡는다.
