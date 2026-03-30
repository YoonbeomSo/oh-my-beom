# oh-my-beom

한국어 개발자를 위한 Claude Code 플러그인.
에이전트 기반 개발 파이프라인, 동적 스킬 라우팅, 코딩 가이드라인 자동 주입을 제공합니다.

## 설치

```bash
claude plugin add --from-github YoonbeomSo/oh-my-beom
```

---

## 핵심 기능

### 동적 라우팅 (UserPromptSubmit Hook)

사용자 입력을 자동으로 분석하여 적절한 스킬로 라우팅합니다.

| 키워드 | 라우팅 대상 |
|--------|------------|
| 계획, plan, 설계 | `/plan` — 4-Mode 계획 전략 |
| 분석, 조사, research | `/research` — 리서치 파이프라인 |
| 끝까지, 멈추지마, persist | `/persist` — 지속 실행 모드 |
| 개발, dev, 구현 | `/dev` — 전체 개발 라이프사이클 |
| 정책, 비즈니스, lens | `/lens` — 정책 탐지 + 영향 분석 |

### 가이드라인 자동 주입 (SessionStart Hook)

세션 시작 시 코딩 가이드라인이 자동으로 주입됩니다.
한국어 응답, 코딩 전 사고, 단순함 우선, 외과적 변경 등 7개 원칙.

### Protected Branch 보호 (PreToolUse Hook)

main/master/develop 브랜치에서 직접 커밋을 차단합니다.

### 작업 완료 검증 (TaskCompleted Hook)

작업 완료 시 자동으로 검증을 수행합니다.

### 유휴 팀원 감지 (TeammateIdle Hook)

팀 에이전트의 유휴 상태를 감지합니다.

### 자동 체이닝 워크플로우

각 스킬은 완료 후 자동으로 다음 스킬을 호출합니다.

```
/lens → /research → /plan → (확인) → /dev
```

| 시작 스킬 | 자동 실행 흐름 | 상황 |
|-----------|--------------|------|
| `/lens` | → `/research` → `/plan` → `/dev` | 정책/비즈니스 영향 분석이 필요할 때 |
| `/research` | → `/plan` → `/dev` | 코드베이스 파악이 필요할 때 |
| `/plan` | → `/dev` | 요구사항이 명확할 때 |
| `/dev` | (최종 스킬) | 간단한 버그 수정/핫픽스 |

- `/plan` → `/dev` 전환 시에만 사용자 확인을 받습니다.
- 단일 스킬만 실행하려면 `--only` 플래그를 사용하세요. (예: `/research --only`)

세션 시작 시 워크플로우 가이드가 자동으로 표시됩니다.

---

## 에이전트

### 팀 에이전트 (5개, TeamCreate + tmux pane)

`/dev` 실행 시 tmux 환경이면 TeamCreate로 생성되어 파이프라인 전체에 걸쳐 상시 실행됩니다.

| Agent | 역할 | 모델 |
|-------|------|------|
| **product-owner** | PRD 작성 + AC 검증 | sonnet |
| **architect** | 기술 설계 | sonnet |
| **coder** | 코드 구현 + 수정 | inherit |
| **qa-manager** | 코드 리뷰 + 스펙 검증 | sonnet |
| **security-auditor** | 보안/정책 감사 | sonnet |

### 유틸리티 에이전트 (7개, on-demand)

필요할 때만 Agent tool로 개별 호출됩니다.

| Agent | 역할 |
|-------|------|
| **researcher** | 코드베이스 탐색 + 분석 |
| **hacker** | 제약 우회 + 돌파구 (정체 감지 시) |
| **simplifier** | 복잡도 줄이기 (정체 감지 시) |
| **plan-visualizer** | 계획 MD → HTML 대시보드 변환 |
| **todo-verifier** | 계획 완료 기준 vs 코드 상태 검증 |
| **web-test-qa** | E2E 테스트 전체 사이클 (계획+생성+디버깅) |
| **design-critic** | 설계 가정 도전 (에이전트 정의, 스킬로도 호출 가능) |

---

## 18개 Skills

### 개발 워크플로우

| 명령어 | 설명 |
|--------|------|
| `/dev` | 전체 개발 라이프사이클 (PRD → 설계 → 구현 → 리뷰 → 완료) |
| `/commit` | 스마트 커밋 (이슈키 파싱, pre-check, 민감파일 감지) |
| `/pull-request` | PR 자동 생성 (커밋 히스토리 기반) |
| `/worktree` | Git worktree 자동화 (create/list/remove/done/switch) |

### 분석 + 계획

| 명령어 | 설명 |
|--------|------|
| `/plan` | 4-Mode 계획 전략 (Direct/Interview/Consensus/Review) |
| `/research` | 리서치 파이프라인 (Explorer → Researcher → Analyzer) |
| `/lens` | 비즈니스 정책 탐지 + 영향 분석 |
| `/persist` | 지속 실행 모드 (6-Phase, 완료까지 멈추지 않음) |

### 유틸리티

| 명령어 | 설명 |
|--------|------|
| `/hecto-setup` | HectoProject용 CLAUDE.md를 프로젝트에 설정 |
| `/new-context` | 도메인 컨텍스트 디렉토리 생성 |
| `/humanizer` | AI 글쓰기 패턴 제거 (40+ 패턴 감지) |
| `/design-critic` | 설계 비판 검토 (CHALLENGE/SIMPLIFY/ROOT-CAUSE) |
| `/test-plan` | E2E 테스트 계획 (인증 분석 + 시나리오 설계) |
| `/test-generate` | E2E 테스트 코드 생성 (.spec.ts) |
| `/test-heal` | E2E 테스트 실행 + 실패 디버깅/수정 |

### 외부 연동

| 명령어 | 설명 |
|--------|------|
| `/fetch-jira-issue` | Jira 이슈 조회 (MCP 우선, REST API fallback) |
| `/fetch-jenkins` | Jenkins 빌드 상태 조회/트리거/로그 확인 |
| `/tmux-team-agent` | TeamCreate 후 빈 tmux pane 감지 + CLI 자동 복구 |

---

## 디렉토리 구조

```
oh-my-beom/
├── .claude-plugin/
│   ├── plugin.json                   # 플러그인 메타데이터
│   └── marketplace.json              # 마켓플레이스 등록 정보
├── CLAUDE.md                         # 플러그인 스코프/제약사항
├── hooks/
│   ├── hooks.json                    # 5개 hook 정의
│   ├── session-start                 # 가이드라인 주입
│   ├── prompt-router                 # 키워드 감지 → 스킬 라우팅
│   ├── pre-tool-guard                # protected branch 보호
│   ├── task-verifier                 # 작업 완료 검증
│   └── idle-checker                  # 유휴 팀원 감지
├── rules/
│   ├── behavior.md                   # 코딩 원칙
│   ├── git-workflow.md               # 브랜치/커밋 규칙
│   └── workspace-structure.md        # 워크스페이스 구조
├── config/
│   └── config.json                   # 이슈키, 프로젝트 타입, 타임아웃
├── agents/                           # 12개 에이전트
├── skills/                           # 18개 스킬
├── docs/                             # 시각화 산출물
└── package.json
```

---

## references

- 코딩 가이드라인: [LOOPERS](https://www.loopers.im/)
- Playwright Test Agents: [Playwright](https://playwright.dev/docs/test-agents)
