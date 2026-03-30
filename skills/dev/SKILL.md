---
name: dev
version: 1.0.0
description: "PRD → 설계 → 구현 → 리뷰 → 커밋/PR까지 전체 개발 사이클을 에이전트 팀이 Q&A 루프로 수행"
argument-hint: "<기능/버그 설명> [--phase requirements|design|implement|review|complete] [--hotfix] [--base <branch>] [--status] [--resume]"
allowed-tools: ["Bash(git *)", "Bash(test *)", "Bash(mkdir *)", "Bash(cp *)", "Bash(mv *)", "Bash(ls *)", "Bash(find *)", "Bash(pwd *)", "Bash(basename *)", "Bash(dirname *)", "Bash(which *)", "Bash(./gradlew *)", "Bash(npm *)", "Bash(npx *)", "Bash(bun *)", "Bash(bunx *)", "Bash(yarn *)", "Bash(pnpm *)", "Bash(pip *)", "Bash(poetry *)", "Bash(pytest *)", "Bash(ruff *)", "Bash(black *)", "Bash(gh *)", "Bash(GH_HOST= *)", "Bash(brew install *)", "Read", "Edit", "Write", "Glob", "Grep", "Task", "AskUserQuestion"]
---

오케스트레이터. 직무 기반 Agent 팀과 Q&A 피드백 루프로 전체 개발 사이클을 관리한다.

항상 한국어로 응답한다.

## 스킬 참조 경로

다른 스킬의 프로세스를 실행할 때 아래 경로에서 Read한다:
- `skills/commit/SKILL.md`
- `skills/pull-request/SKILL.md`
- `skills/worktree/SKILL.md`

Agent를 호출할 때는 `agents/` 디렉토리의 에이전트 정의를 참조한다.

## 인자

- `ARGS[0]` (필수): 기능 또는 버그 설명 (e.g., "[JIRA-123] 로그인 기능 추가")
- `--phase requirements|design|implement|review|complete`: 특정 Phase만 실행
- `--hotfix`: 긴급 버그 수정용 경량 경로. 설계/리뷰를 건너뛰되 경량 PRD와 인수 검증은 실행 (setup → requirements → implement → complete)
- `--base <branch>`: 베이스 브랜치 지정 (미지정 시 자동 감지)
- `--status`: 현재 파이프라인 진행 상태를 조회한다. 다른 플래그/인자와 함께 사용 불가.
- `--resume`: 이전 파이프라인을 명시적으로 재개한다. state.md가 없거나 completed이면 에러.

ARGS[0]이 없고 `--status`도 `--resume`도 없으면 다음을 응답:
"구현할 기능이나 수정할 버그를 설명해주세요. 예: `/dev [JIRA-123] 로그인 기능 추가`"

### --status 동작
`--status`가 지정되면 파이프라인을 실행하지 않고 현재 상태만 출력한다:

1. phase-setup의 0.0과 동일한 방식으로 `.dev/state.md`를 탐색한다.
2. state.md가 없으면: "진행 중인 파이프라인이 없습니다." 출력 후 종료.
3. state.md가 있으면 다음을 출력:
   ```
   ## 파이프라인 상태
   - 작업: {args}
   - 브랜치: {branch} (base: {base})
   - 프로젝트: {project-type} ({project-root})
   - 현재 Phase: {phase} ({status})
   - 플래그: {flags}
   - 시작: {started}

   ### Phase 진행
   - setup: {status}
   - requirements: {status}
   - ...
   ```
4. 출력 후 종료. 파이프라인을 시작하지 않는다.

## Agent 팀

| Agent | 분류 | 역할 | 관점 | 모델 |
|-------|------|------|------|------|
| product-owner | PRODUCT | PRD 작성 + 인수 검증 | "뭘 만들지" / "비즈니스 의도대로 됐나" | sonnet |
| architect | PLANNING | 설계 | "어떻게 만들지" / "구조적 일관성" | sonnet |
| design-critic | REVIEW | 설계 비판 검토 | "이 가정이 맞나" / "더 단순하게 안 되나" | opus |
| coder | EXECUTION | 구현 + 수정 | "만든다" | inherit |
| qa-manager | REVIEW | 코드 리뷰 + 스펙 충족 검증 | "스펙대로 됐나" | sonnet |
| security-auditor | REVIEW | 정책/보안/허점 감사 | "뭘 놓쳤나" | sonnet |
| researcher | ANALYSIS | 코드베이스 조사 + 기술 비교 | "이해한다" (독립 호출 전용) | sonnet |
| hacker | RECOVERY | 제약 우회 + 정체 탈출 | "다른 길이 있다" (정체 감지 시 호출) | sonnet |
| simplifier | RECOVERY | 복잡도 제거 + 범위 축소 | "더 작게 만들자" (정체 감지 시 호출) | sonnet |
| playwright-tester | TESTING | E2E 테스트 계획 + 코드 생성 | "테스트를 만든다" | sonnet |
| playwright-test-healer | TESTING | 실패 테스트 수정 | "테스트를 고친다" | sonnet |
| todo-verifier | VERIFICATION | TODO 완료 기준 검증 | "기준대로 됐나" | sonnet |
| plan-visualizer | VISUALIZATION | 계획 MD → HTML | "보여준다" | sonnet |

### 모델 라우팅 원칙

- 비판적 분석 (가정 도전, 설계 비판): opus — 추론 깊이 우선
- 산출물 생성 (PRD, 설계, 코드, 리뷰): sonnet — 비용 효율 우선
- 정체 탈출 (제약 우회, 복잡도 제거): sonnet — 빠른 판단 우선
- E2E 테스트 (계획+생성, 수정): sonnet — 브라우저 상호작용 중심, 빠른 실행 우선
- 단순 검증 (Mechanical Gate 결과 판단): 오케스트레이터가 직접 수행 — 에이전트 불필요
- 검증/시각화 (TODO 검증, HTML 생성): sonnet — 경량 분석 작업

## Phase 개요

| Phase | 주 Agent | Q&A Loop |
|-------|----------|----------|
| setup | (inline) | No |
| requirements | product-owner | Yes (max 1) |
| design | architect + design-critic (선택적) | Yes (max 2) |
| implement | coder + qa-manager | Self-check (1회) |
| review | qa-manager + security-auditor (병렬) | Yes (max 2) |
| complete | product-owner (인수) + (스킬 참조) | 인수 재시도 (max 1) |

### Hotfix 경로 (`--hotfix`)

긴급 버그 수정용 경량 경로. 설계/리뷰를 건너뛰지만, **경량 PRD와 인수 검증은 실행**한다:
```
--hotfix: setup → requirements (경량) → implement → complete (인수검증 포함)
정상:     setup → requirements → design → implement → review → complete
```
- requirements: product-owner가 소형 PRD를 작성한다 (배경 + 요구사항 + 수용 기준만).
- design: 건너뛴다. coder가 PRD와 코드 맵을 기반으로 직접 구현한다.
- review: 건너뛴다.
- complete: 인수 검증(5.1)을 **실행**한다. PRD 수용 기준 대비 결과를 검증한다.

## 코드 맵

오케스트레이터가 관리하는 누적 문서. 관련 파일의 경로와 역할을 기록한다.

**구조:**
```
## 코드 맵: <기능 설명>

### 핵심 파일
- <파일경로:라인> → 역할 설명
- ...

### 참조 파일
- <파일경로:라인> → 역할 설명
- ...

### 설정
- <파일경로> → 역할 설명
- ...
```

**생성**: phase-setup의 Step 0.4에서 초기 맵을 생성한다.
**누적**: 각 agent 출력에 "탐색 추가 항목" 섹션이 있으면 해당 항목을 맵에 append한다. 누적 맵은 **최대 25개**로 제한한다. 초과 시 참조 파일부터 제거한다.
**저장**: 코드 맵이 갱신될 때마다 `${PROJECT_ROOT}/.dev/codemap.md`에 Write한다.
**전달**: 모든 agent 호출 시 현재 코드 맵을 프롬프트에 포함한다.

## Trust Ledger (신뢰 원장)

security-auditor의 감사 결과를 누적하는 문서. 오케스트레이터가 관리한다.

**구조:**
```
## Trust Ledger

### 통합 감사 (review)
- [분류/심각도] 항목 설명
  - 근거: ...
  - 권고: ...
```

**생성**: phase-review에서 ZT 통합 감사 완료 시 생성.
**저장**: `${PROJECT_ROOT}/.dev/trust-ledger.md`에 저장한다.
**전달**: PR 본문에 감사 결과 요약으로 포함한다.

---

## 공유 규칙

### 작업 경로 기준
phase-setup에서 결정된 변수를 이후 모든 Phase에서 사용한다:
- `GIT_PREFIX`: git 명령의 prefix. 워크트리 생성 후에는 적절히 갱신.
- `PROJECT_ROOT`: 프로젝트 소스 코드의 루트 경로.
- `DIFF_FILE`: 변경사항 diff를 저장하는 파일 경로. `${PROJECT_ROOT}/.dev/diff.txt`. Diff 수집 규칙에 따라 phase-implement(자기점검), phase-review, phase-complete에서 갱신된다.
- `DOMAIN_CONTEXT`: phase-setup 0.3에서 로드된 도메인 용어(glossary)와 아키텍처 정보. 매칭되지 않으면 빈 상태.
- `GIT_PREFIX`를 갱신할 때 `test -d <path>`로 대상 경로 존재를 검증한다. 실패 시 갱신하지 않고 사용자에게 에러를 보고한다.
- Agent에게 `PROJECT_ROOT` 경로를 항상 전달하여 파일 도구(Read/Write/Edit/Glob/Grep)의 기준점으로 사용하게 한다.
- 빌드/린트/테스트 명령(`./gradlew`, `npm`, `pytest` 등)을 `PROJECT_ROOT`에서 실행할 때, Bash 작업 디렉토리가 변경되지 않도록 **서브셸**을 사용한다: `(cd ${PROJECT_ROOT} && ./gradlew build)`.

### 베이스 브랜치 감지
`--base`가 지정되었으면 해당 브랜치를 사용한다. 미지정이면 자동 감지:
1. `${GIT_PREFIX} branch --list main master develop`로 존재하는 브랜치를 확인한다.
2. `main`이 존재하면 → 베이스로 자동 선택.
3. `main`이 없으면 → 존재하는 `develop`/`master`를 선택지로 사용자에게 제시한다 (AskUserQuestion). 하나도 없으면 직접 입력을 요청한다.

확정된 베이스 브랜치를 이후 phase-review (diff 계산), phase-complete (PR 생성)에서 사용한다.

### Q&A 히스토리 관리
Agent prompt 크기를 관리하기 위해:
- Agent에게는 **최신 설계/리뷰 출력만** 전달한다. 이전 버전은 전달하지 않는다.
- 이전 라운드의 질문+답변은 **핵심 결정 사항만 요약**하여 전달한다 (원문 그대로 X).
- 예: "Q: 세션 기반 vs JWT? → A: JWT 선택. Q: 토큰 만료 시간? → A: 30분"

### Agent 결과 전달 규칙 (컨텍스트 경량화)
Agent 출력을 사용자에게 전달할 때, **Phase 상태에 따라** 전문 표시 여부를 결정한다:
- **Q&A Phase** (requirements, design): Agent 출력의 첫 표시는 항상 **전문 표시**한다 (사용자가 산출물을 검토할 수 있도록). Phase 파일의 구체적인 표시 규칙이 이 일반 규칙보다 우선한다.
- **Q&A Phase 완료 보고**: 확정된 산출물을 파일에 저장하고, 사용자에게는 **요약만** 보고한다 ("PRD 확정. .dev/prd.md에 저장됨" 등).
- **Q&A 없는 Phase** (implement, review, complete): Agent 출력의 **요약만** 사용자에게 표시한다. 전문은 파일에 저장하거나 변수에 보관한다.

이후 Phase에서 이전 산출물이 필요하면 **파일을 Read하여 Agent prompt에 포함**하되, 오케스트레이터 자신의 출력에는 포함하지 않는다. 각 Phase 파일에서 구체적인 요약 포맷을 정의한다.

### 문서 보관
- phase-requirements 완료 시 확정된 PRD를 `${PROJECT_ROOT}/.dev/prd.md`에 저장한다.
- phase-design 완료 시 확정된 설계 문서를 `${PROJECT_ROOT}/.dev/design.md`에 저장한다.
- Trust Ledger를 `${PROJECT_ROOT}/.dev/trust-ledger.md`에 저장한다.
- 코드 맵을 `${PROJECT_ROOT}/.dev/codemap.md`에 저장한다 (갱신 시마다).
- 자기점검 결과를 `${PROJECT_ROOT}/.dev/self-check.md`에 저장한다 (phase-implement 자기점검 완료 시).
- phase-design, phase-implement, phase-review 진입 시 해당 파일들을 Read하여 에이전트 프롬프트에 사용한다.
- `.gitignore` 보강은 phase-setup의 Step 0.5a에서 프로젝트 타입별로 처리한다 (`.dev/` 포함).

### 진행 상태 추적 (state.md)
파이프라인 진행 상태를 `.dev/state.md`에 기록하여 세션 재개를 지원한다.

**state.md 구조:**
```yaml
phase: implement
status: in_progress
branch: JIRA-123
base: main
project-type: kotlin-gradle
project-root: .
plan-file: docs/plan/JIRA-123-plan.md
args: "[JIRA-123] 로그인 기능 추가"
flags: --hotfix
started: 2026-02-17T10:30:00
current-step: "자기점검"
phases:
  setup: completed
  requirements: completed
  design: completed
  implement: in_progress
steps:
  implement:
    - coder 구현: completed
    - 자기점검: in_progress
  review:
    - mechanical-gate: pending
    - qa-review-1: pending
execution-log:
  - phase: implement
    agent: coder
    result: completed
    steps-reported: 5/5
  - phase: implement
    agent: qa-manager (자기점검)
    result: "Critical 1건, Warning 2건"
  - phase: implement
    agent: coder (수정)
    result: "Critical 1건 해소"
  - phase: review
    step: mechanical-gate
    result: "lint O, build O, test O"
  - phase: review
    agent: qa-manager
    result: "CERTAIN 0건, QUESTION 1건"
  - phase: review
    agent: security-auditor
    result: "CRITICAL 0건"
```

**갱신 규칙:**
- Phase 진입 시: `phase: {name}`, `phases.{name}: in_progress`로 갱신.
- Phase 완료 시: `phases.{name}: completed`로 갱신.
- Phase 내 주요 Step 시작/완료 시: `current-step`과 `steps` 갱신.
- `--resume` 시 `current-step`에서 재개한다 (Phase 처음부터가 아닌 중단 Step부터).
- 에이전트 호출 완료 시: `execution-log`에 엔트리 추가 (agent명, result 요약).
- Gate 실행 결과도 `execution-log`에 기록한다.
- 정체 감지 시: 해당 `execution-log` 엔트리에 `stagnation: {패턴}` 필드를 추가한다.
- phase-complete 완료 시: `status: completed`로 갱신.
- 새 파이프라인 시작 시 기존 state.md를 덮어쓴다.

### Context Slicing 규칙
설계서와 PRD를 Agent에게 전달할 때, 역할에 따라 필요한 섹션만 전달하여 컨텍스트 효율을 높인다:
- **product-owner (PRD 작성)**: ARGS[0] + 코드 맵 + 프로젝트 타입/구조 + 프로젝트 루트 경로 + DOMAIN_CONTEXT (있으면)
- **product-owner (인수 검증)**: PRD의 "요구사항" + "수용 기준" + diff 파일 경로 (`DIFF_FILE`) + 코드 맵
- **architect (설계)**: PRD 전체 + 코드 맵 + 프로젝트 타입/구조/컨벤션 + 프로젝트 루트 경로 + DOMAIN_CONTEXT (있으면)
- **coder (구현)**: 설계서 전체 + 코드 맵 + 프로젝트 루트 경로. `--hotfix`이면 설계서 대신 PRD + 코드 맵.
- **coder (수정)**: 수정 항목 목록 + 수정 방안 + 코드 맵 + 프로젝트 루트 경로
- **qa-manager**: PRD의 "요구사항" + "수용 기준" + 설계서의 "변경 범위" 섹션 + 코드 맵
- **qa-manager (자기점검)**: PRD의 "요구사항" + "수용 기준" 섹션만 (스펙 충족 확인용)
- **security-auditor (통합 감사)**: PRD 전체 + 설계서 전체 + diff 파일 경로 (`DIFF_FILE`) + 코드 맵
- **design-critic (설계 비판)**: 설계서 초안 + PRD + 코드 맵 + 프로젝트 루트 경로
- **researcher (독립 조사)**: 조사 요청 + 코드 맵 (있으면) + 프로젝트 루트 경로
- **hacker (제약 우회)**: 정체 상황 설명 (에러 메시지, 시도한 접근) + 코드 맵 + 프로젝트 루트 경로
- **simplifier (복잡도 제거)**: 정체 상황 설명 + 설계서 + PRD + 코드 맵
- **playwright-tester**: PRD의 "요구사항" + "수용 기준" + diff 파일 경로 (`DIFF_FILE`) + 코드 맵 + 개발 서버 URL + 프로젝트 루트 경로
- **playwright-test-healer**: 테스트 파일 경로 목록 + 프로젝트 루트 경로 + 개발 서버 URL + 최대 재시도 횟수
- **todo-verifier**: 계획 파일 경로 + 코드 맵 + 프로젝트 루트 경로
- **plan-visualizer**: 계획 파일 경로

### 병렬 실행 규칙
읽기 전용 Agent(product-owner, architect, design-critic, qa-manager, security-auditor, researcher, hacker, simplifier)는 서로 병렬 실행이 가능하다. 병렬 실행 시:
1. 하나의 메시지에서 여러 `Task()` 호출을 동시에 발행한다.
2. 모든 병렬 Task가 완료된 후 결과를 합산한다 (Gate 로직).
3. 쓰기 Agent(coder)는 다른 쓰기 Agent와 병렬 실행하지 않는다.
4. coder와 읽기 전용 Agent의 병렬은 **읽기 Agent가 이전 Phase의 산출물(설계서 등)만 참조하는 경우** 허용한다.

### 정체 감지 + 에스컬레이션

phase-implement(구현→자기점검 루프)와 phase-review(QA→수정→재리뷰 루프)에서 적용한다.
각 루프의 최대 반복은 기존과 동일하다. 정체 감지 시 반복을 소진하지 않고 에스컬레이션으로 전환한다.

#### 감지 패턴

| 패턴 | 감지 기준 | 유형 |
|------|----------|------|
| SPINNING | 동일 에러 메시지가 2회 연속 반복 | 기계적 (텍스트 비교) |
| OSCILLATION | 접근법 A→B→A 왕복이 감지됨 | 정성적 (LLM 판단) |
| NO_DRIFT | 이전 반복과 비교해 코드 변경이 실질적으로 없음 (diff 비교) | 반기계적 (diff stat) |
| DIMINISHING_RETURNS | 수정 범위가 줄어드는데 테스트/리뷰 결과가 개선되지 않음 | 정성적 (LLM 판단) |

#### 에스컬레이션 경로

| 감지 패턴 | 1차 대응 | 2차 대응 (1차 실패 시) |
|----------|---------|---------------------|
| SPINNING | hacker에 제약 우회 분석 위임 | researcher에 근본 원인 분석 위임 |
| OSCILLATION | architect에 설계 재검토 요청 | 사용자에게 두 접근법 제시, 선택 요청 |
| NO_DRIFT | hacker에 제약 식별 + 우회 경로 요청 | researcher에 코드베이스 탐색 위임 |
| DIMINISHING_RETURNS | simplifier에 복잡도 분석 + 범위 축소 요청 | 사용자에게 현재 상태 보고, 방향 전환 여부 확인 |

### Gate 로직
phase-review의 Step 3~4에 정의. QA + ZT 결과를 합산하고 심각도별로 처리한다.

### Diff 수집 규칙
Agent에게 변경사항 diff를 전달할 때, 메인 컨텍스트 절약을 위해 **파일 리다이렉트 + 경로 전달**을 사용한다.

**핵심 원칙**: diff 출력이 Bash 결과로 메인 컨텍스트에 진입하지 않도록, **셸 리다이렉트로 파일에 직접 쓴다**.

#### 수집 절차

1. `DIFF_FILE = ${PROJECT_ROOT}/.dev/diff.txt`. **매 수집 시** `mkdir -p $(dirname ${DIFF_FILE})`을 실행하여 디렉토리 존재를 보장한다.
2. diff를 파일에 직접 리다이렉트한다 (Bash 결과에 diff가 나타나지 않음):
   ```bash
   ${GIT_PREFIX} diff --cached > ${DIFF_FILE}
   ```
3. `wc -l < ${DIFF_FILE}`로 줄 수를 확인한다.
4. 총 변경이 **500줄 이상**이면: `--stat` 요약을 파일 앞에 추가하고, 파일 끝에 "변경된 파일을 Read 도구로 직접 확인하라"는 안내를 추가한다:
   ```bash
   ${GIT_PREFIX} diff --cached --stat > ${DIFF_FILE}
   echo "---" >> ${DIFF_FILE}
   echo "위는 요약입니다. 변경된 파일을 Read 도구로 직접 확인하라." >> ${DIFF_FILE}
   ```
5. Agent 프롬프트에는 **파일 경로만 전달**한다:
   ```
   변경사항 diff: <DIFF_FILE>
   이 파일을 Read하여 변경사항을 확인하라.
   ```

이 규칙은 모든 diff 패턴에 적용한다: `${GIT_PREFIX} diff --cached` (스테이징), `${GIT_PREFIX} diff <base>...HEAD` (브랜치 비교) 등.

---

## 플래그 충돌 검증

- `--hotfix`와 `--phase`는 **동시 사용 불가**. 둘 다 있으면: "`--hotfix`와 `--phase`는 동시에 사용할 수 없습니다." 에러 후 중단.
- `--resume`과 `--phase`, `--hotfix`, `--status`는 **동시 사용 불가**. 함께 있으면: "`--resume`은 다른 모드 플래그와 동시에 사용할 수 없습니다." 에러 후 중단.
- `--resume`은 ARGS[0] 없이 단독 사용한다. ARGS[0]이 함께 있으면: "`--resume`은 작업 설명 없이 단독으로 사용합니다." 에러 후 중단.

## Phase 선택 (--phase 플래그)

`--phase`가 지정되면 해당 Phase만 실행한다:
- `--phase requirements`: setup (필요 시) + requirements만 실행 (PRD 작성).
- `--phase design`: setup (필요 시) + requirements + design만 실행. 대화 맥락에 요구사항이 없고 `${PROJECT_ROOT}/.dev/prd.md`도 없으면 requirements부터 시작.
- `--phase implement`: 환경 감지 + implement 실행. 대화 맥락에 설계서가 없고 `${PROJECT_ROOT}/.dev/design.md`도 없으면: "설계서가 필요합니다. `/dev --phase design`을 먼저 실행하거나 설계 내용을 입력해주세요." 후 중단.
- `--phase review`: 환경 감지 + 베이스 브랜치 감지 + review 실행 (현재 변경사항을 리뷰).
- `--phase complete`: 환경 감지 + 베이스 브랜치 감지 + complete 실행 (lint, test, commit, PR).

> **환경 감지**: 위 3개 모드는 phase-setup을 건너뛰므로, Phase 진입 전에 다음을 수행한다:
> 1. phase-setup의 Step 0.1(모드 감지)로 `GIT_PREFIX`를 초기 설정한다.
> 2. **일반 모드**: `PROJECT_ROOT` = 현재 디렉토리. 완료.
> 3. `git rev-parse --show-toplevel`로 프로젝트 루트를 파악하고 `PROJECT_ROOT`를 설정한다.

---

## 에러 처리

- Phase가 심각하게 실패하면 에러를 표시하고 사용자에게 진행 방법을 확인한다.
- 에러를 조용히 무시하지 않는다.
- 도구나 명령이 사용 불가하면 대안을 제안한다.
- 사용자가 중단하면 진행 상황을 저장하고 완료된 내용을 보고한다.
- phase-review의 ZT 통합 감사가 실패해도 QA 리뷰 결과만으로 진행한다. 감사 실패를 사용자에게 알린다.
- 2분 이상 소요될 수 있는 Bash 명령(`./gradlew test`, `npm test`, `npm install` 등)에는 `timeout: 300000`(5분)을 설정한다.

---

# Phase: setup (작업환경 준비)

## 0.0 진행 중 작업 감지

### `--resume` 플래그가 있는 경우
1. state.md를 탐색한다 (아래 탐색 규칙 동일).
2. 존재하고 `status: in_progress`이면 → 질문 없이 바로 재개 (아래 "이어서 진행" 절차).
3. state.md가 없거나 `status: completed`이면 → "재개할 작업이 없습니다." 출력 후 종료.

### `--resume` 플래그가 없는 경우 (자동 감지)
ARGS[0]이 있으면 → 새 작업이므로 자동 감지를 건너뛰고 0.1로 진행.
ARGS[0]이 없으면 → 아래 자동 감지 로직 실행.

1. 현재 디렉토리 기준으로 `.dev/state.md`를 탐색한다.
2. state.md가 존재하고 `status: in_progress`이면:
   - 사용자에게 AskUserQuestion으로 질문: "이전에 진행하던 작업이 있습니다."
     - "이어서 진행" → 재개
     - "새로 시작" → 0.1로 진행 (0.6에서 덮어씀)
3. state.md가 없거나 `status: completed`이면 → 0.1로 진행.

**이어서 진행 시:**
- state.md에서 GIT_PREFIX, PROJECT_ROOT, 베이스 브랜치, 프로젝트 타입, ARGS[0], flags를 복원.
- `test -d`로 경로 검증. 실패 시 에러 보고 후 새로 시작.
- prd.md, design.md, trust-ledger.md, codemap.md, self-check.md가 있으면 Read하여 맥락 복원.
- phases 맵에서 마지막 in_progress Phase를 찾아 재개.
- phase-setup의 나머지 단계(0.1~0.6)를 건너뛴다.

## 0.1 Git 저장소 및 모드 감지
아래 순서로 확인한다:
1. `git rev-parse --is-inside-work-tree` 확인. 성공 → `GIT_PREFIX` = `git`.
2. 실패 → AskUserQuestion: "Git 저장소가 아닙니다. `git init`으로 생성할까요?"
   - 예 → `git init` 실행 후 진행.
   - 아니오 → 중단.

## 0.2 베이스 브랜치 결정
공유 규칙의 "베이스 브랜치 감지"에 따라 결정한다.

결정 후 베이스 브랜치를 최신 상태로 동기화한다:
1. `${GIT_PREFIX} remote get-url origin`으로 remote 존재를 확인한다. 없으면 건너뛴다.
2. `${GIT_PREFIX} checkout <base-branch>`를 실행한다. 실패 시 경고를 표시하고 현재 로컬 상태로 계속 진행한다.
3. checkout 성공 시, `${GIT_PREFIX} pull origin <base-branch>`를 실행한다. pull 실패 시 경고를 표시하고 현재 로컬 상태로 계속 진행한다.

## 0.3 프로젝트 정보 수집
`PROJECT_ROOT`를 결정한다: 기본적으로 `PROJECT_ROOT = ./` (현재 디렉토리) 또는 `git rev-parse --show-toplevel` 결과.

아래 4개 작업은 서로 독립적이므로 **병렬로 실행**한다:
1. **프로젝트 타입 감지**: `PROJECT_ROOT`에서 빌드/설정 파일을 스캔하여 타입을 결정한다 (`build.gradle.kts`, `build.gradle`, `package.json`, `pyproject.toml`, `setup.py`).
2. **디렉토리 구조 수집**: `PROJECT_ROOT`의 최상위 2레벨 디렉토리 구조를 수집한다.
3. **CLAUDE.md 확인**: `PROJECT_ROOT`에 CLAUDE.md가 있으면 읽어서 코딩 컨벤션을 확보한다.
4. **도메인 컨텍스트 탐색**: 현재 레포와 매칭되는 도메인 컨텍스트를 찾는다 (있으면).

## 0.4 관련 코드 맵 생성
ARGS[0]에서 도메인 키워드를 추출하여 `PROJECT_ROOT` 내에서 관련 코드를 탐색하고 초기 코드 맵을 생성한다.

1. **키워드 추출**: ARGS[0]에서 핵심 도메인 키워드를 추출한다 (이슈 키 제외).
   - 예: "[JIRA-123] 결제 한도 변경" → `결제`, `한도` → `payment`, `limit`, `amount`
2. **관련 파일 탐색**: `PROJECT_ROOT`를 기준으로 키워드로 Grep하여 관련 파일을 수집한다.
3. **핵심 파일 스캔**: 발견된 파일의 상단(클래스 선언, 주요 상수/메서드 시그니처)을 Read하여 역할을 한 줄로 정리한다.
4. **코드 맵 작성**: 핵심 파일 / 참조 파일 / 설정으로 분류하여 맵을 작성한다.

탐색은 **가볍게** — 파일 전체를 읽지 않고, 역할 파악에 필요한 최소한만 읽는다. 코드 맵에 등록하는 파일은 **최대 15개**로 제한한다 (핵심 ≤ 5, 참조 ≤ 7, 설정 ≤ 3).

## 0.5 작업환경 생성
격리된 작업환경을 생성한다.
- ARGS[0]에서 브랜치명을 생성한다:
  1. 이슈 키 추출 시도: 대문자 영문 + `-` + 숫자 패턴 (e.g., `JIRA-123`, `PAY-456`)
  2. **이슈 키가 있으면**: 이슈 키를 브랜치명으로 사용 (e.g., `[JIRA-123] 로그인 기능 추가` → 브랜치 `JIRA-123`)
  3. **이슈 키가 없으면**: 핵심 키워드 추출, 한국어→영어 번역, 최대 40자 (e.g., `로그인 기능 추가` → `login-feature`)
- `git checkout -b <branch-name>`으로 브랜치를 생성한다. 브랜치가 이미 존재하면 `git checkout <branch-name>`으로 전환한다.
- 완료 후 프로젝트 타입, 브랜치명, 작업 경로를 사용자에게 보고.

## 0.5a .gitignore 자동 보강
프로젝트 타입에 따라 `${PROJECT_ROOT}/.gitignore`에 빌드 아티팩트 패턴을 추가한다. 이미 존재하는 패턴은 건너뛴다.

| 프로젝트 타입 | 추가 패턴 |
|---------------|-----------|
| kotlin-gradle, java-gradle | `.gradle/`, `build/` |
| node (npm/yarn/pnpm/bun) | `node_modules/`, `dist/`, `.next/` |
| python | `__pycache__/`, `.venv/`, `*.pyc`, `dist/` |

`.dev/` 패턴도 이 단계에서 함께 추가한다.

## 0.6 진행 상태 초기화
`${PROJECT_ROOT}/.dev/state.md`에 초기 상태를 Write한다:
- phase: setup, status: in_progress
- branch, base, project-type, project-root, args, flags 기록
- phases: { setup: completed }

## 0.7 계획 파일 초기화
config.json의 `verification.enabled`가 `true`이면:
1. `mkdir -p ${PROJECT_ROOT}/docs/plan ${PROJECT_ROOT}/docs/show`
2. 이슈키가 있으면 `${PROJECT_ROOT}/docs/plan/{이슈키}-plan.md` 스켈레톤 생성:
   - 메타데이터 (상태: IN_PROGRESS, 생성일, 브랜치, 베이스)
   - 나머지 섹션은 빈 상태
3. `state.md`에 `plan-file` 경로 기록.

---

# Phase: requirements (PRD Q&A 사이클)

**최대 1회 반복.**

## Hotfix 모드 분기

`--hotfix` 모드이면 경량 PRD를 작성한다:
- product-owner에게 "경량 PRD 작성"으로 동작할 것을 지시한다.
- 포함 섹션: 배경 + 요구사항 + 수용 기준만 (3관점 품질 검증, Q&A 생략).
- 작성 완료 후 사용자에게 전문 표시 + 승인 확인.
- 승인 → `${PROJECT_ROOT}/.dev/prd.md`에 저장 후 phase-implement로 진행.
- 수정 요청 → 1회 수정 후 저장.

hotfix가 아닌 경우 아래 정상 플로우를 따른다.

---

**Step 1**: product-owner agent를 호출한다 (PRD 작성).
`Task(subagent_type="product-owner")` — prompt에 다음을 포함:
- 기능/버그 설명: ARGS[0]
- 코드 맵 (phase-setup에서 생성한 초기 맵)
- 프로젝트 타입, 디렉토리 구조
- 프로젝트 루트 경로
- "PRD 작성"으로 동작할 것
- 이전 Q&A 히스토리 (사용자 수정 요청이 있었으면: 이전 PRD 초안 + 사용자 답변)
- PRD 품질 자가 검증 3관점:
  1. **유저 경험 검증**: 이 정책대로 만들면 사용자가 자연스럽게 이해하고 행동할 수 있는가.
  2. **해석 여지 제거**: 개발자/디자이너/PO가 같은 문서를 보고 다르게 해석할 여지가 없는가.
  3. **엣지케이스 커버리지**: 빈 상태, 로딩, 에러, 수량/길이의 최솟값/최댓값이 정의되어 있는가.

**Step 2**: Agent 출력(PRD + 질문)을 사용자에게 **전문 표시**한다.

**Step 3**: Agent 출력에서 "탐색 추가 항목"을 파싱하여 코드 맵에 누적한다.

**Step 4**: 질문 여부를 확인한다.

**질문이 있으면**: PRD와 질문 목록을 사용자에게 출력한 뒤, 사용자의 다음 입력을 기다린다. 사용자 답변을 반영하여 product-owner를 1회 더 호출.

**질문이 없으면**: 사용자에게 확인 후 phase-design으로 진행.

**Phase 완료 후 저장**: 확정된 PRD를 `${PROJECT_ROOT}/.dev/prd.md`에 Write한다.

**계획 파일 채움** (verification.enabled이면):
1. PRD의 "요구사항" + "수용 기준"을 계획 파일의 `최종 완료 기준`에 반영.
2. 수용 기준별 TODO 항목 생성 + 적절한 태그 부여 ([FILE_EXISTS], [TEST_PASSES], [CRITERIA] 등).
3. `verification.autoVisualize`가 true이면 `Task(subagent_type="plan-visualizer")` 호출.

**Phase 완료 보고 (요약 모드)**: PRD 저장 후 사용자에게 **요약만** 출력한다.

---

# Phase: design (설계 Q&A 사이클)

**최대 2회 반복.**

## 각 반복 (1~2회)

**Step 0**: `${PROJECT_ROOT}/.dev/prd.md`를 Read하여 확정된 PRD를 로드한다.

**Task**: architect agent를 호출한다 (설계).
`Task(subagent_type="architect")` — prompt에 다음을 포함:
- 확정된 PRD (Step 0에서 로드)
- 코드 맵 (누적된 상태)
- 프로젝트 타입, 디렉토리 구조, 컨벤션
- 프로젝트 루트 경로
- "설계"로 동작할 것
- 이전 Q&A 히스토리 (이전 반복의 답변, 있으면)

## Task 완료 후

**Step 1**: architect 출력을 사용자에게 **전문 표시**한다.

**Step 2**: architect 출력에서 "탐색 추가 항목"을 파싱하여 코드 맵에 누적한다.

**Step 2.5**: 설계 비판 검토 (선택적).

architect 출력의 "설계 규모" 필드가 **소형**이면 이 단계를 건너뛴다. 중형/대형인 경우에만 수행한다.

design-critic agent를 호출한다.
`Task(subagent_type="design-critic")` — prompt에 다음을 포함:
- architect의 설계 초안
- PRD
- 코드 맵
- 프로젝트 루트 경로

design-critic 결과 처리:
- **MUST-ADDRESS 항목이 있으면**: 사용자에게 표시하고 다음 architect 반복의 피드백으로 전달.
- **CONSIDER만 있으면**: 요약만 표시.
- **문제 없음**: 한 줄로 알림.

**Step 3**: 질문 여부를 확인한다.

**질문이 있으면**: 설계 초안과 질문 목록을 사용자에게 출력한 뒤, 사용자의 다음 입력을 기다린다.

**질문이 없으면**: 사용자에게 확인 후 phase-implement로 진행.

**2회 반복 후**: 최신 설계로 phase-implement를 진행한다.

**Phase 완료 후 저장**: 확정된 설계 문서를 `${PROJECT_ROOT}/.dev/design.md`에 Write한다.

**계획 파일 보강** (verification.enabled이면):
1. 설계서의 "구현 순서"를 계획 파일의 Step으로 매핑.
2. 각 Step에 TODO 항목 + 기계적 완료 기준 태그 추가 (파일 생성 → [FILE_EXISTS], 테스트 → [TEST_PASSES] 등).
3. `Task(subagent_type="plan-visualizer")` 호출.

**Phase 완료 보고 (요약 모드)**: 설계서 저장 후 사용자에게 **요약만** 출력한다.

---

# Phase: implement (구현 + 자기점검)

## Hotfix 모드 분기

`--hotfix` 모드이면:
- Step 0에서 설계서(`design.md`) 로드를 건너뛴다. PRD(`prd.md`)는 로드한다.
- 구현 Task에서 설계서 대신 PRD와 코드 맵을 전달한다.
- 자기점검은 동일하게 실행한다.

## 구현

**Task A**: coder 구현.

**Step 0**: 문서 로드.
- `${PROJECT_ROOT}/.dev/design.md`를 Read하여 설계서를 로드한다.
- `${PROJECT_ROOT}/.dev/prd.md`를 Read하여 PRD를 로드한다.

`Task(subagent_type="coder")` — prompt에 다음을 포함:
- 확정된 설계서
- 코드 맵
- 프로젝트 타입 및 구조
- 프로젝트 루트 경로
- "구현 순서" 섹션에 따라 순서대로 구현할 것
- 계획 파일 경로 (`plan-file` from state.md)
- "각 TODO 완료 시 계획 파일의 해당 항목을 체크(- [x])하고 검증 상태를 갱신하라"
- "구현 중 발견한 버그/변경사항을 변경 이력 섹션에 기록하라"

## Task 완료 후

**Step 1**: coder 결과의 **요약만** 사용자에게 보고한다 (Agent 전문 출력 금지).

## 자기점검 (1회 패스, 루프 없음)

사용자 리뷰(phase-review) 전에 명백한 실수를 자동으로 잡는다. **1회만 실행하고 루프하지 않는다.**

**조건**: `${GIT_PREFIX} diff --stat`으로 변경 규모와 대상 파일을 확인한다. 다음 **두 조건을 모두** 만족할 때만 자기점검을 건너뛴다:
1. 총 변경이 **10줄 미만**
2. 변경된 파일이 **설정 파일만**으로 구성

**Step 1**: 변경사항 수집 및 파일 저장. `${GIT_PREFIX} add -A` 후 **Diff 수집 규칙**에 따라 diff를 `DIFF_FILE`에 리다이렉트한다.

**Step 2**: qa-manager agent로 자동 리뷰.
`Task(subagent_type="qa-manager")` — prompt에 다음을 포함:
- 변경사항 diff 파일 경로 (`DIFF_FILE`) + Read 지시
- PRD의 "요구사항" + "수용 기준" 섹션만
- "자기점검 단계이므로 CERTAIN 문제만 자동 수정 대상으로 취급할 것."

**Step 3**: 결과 판단.
- **Critical이 있으면**: coder로 자동 수정 (1회). 수정 실패 시 미해결로 phase-review에 이월.
- **Critical이 없으면**: 자기점검 완료.
- Warning/Info는 `SELF_CHECK_FINDINGS`에 저장. QUESTION은 `SELF_CHECK_QUESTIONS`에 저장.
- 자기점검 결과를 `${PROJECT_ROOT}/.dev/self-check.md`에 Write한다.

## TODO 검증 (verification.enabled이면)

자기점검 완료 후, 계획 파일의 완료 기준을 검증한다.

**Step**: todo-verifier 호출.
`Task(subagent_type="todo-verifier")` — prompt에 다음 포함:
- 계획 파일 경로 + 코드 맵 + 프로젝트 루트 경로
- "PENDING 상태인 항목을 검증하고 계획 파일을 업데이트하라"

**검증 실패 시**: FAILED 항목을 coder에 수정 지시. 최대 `verification.maxVerificationRetries`회(기본 2) 반복.
- coder 수정 → todo-verifier 재검증 → 여전히 FAILED → 사용자에게 보고

**검증 완료 시**: `Task(subagent_type="plan-visualizer")` 호출.

이후 phase-review로 진행.

---

# Phase: review (검토 + 통합 감사)

**최대 2회 반복.**

**문서 로드**: `${PROJECT_ROOT}/.dev/prd.md`와 `${PROJECT_ROOT}/.dev/design.md`를 Read한다. 파일이 없으면 건너뛴다.

## Step 0: Mechanical Gate (lint + build + test)

QA/ZT 에이전트 호출 전에 기계적 검증을 통과시킨다.

### 0-1. Lint
- 프로젝트 타입에 따른 lint 명령: kotlin-gradle → `./gradlew ktlintFormat`, node → `bun run lint --fix` 또는 `npm run lint -- --fix`, python → `ruff format .`
- lint 변경이 있으면 `${GIT_PREFIX} add -A`로 스테이징에 포함한다.

### 0-2. Build
**빌드 명령 결정**:
1. `${PROJECT_ROOT}/CLAUDE.md`를 Read하여 빌드 명령을 탐색한다.
2. 없으면 프로젝트 타입에서 기본값을 사용한다.
3. 결정 불가 → AskUserQuestion.

**실행 흐름**: 빌드 실패 → coder로 자동 수정 → 1회 재시도 → 재실패 시 사용자에게 보고.

### 0-3. Test
테스트 실패 → coder로 자동 수정 → 1회 재시도 → 재실패 시 사용자에게 보고.

### 0-4. 계획 기준 교차 검증 (verification.enabled이면)
Mechanical Gate 결과를 계획 파일에 반영:
1. lint 통과 → `[LINT]` 체크, test 통과 → `[TEST]` 체크, build 통과 → `[BUILD]` 체크.
2. 미검증 `[CRITERIA]` 있으면 `Task(subagent_type="todo-verifier")` 호출.

---

각 반복(1~2회)에서:

**Step 1**: 변경사항 수집. `${GIT_PREFIX} add -A` 후 **Diff 수집 규칙**에 따라 diff를 `DIFF_FILE`에 저장.

**Step 2**: qa-manager와 security-auditor를 **병렬로** 호출한다.

**Task A**: qa-manager agent.
- 변경사항 diff 파일 경로 + PRD/설계서의 관련 섹션 + 코드 맵

**Task B**: security-auditor 통합 감사.
- PRD 전체 + 설계서 전체 + diff 파일 경로 + 코드 맵

**Step 2.5: Playwright E2E 테스트 (조건부)**

프론트엔드 변경이 감지된 경우에만 실행. 백엔드 전용이면 건너뛴다.

#### 2.5-0. 프론트엔드 변경 감지
1. config.json의 `playwrightTesting.enabled`가 `false`면 건너뛴다.
2. `DIFF_FILE`에서 변경 파일 목록 추출 → `playwrightTesting.frontendFilePatterns`과 매칭.
3. 매칭 없으면 `PROJECT_ROOT`에서 `playwrightTesting.devServerConfigFiles` 존재 여부 확인.
4. 둘 다 해당 없으면: `execution-log`에 `"playwright: 건너뜀 (프론트엔드 변경 없음)"` 기록, Step 3으로 진행.
5. `package.json`에 `@playwright/test` 의존성이 없으면: `"Playwright 미설치 — E2E 건너뜀"` 기록, Step 3으로 진행.

#### 2.5-1. 개발 서버 시작
1. `playwrightTesting.devServerCommand`가 있으면 해당 명령 사용. 없으면 프로젝트 런타임에서 추론: `bun dev` 또는 `npm run dev`.
2. 백그라운드 실행, PID 캡처: `DEV_SERVER_PID=$!`
3. `playwrightTesting.devServerUrl`(기본 `http://localhost:3000`)에 `playwrightTesting.devServerStartTimeout`(기본 30초) 내 응답 확인.
4. 타임아웃 시: 서버 프로세스 정리 후 경고 표시, Step 3으로 진행.

#### 2.5-2. 인증 전략 수립 (planner 내 선행 단계)
planner가 테스트 계획 수립 시 **인증 요구사항을 먼저 분석**하여 테스트 중단을 방지한다.

1. 코드 맵 + diff에서 인증/로그인 관련 코드 탐색 (미들웨어, 토큰 검증, 세션 체크 등).
2. 테스트 대상 페이지가 인증을 요구하는지 판단.
3. 인증이 필요하면 사용자에게 AskUserQuestion으로 전략을 확인:
   - **A. 테스트용 토큰/계정 제공** — 사용자가 토큰 또는 로그인 정보를 제공. planner가 테스트 계획에 인증 선행 단계를 포함.
   - **B. 인증 로직 임시 우회** — 테스트 동안 인증 미들웨어/가드를 주석 처리. coder에게 위임하여 임시 비활성화 → 테스트 완료 후 원복.
   - **C. 인증 불필요** — 공개 페이지만 테스트. 그대로 진행.
4. 선택된 전략을 테스트 계획에 `## 인증 전략` 섹션으로 기록.

**B 선택 시 흐름:** playwright-tester 완료 후 coder에게 인증 우회 코드 수정 위임 → healer 실행 → Step 2.5-5에서 coder에게 인증 코드 원복 위임.

#### 2.5-3. 테스트 계획 + 코드 생성 (playwright-tester)
`Task(subagent_type="playwright-tester")` — prompt에 다음 포함:
- 개발 서버 URL + PRD의 "요구사항" + "수용 기준" + diff 파일 경로 + 코드 맵
- 프로젝트 루트 경로
- "변경된 기능에 집중하여 테스트 시나리오를 설계하고 .spec.ts 파일을 생성하라"
- 인증 전략 (있으면)

playwright-tester가 브라우저 탐색 → 시나리오 설계 → 코드 생성을 하나의 흐름으로 수행한다.
생성된 테스트 파일 경로를 `PLAYWRIGHT_TEST_FILES`에 보관.

#### 2.5-4. 테스트 실행 및 수정 (playwright-test-healer)
`Task(subagent_type="playwright-test-healer")` — prompt에 다음 포함:
- 테스트 파일 경로 목록 (`PLAYWRIGHT_TEST_FILES`) + 프로젝트 루트 경로 + 개발 서버 URL
- 최대 재시도: `playwrightTesting.maxHealerRetries` (기본 2)
- "테스트 코드 문제는 직접 수정. 앱 코드 문제는 수정 없이 보고 반환."

healer 출력: 테스트 결과 요약 (통과/수정 후 통과/fixme/미해결 실패).

#### 2.5-5. 인증 원복 + 개발 서버 종료
1. 인증 전략 B(임시 우회)였으면: coder에게 인증 코드 원복 위임 → 원복 확인.
2. `kill ${DEV_SERVER_PID}`로 서버 종료. 포트 해제 확인.

#### 2.5-6. 결과 기록
- `execution-log`에 `{ phase: review, step: playwright-e2e, result: "N개 pass, M개 fail, K개 fixme" }` 기록.
- Trust Ledger에 `### E2E 테스트 (review)` 섹션을 append.

**Step 3**: qa-manager + security-auditor + Playwright E2E 결과(있으면)를 합산한다. Trust Ledger를 저장한다. 사용자에게 **요약만** 표시.
- Playwright fixme → Warning (비블로킹).
- Playwright 미해결 실패 → Critical.

**Step 4: 결과 처리**
- QA/ZT Critical → coder로 자동 수정 (기존)
- Playwright 미해결 실패 (앱 코드 문제) → coder에 UI 코드 수정 위임 → 1회 재시도
- QUESTION → 사용자 확인 → 반복 판단
- 2회 반복 후 미해결 Critical이 있으면 사용자에게 진행 여부 확인.

---

# Phase: complete (완료)

각 단계가 실패하면 사용자에게 보고하고 진행 여부를 확인한다.

## 5.1 인수 검증 (ProductOwner)
PRD가 없으면 이 단계를 건너뛴다.

PRD가 있으면 product-owner에게 인수 검증을 요청한다.
- **ACCEPT**: "인수 검증 통과." 다음 단계 진행.
- **REJECT**: 미충족 항목 표시. 수정 여부 확인. 수정 시 coder로 수정 후 1회 재검증.

## 5.2 Commit
`commit` 스킬을 Read하여 프로세스를 실행한다 (lint → test → commit 일괄).

**test 실패 시 자동 수정 (1회):** coder에 수정 요청 → 재호출 → 재실패 시 사용자에게 보고.

## 5.3 PR 생성
`pull-request` 스킬을 Read하여 프로세스를 실행한다.

1. **비즈니스 맥락 조립**: PRD의 "배경"과 "요구사항", 설계서의 "배경 및 목적"을 PR 본문에 반영.
2. **Trust Ledger 요약 삽입**: trust-ledger.md가 있으면 PR 본문에 `## Audit Summary` 섹션 추가.
3. pull-request이 전제조건 미충족으로 종료하면 후속 안내.

## 5.4 진행 상태 완료
`${PROJECT_ROOT}/.dev/state.md`의 `status`를 `completed`로 갱신한다.

**계획 파일 최종화** (verification.enabled이면):
1. 계획 파일의 `상태`를 `COMPLETED`로 갱신.
2. `Task(subagent_type="plan-visualizer")` 호출하여 최종 HTML 생성.

## 5.5 다음 단계

PR이 생성되었으면 완료이다. **PR 머지는 절대 실행하지 않는다** — 머지는 리뷰어가 직접 수행한다.

리뷰 수정 요청에 대비하여 작업환경 유지를 안내한다:
"리뷰 피드백 대응을 위해 현재 브랜치를 유지합니다. 리뷰 완료 후 베이스 브랜치로 전환하세요."
