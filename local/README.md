# 로컬 검증 (kind)

EKS와 같은 플랫폼 구성(ArgoCD, Argo Rollouts, Kyverno)을 내 PC의 kind 클러스터에 올려서
GitOps 배포, 이미지 서명 검증, 자동 롤백을 비용 없이 확인한다.

## 1. 도구 설치 (Windows, 최초 1회)

PowerShell에서 실행한다. 설치 후 Docker Desktop을 한 번 실행해 두고, 터미널을 새로 연다.

```powershell
winget install -e --id Docker.DockerDesktop
winget install -e --id Kubernetes.kind
winget install -e --id Kubernetes.kubectl
winget install -e --id Helm.Helm
```

아래 스크립트는 Git Bash에서 실행한다.

## 2. 클러스터 + 플랫폼 올리기 (약 5~10분)

```bash
GITOPS_TOKEN=<nebula-gitops 읽기 토큰> ./local/bootstrap.sh
```

- 끝나면 ArgoCD 비밀번호와 UI 여는 방법이 출력된다.
- 서비스(service-* 등)는 DB·Kafka·Redis가 없어서 로컬에서는 정상 기동하지 않는다.
  로컬에서 확인하는 것은 "git 변경이 클러스터에 반영되는가"와 "정책·롤백이 동작하는가"다.

## 3. 데모

### 이미지 서명 검증 (Kyverno)

```bash
./local/demo-signature.sh
```

| 케이스 | 기대 |
|---|---|
| `nginx:1.27` (외부 레지스트리) | 거부 |
| gitops에 기록된 서명 이미지 | 허용 |
| `UNSIGNED_IMAGE=ghcr.io/shashax42/<직접 push한 이미지>` 지정 시 | 거부 |

서명 이미지 케이스는 CI 파이프라인이 한 번 성공해서 gitops의 이미지가 `sha-xxxx@sha256:...`로
갱신된 뒤에 의미가 있다.

### 자동 롤백 (Argo Rollouts)

```bash
./local/demo-rollback.sh 10
```

장애 버전(약 1/3 확률로 500 응답)을 10번 배포하고, 카나리 분석이 매번 롤백하는지와
기존 stable 버전이 유지되는지를 `local/rollback-results.csv`에 기록한다.

## 4. 끝나면 정리

```bash
kind delete cluster --name nebula
```

## 결과를 포트폴리오에 쓸 때

측정한 그대로 쓴다. 예: "장애 버전 10회 배포 → 10회 자동 롤백, 평균 N초".
측정하지 않은 값은 "목표(SLO)"로 표기한다.
