---
name: beom
description: "개발 오케스트레이터. 작업을 분석하여 팀 조합을 추천하고, 선택된 팀으로 설계→구현→리뷰→커밋까지 수행한다. plan 파일로 전 과정을 형상관리한다."
argument-hint: "<기능/버그 설명> [--hotfix] [--base <branch>] [--status] [--resume]"
---

오케스트레이터. 작업 분석 → 팀 추천 → 에이전트 팀 작업 → 커밋까지 전체 개발 사이클을 관리한다.

항상 한국어로 응답한다.

## 절대 원칙

**오케스트레이터는 직접 코드를 작성하지 않는다.** 모든 산출물(PRD, 설계서, 코드, 리뷰)은 반드시 에이전트(SendMessage 또는 Agent tool)를 통해 생성한다.

## 인자

- `ARGS[0]` (필수): 기능 또는 버그 설명 (e.g., "[JIRA-123] 로그인 기능 추가")
- `--hotfix`: coder만 사용하는 최소 경로 (설계/리뷰 건너뜀)
- `--base <branch>`: 베이스 브랜치 지정 (미지정 시 자동 감지)
- `--status`: 현재 상태만 출력 후 종료
- `--resume`: state.md에서 상태 복원 후 중단 Phase부터 재개

ARGS[0] 없이 호출 시: "개발할 기능이나 수정할 버그를 설명해주세요. 예: `/beom [JIRA-123] 로그인 기능 추가`"

## 참조

- 상세 규격 (Context Slicing, Diff 수집, plan/state 포맷): `skills/beom/reference.md`
- 커밋/PR 프로세스: `skills/commit/SKILL.md`, `skills/pull-request/SKILL.md`
- 에이전트 정의: `agents/` 디렉토리

---

# 팀 조합

| 조합 | 에이전트 | 적합한 작업 |
|------|---------|------------|
| **Light (3명)** | architect + coder + qa-manager | 버그 수정, 소규모 기능, 리팩토링, 요구사항이 명확한 작업 |
| **Full (5명)** | + product-owner + security-auditor | 신규 기능, 정책/보안 민감, 요구사항이 모호한 작업 |

| Agent | 역할 | 모델 |
|-------|------|------|
| product-owner | PRD 작성 + 인수 검증 (Full만) | sonnet |
| architect | 기술 설계 | sonnet |
| coder | 구현 + 수정 | inherit |
| qa-manager | 코드 리뷰 + 스펙 검증 | sonnet |
| security-auditor | 정책/보안 감사 (Full만) | sonnet |

### Phase 흐름

```
Light (3명): setup → 설계 → 구현 → 리뷰 → 커밋
Full  (5명): setup → PRD → 설계 → 구현 → 리뷰 → 커밋
Hotfix:      setup → 구현 → 커밋
```

---

# 유틸리티 스킬 (on-demand)

| Skill | 호출 시점 |
|-------|---------|
| design-critic | 설계 규모 중형/대형일 때 architect에게 호출 지시 |
| todo-verifier | verification.enabled일 때 각 Phase 완료 시 |
| plan-visualizer | autoVisualize일 때 각 Phase 완료 시 |
| web-test-qa | 리뷰 Phase에서 프론트엔드 변경 감지 시 |

## 에스컬레이션 (정체 감지)

구현→자기점검 루프와 리뷰→수정→재리뷰 루프에서 적용한다.

| 감지 패턴 | 기준 | 1차 대응 | 2차 대응 |
|----------|------|---------|---------|
| SPINNING | 동일 에러 2회 반복 | `Skill("oh-my-beom:hacker")` | `Skill("oh-my-beom:research")` |
| NO_DRIFT | 코드 변경 실질 없음 | `Skill("oh-my-beom:hacker")` | `Skill("oh-my-beom:research")` |
| OSCILLATION | 접근법 A→B→A | architect 설계 재검토 | 사용자에게 선택 요청 |
| DIMINISHING_RETURNS | 범위↑ 품질→ | `Skill("oh-my-beom:simplifier")` | 사용자에게 방향 전환 확인 |

---

# Phase: setup (환경 준비)

1. **진행 중 작업 감지**: `--resume` → state.md 복원. `--status` → 상태 출력 후 종료. ARGS[0] 없음 → state.md 탐색 후 AskUserQuestion.
2. **Git 저장소 확인**: `git rev-parse --is-inside-work-tree`. 실패 시 `git init` 여부를 AskUserQuestion.
3. **베이스 브랜치 결정 + 동기화**: `git checkout <base> && git pull origin <base>`. (감지 로직은 reference.md 참조)
4. **프로젝트 정보 수집** (병렬): 타입 감지 (config.json), 디렉토리 구조, CLAUDE.md, 도메인 컨텍스트.
5. **코드 맵 생성**: ARGS[0] 키워드로 Grep → `.dev/codemap.md` 저장.
6. **작업 브랜치 생성**: 이슈 키 → 브랜치명, 없으면 키워드 slug. `.gitignore`에 `.dev/` 추가.
7. **이전 산출물 감지**: `.dev/lens-report.md`, `.dev/research-report.md` 존재 확인.
8. **이전 메트릭 로드**: `.dev/agent-metrics.md` 존재 시 읽어서 effort 스코어링 보정에 활용.
9. **작업 분석 + 팀/effort 추천**:
   - **팀 판단**: 이전 산출물 존재, 키워드 분석, 코드 맵 파일 수(10개↑→Full, 5개↓→Light).
   - **effort 판단**:
     - `low`: 오타 수정, 설정 변경, 단일 파일 수정 → architect에게 설계 요약만 요청
     - `medium`: 기능 추가, 버그 수정, 소규모 리팩토링 → 현행 유지
     - `high`: 아키텍처 변경, 다수 파일 수정, 신규 모듈 → design-critic 자동 호출, architect에게 대안 비교 포함 상세 설계
   - 이전 메트릭이 있으면 평균 review_rounds, critical_count로 effort 보정.
   - `--hotfix` 시 건너뜀 (coder 1명, effort=low 고정).
   - AskUserQuestion으로 팀 + effort 추천 표시, 사용자 선택.
10. **팀 생성**: TeamCreate 호출. tmux 환경이면 `Skill("oh-my-beom:tmux-team-agent")`.
11. **상태 + plan 파일 초기화**: `.dev/state.md` + `docs/plan/{이슈키}-plan.md` 생성. (포맷은 reference.md 참조)

---

# Phase: PRD (Full 팀만)

**Light 팀은 건너뛴다.** 최대 1회 Q&A.

1. `SendMessage(to="product-owner")` — PRD 작성. 입력: ARGS[0] + 코드 맵 + LENS/RESEARCH_REPORT.
2. 질문 있으면 사용자에게 표시. 1회 재호출.
3. 확정된 PRD → `.dev/prd.md` 저장.
4. plan 기록: `### [PRD] product-owner — {timestamp}` + 핵심 요약.

---

# Phase: 설계

최대 2회 Q&A.

1. `SendMessage(to="architect")` — 기술 설계. 입력: PRD(있으면) + 코드 맵 + 컨벤션. effort=low면 설계 요약만 요청.
2. 설계 규모 판단. 중형 이상 또는 effort=high이면 `/design-critic` 호출 지시.
3. 질문 있으면 사용자에게 표시. 최대 2회.
4. 확정된 설계서 → `.dev/design.md` 저장.
5. plan 기록: `### [설계] architect — {timestamp}` + 설계 요약/변경 범위/규모.
6. **메트릭 기록**: `.dev/agent-metrics.md`에 architect Q&A 횟수, 설계 규모 기록.
7. 검증 활성화 시: `Skill("oh-my-beom:plan-visualizer")`.

---

# Phase: 구현

1. `SendMessage(to="coder")` — 코드 구현. 입력: 설계서 + 코드 맵. `--hotfix` 시 ARGS[0] + 코드 맵.
2. **자기점검** (변경 10줄 이상): `SendMessage(to="qa-manager")` — Critical만. Critical 있으면 coder 자동 수정 1회. → `.dev/self-check.md` 저장.
3. 검증 활성화 시: `Skill("oh-my-beom:todo-verifier")`. FAILED → coder 수정 + 재검증 (최대 2회).
4. plan 기록: `### [구현] coder — {timestamp}` + 구현 요약/변경 파일/자기점검 결과.
5. **메트릭 기록**: `.dev/agent-metrics.md`에 변경 파일 수, 자기점검 Critical/Warning 수 기록.

---

# Phase: 리뷰

**Hotfix는 건너뛴다.** 최대 2회 반복.

## Mechanical Gate

lint → build → test 순서 실행. 실패 시 coder 자동 수정 (1회 재시도).

## 코드 리뷰

- **Light**: `SendMessage(to="qa-manager")` — diff + 설계서 + 코드 맵.
- **Full**: qa-manager + security-auditor **병렬** 호출.
- 프론트엔드 변경 감지 시: `Skill("oh-my-beom:web-test-qa")`.

## 결과 처리

- Critical/RISK → coder 자동 수정.
- QUESTION → 사용자 확인.
- 2회 반복 후 미해결 Critical → 사용자에게 진행 여부 확인.

plan 기록: `### [리뷰] qa-manager — {timestamp}` + 결과. Full이면 `### [감사] security-auditor — {timestamp}` 추가.

**메트릭 기록**: `.dev/agent-metrics.md`에 리뷰 라운드 수, Critical/RISK 수, 수정 횟수 기록.

---

# Phase: 커밋

## 인수 검증 (Full 팀만)

`SendMessage(to="product-owner")` — PRD 수용 기준 검증. REJECT → coder 수정 1회 → 재검증.

## 사용자 확인

AskUserQuestion: "커밋을 진행할까요?" → 수정 필요 시 coder 재지시, 중단 시 상태 저장.

## 커밋 실행

`commit` 스킬을 Read하여 프로세스 실행. test 실패 시 coder 자동 수정 1회.

## 완료

1. state.md `status: completed`, plan 파일 `상태: COMPLETED` 갱신.
2. 검증 활성화 시 `Skill("oh-my-beom:plan-visualizer")`.
3. "커밋이 완료되었습니다. PR이 필요하면 `/pull-request`를 실행하세요."

---

# Hotfix 경로 (`--hotfix`)

팀 추천을 건너뛰고 coder 1명만으로 최소 경로 실행: **setup → 구현 → 커밋**. 설계/리뷰/PRD/인수검증 모두 건너뜀. plan 파일은 생성하되 최소 기록만.
