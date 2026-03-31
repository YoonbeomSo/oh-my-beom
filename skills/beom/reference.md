# beom 오케스트레이터 참조 명세

SKILL.md에서 참조하는 상세 규격. 실행 중 필요할 때 Read하여 사용한다.

## 작업 경로

- `GIT_PREFIX`: git 명령 prefix.
- `PROJECT_ROOT`: 프로젝트 소스 코드 루트 (기본 `./`).
- `DIFF_FILE`: `${PROJECT_ROOT}/.dev/diff.txt`.

## 베이스 브랜치 감지

`--base` 지정 시 사용. 미지정이면:
1. `git branch --list main master develop`로 확인.
2. `main` 존재 → 자동 선택.
3. 없으면 → AskUserQuestion으로 선택/입력 요청.

## 코드 맵

관련 파일의 경로와 역할을 기록하는 누적 문서. `${PROJECT_ROOT}/.dev/codemap.md`에 저장.
- 생성: setup Phase에서 ARGS[0] 키워드 기반 탐색.
- 누적: 에이전트 출력의 "탐색 추가 항목"을 append. 최대 25개.
- 전달: 모든 에이전트 호출 시 프롬프트에 포함.

## Context Slicing

에이전트별 필요한 정보만 전달:
- **product-owner (PRD)**: ARGS[0] + 코드 맵 + 프로젝트 정보 + LENS_REPORT + RESEARCH_REPORT
- **product-owner (인수)**: PRD 수용 기준 + diff + 코드 맵
- **architect**: PRD(있으면) + 코드 맵 + 프로젝트 컨벤션 + RESEARCH_REPORT
- **coder (구현)**: 설계서 + 코드 맵 + 프로젝트 루트
- **coder (수정)**: 수정 항목 + 코드 맵 + 프로젝트 루트
- **qa-manager**: diff + PRD 수용 기준(있으면) + 설계서 변경 범위 + 코드 맵
- **security-auditor**: PRD + 설계서 + diff + 코드 맵

## Diff 수집

diff 출력이 메인 컨텍스트에 진입하지 않도록 파일 리다이렉트를 사용한다:
1. `${GIT_PREFIX} diff --cached > ${DIFF_FILE}`
2. 500줄 이상이면 `--stat` 요약으로 대체.
3. 에이전트에게는 파일 경로만 전달.

## 병렬 실행

읽기 전용 에이전트(product-owner, architect, qa-manager, security-auditor)는 병렬 가능.
쓰기 에이전트(coder)는 다른 쓰기 에이전트와 병렬 불가.

## 문서 보관

| 파일 | 시점 |
|------|------|
| `.dev/state.md` | setup에서 생성, 매 Phase 갱신 |
| `.dev/prd.md` | PRD Phase 완료 시 (Full만) |
| `.dev/design.md` | 설계 Phase 완료 시 |
| `.dev/codemap.md` | 갱신 시마다 |
| `.dev/self-check.md` | 구현 Phase 자기점검 완료 시 |
| `.dev/trust-ledger.md` | 리뷰 Phase 감사 완료 시 (Full만) |
| `.dev/diff.txt` | diff 수집 시마다 |
| `docs/plan/{key}-plan.md` | 전 과정 형상관리 |

## plan 파일 형상관리

**파일 구조:**
```markdown
# {이슈키}: {제목}

## 메타 정보
- 상태: IN_PROGRESS | COMPLETED
- 팀 구성: {Light 3명 / Full 5명} ({에이전트 목록})
- 브랜치: {branch} (base: {base})
- 프로젝트 타입: {type}
- 생성일: {timestamp}

## Phase 기록

### [Phase명] 에이전트 — {timestamp}
{에이전트 출력 요약}
```

**형상관리 규칙:**
- 오케스트레이터만 plan 파일에 Write한다 (에이전트 직접 Write 금지).
- 각 기록은 Phase명 + 에이전트명 + timestamp로 식별.
- 기존 기록을 수정하지 않고 항상 append.
- 상태 변경(IN_PROGRESS → COMPLETED)은 Edit으로 메타 정보만 갱신.

## 진행 상태 추적 (state.md)

`.dev/state.md`에 파이프라인 상태를 기록하여 세션 재개를 지원한다.

```yaml
phase: 구현
status: in_progress
team: light
team-members: architect, coder, qa-manager
effort: medium
branch: JIRA-123
base: main
project-type: kotlin-gradle
project-root: .
plan-file: docs/plan/JIRA-123-plan.md
args: "[JIRA-123] 로그인 기능 추가"
flags: ""
started: 2026-03-31T14:00:00
```

갱신 규칙:
- Phase 진입 시: `phase` 갱신.
- Phase 완료 시: 다음 Phase로 갱신.
- 완료 시: `status: completed`.
- `--resume` 시 마지막 Phase부터 재개.

## Effort 스코어링

작업 복잡도에 따라 리소스 투입을 차등 적용한다.

| Effort | 기준 | 설계 | 리뷰 |
|--------|------|------|------|
| **low** | 오타/설정 변경, 단일 파일 수정 | 설계 요약만 | 자기점검만 (리뷰 생략 가능) |
| **medium** | 기능 추가, 버그 수정, 소규모 리팩토링 | 현행 유지 | 현행 유지 |
| **high** | 아키텍처 변경, 다수 파일, 신규 모듈 | 대안 비교 포함, design-critic 자동 | 상세 리뷰 |

**판단 입력:**
- ARGS[0] 키워드 (아키텍처, 신규, 대규모 → high / 오타, 수정, 설정 → low)
- 코드 맵 파일 수 (1~2개 → low / 3~9개 → medium / 10개↑ → high)
- 이전 메트릭 보정 (평균 review_rounds > 2 → effort 한 단계 상향)

## Agent Memory (메트릭 기록)

`.dev/agent-metrics.md`에 Phase별 메트릭을 기록하여 다음 작업의 effort 스코어링에 활용한다.

```markdown
# Agent Metrics

## 설계
- Q&A 횟수: 1
- 설계 규모: 중형
- design-critic 호출: N

## 구현
- 변경 파일 수: 5
- 자기점검 Critical: 0
- 자기점검 Warning: 2

## 리뷰
- 리뷰 라운드: 1
- Critical: 0
- RISK: 0
- 수정 횟수: 0
```

**활용:**
- 다음 `/beom` 실행 시 이전 `.dev/agent-metrics.md`를 참고.
- 평균 리뷰 라운드, Critical 빈도 등으로 effort 스코어링 보정.
- 세션 종료 시 `/report` 스킬이 메트릭을 보고서에 포함.
