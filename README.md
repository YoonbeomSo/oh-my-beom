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

---

## 12개 에이전트

### 개발 파이프라인 에이전트 (9개)

| Agent | 역할 | 모델 |
|-------|------|------|
| **product-owner** | PRD 작성 + AC 검증 (요구사항 분석 7단계 포함) | sonnet |
| **architect** | 기술 설계 (API/JPA 설계 원칙 내장) | sonnet |
| **design-critic** | 설계 가정 도전 (CHALLENGE/SIMPLIFY/ROOT-CAUSE) | opus |
| **coder** | 코드 구현 (Spring Boot/JPA/QueryDSL 컨벤션 내장) | inherit |
| **qa-manager** | 코드 리뷰 (25조항 코딩 컨벤션 + 20조항 추상화 원칙) | sonnet |
| **security-auditor** | 보안/정책 감사 (Zero Trust) | sonnet |
| **researcher** | 코드베이스 탐색 + 분석 | sonnet |
| **hacker** | 제약 우회 + 돌파구 | sonnet |
| **simplifier** | 복잡도 줄이기 | sonnet |

### Playwright 테스트 에이전트 (3개)

| Agent | 역할 |
|-------|------|
| **playwright-test-planner** | 테스트 계획 생성 |
| **playwright-test-generator** | 테스트 코드 작성 |
| **playwright-test-healer** | 실패 테스트 디버깅/수정 |

---

## 11개 Skills

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

---

## 디렉토리 구조

```
oh-my-beom/
├── .claude-plugin/plugin.json        # 플러그인 메타데이터
├── CLAUDE.md                         # 플러그인 스코프/제약사항
├── guidelines/
│   └── CLAUDE.md                     # 세션 시작 시 자동 주입
├── hooks/
│   ├── hooks.json                    # 3개 hook 정의
│   ├── session-start                 # 가이드라인 주입
│   ├── prompt-router                 # 키워드 감지 → 스킬 라우팅
│   └── pre-tool-guard                # protected branch 보호
├── rules/
│   ├── behavior.md                   # 코딩 원칙
│   ├── git-workflow.md               # 브랜치/커밋 규칙
│   └── workspace-structure.md        # 워크스페이스 구조
├── config/
│   └── config.json                   # 이슈키, 프로젝트 타입, 타임아웃
├── agents/                           # 12개 에이전트
├── skills/                           # 11개 스킬
└── package.json
```

---

## references

- 코딩 가이드라인: [LOOPERS](https://www.loopers.im/)
- Playwright Test Agents: [Playwright](https://playwright.dev/docs/test-agents)
