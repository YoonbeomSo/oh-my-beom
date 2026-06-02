# oh-my-beom

한국어 개발자를 위한 Claude Code 플러그인.
에이전트 팀 기반 개발 파이프라인으로, 기능 개발 / 버그 수정 / 분석 / 자율 실행을 지원합니다.

## 설치

```bash
claude plugin install oh-my-beom@syb1224
```

## 업데이트

새 버전이 `main`에 머지된 뒤 로컬을 갱신하려면:

```
/plugin
```

→ 메뉴에서 `oh-my-beom` 선택 → **Update**.

또는 CLI:

```bash
claude plugin update oh-my-beom
# 갱신이 안 잡히면 재설치:
claude plugin install oh-my-beom@syb1224
```

설치된 버전 확인:

```bash
cat ~/.claude/plugins/cache/syb1224/oh-my-beom/*/.claude-plugin/plugin.json | grep version
```

### QA 리뷰 방식

Phase 5 QA 리뷰는 `Agent(subagent_type="oh-my-beom:qa-manager")` 단일 호출로 수행됩니다. qa-manager는 Sonnet 모델로 동작하며, Agent 일회성 호출이므로 페르소나가 메인 세션 컨텍스트에 영구 진입하지 않습니다.

---

## 하네스 구조

```
oh-my-beom/
├── CLAUDE.md                         # 최상위 지침 (금지 사항 + 워크플로우)
├── agents/                           # 에이전트 6개
│   ├── planner.md                    # plan 관리, TODO, QA 이슈 수신
│   ├── architect.md                  # 기술 설계 + 비판적 자기검토
│   ├── coder.md                      # 코드 구현/수정, 빌드/테스트
│   ├── qa-manager.md                 # 코드 리뷰, 스펙 검증, 기본 보안 체크
│   ├── web-tester.md                 # E2E 테스트 생성+실행 (16 tools)
│   └── web-test-runner.md            # E2E 테스트 실행 전용 (8 tools)
├── skills/                           # 스킬 18개 (메인 4 + 유틸 14)
│   ├── dev-beom/                     # 기능 개발
│   ├── fix-beom/                     # 버그 수정
│   ├── analysis-beom/                # 코드/정책 분석
│   ├── persist-beom/                 # 자율 실행 (끝까지)
│   ├── tdd/                          # TDD 방법론 (Red-Green-Refactor)
│   ├── web-test/                     # E2E 웹 테스트 (Playwright + OTP 바이패스)
│   ├── commit/                       # Git 커밋 (이슈키 파싱, pre-check)
│   ├── pull-request/                 # GitHub PR 자동 생성
│   ├── merge-request/                # GitLab MR 자동 생성
│   ├── fetch-jira-issue/             # Jira 이슈 조회 (내부 유틸리티)
│   ├── fetch-jenkins/                # Jenkins 빌드 관리
│   ├── fetch-elk/                    # ELK/Elasticsearch 로그 조회
│   ├── worktree/                     # Git worktree 자동화
│   ├── version-bump/                 # 플러그인 버전 일괄 갱신 (3개 파일 동기화)
│   ├── tmux-team-agent/              # tmux pane 복구 (tmux 전용)
│   ├── humanizer/                    # AI 글쓰기 패턴 제거
│   ├── hecto-setup/                  # HectoProject CLAUDE.md 자동 설정
│   └── new-context/                  # 도메인 컨텍스트 생성
├── hooks/                            # 안전 훅 8개
│   ├── hooks.json                    # 훅 설정
│   ├── pre-tool-guard                # 보호 브랜치 커밋 차단 + 웹 테스트 게이트
│   ├── pre-commit-build-check        # 커밋 전 빌드/타입체크 검증
│   ├── version-sync-check            # 커밋 전 플러그인 메타 3개 파일 버전 일치 검증
│   ├── doc-sync-check                # 커밋 전 구조 변경 시 HTML 문서 동반 갱신 강제
│   ├── code-quality-gate             # 시크릿/보안 감지
│   ├── error-learner                 # 에러 기록 + 반복 감지 → 접근 방식 변경 유도
│   ├── web-test-detector             # [WEB-TEST-REQUIRED] 마커 감지
│   └── team-recovery-reminder        # TeamCreate 후 환경 감지 + 복구 스킬 호출 자동 주입
├── rules/                            # 행동 규칙 2개
│   ├── behavior.md                   # 행동 원칙 (읽기 우선, 단순함, 외과적 변경)
│   └── git-workflow.md               # Git 브랜치/커밋/PR 규칙
├── config/
│   └── config.json                   # 프로젝트 타입, 민감파일, 타임아웃
└── docs/
    ├── plan/                         # plan_{작업내용}.md (작업 계획)
    ├── result/                       # result_{작업내용}.md (최종 보고)
    └── issue/                        # issue_{작업내용}.md (QA 미해결 보고)
```

---

## 사용법

### 4개 진입점

| 명령 | 용도 | 에이전트 팀 | QA |
|------|------|------------|----|
| `/dev-beom` | 기능 개발 | planner + architect + coder | qa-manager (Sonnet) |
| `/fix-beom` | 버그 수정 | planner + coder | qa-manager (Sonnet) |
| `/analysis-beom` | 코드/정책 분석 | Explore 에이전트 | — |
| `/persist-beom` | 자율 실행 | planner + architect + coder (질문 없이 끝까지) | qa-manager (Sonnet) |

### 기본 사용 예시

```bash
# 기능 개발 (Jira 이슈 연동)
/dev-beom https://jira.example.com/browse/PROJ-123 로그인 기능 추가

# 버그 수정
/fix-beom https://jira.example.com/browse/PROJ-456 결제 오류 수정

# 코드 분석
/analysis-beom 결제 모듈 아키텍처 분석

# 자율 실행 (질문 없이 끝까지)
/persist-beom https://jira.example.com/browse/PROJ-789 사용자 인증 개선
```

### 유틸리티 스킬

```bash
/commit                  # 변경사항 커밋 (이슈키 자동 파싱)
/pull-request            # GitHub PR 생성 (커밋 히스토리 기반)
/merge-request           # GitLab MR 생성 (커밋 히스토리 기반)
/worktree create feature # Git worktree 생성
/fetch-jenkins           # Jenkins 빌드 상태 조회
/fetch-elk               # ELK/Elasticsearch 로그 조회·분석
/humanizer               # AI 글쓰기 패턴 제거
/web-test                # E2E 웹 테스트 (Playwright)
/version-bump patch      # 플러그인 메타 3개 파일 버전 일괄 갱신 (oh-my-beom 자체 개발용)
/hecto-setup             # HectoProject용 CLAUDE.md 설정
/new-context payment     # 도메인 컨텍스트 생성
```

---

## 개발 파이프라인

### /dev-beom 실행 흐름

```
입력 → Jira 조회 → Git 준비 → 코드 맵 생성
  ↓
TeamCreate (planner + architect + coder) ← 팀에서 qa-manager 분리
  ↓
planner: plan 작성 (docs/plan/plan_{작업내용}.md)
  ↓
architect: 기술 설계 (.dev/design.md)
  ↓
coder: 구현
  ↓
Agent(oh-my-beom:qa-manager) → PASS / FAIL 판정
  ├── PASS → /commit → result 보고
  └── FAIL → QA 루프 (최대 5회)
              ↓
         planner: plan 수정 → coder: 수정 → qa-manager 재호출
              ↓
         5회 초과 → issue 보고서 (docs/issue/) → 사용자에게 보고
```

### QA 루프

qa-manager가 **Critical** 이슈를 발견하면 수정 루프가 시작됩니다:

1. **planner**: plan 파일에 이슈 기록 + 수정 방향 결정
2. **coder**: 수정 방향에 따라 코드 수정
3. **qa-manager**: 재리뷰 (Agent 재호출)
4. PASS가 나올 때까지 반복 (최대 5회)
5. 5회 초과 시 `docs/issue/issue_{작업내용}.md`에 미해결 보고서 생성

### /fix-beom과의 차이

- architect 없이 coder가 직접 영향 범위 확인 + 수정 (경량)
- planner는 "버그 분석 모드"로 동작 (재현 경로 + 원인 추정 + 수정 계획)

### /persist-beom과의 차이

- 사용자에게 질문하지 않고 합리적 가정으로 진행
- QA 5회 초과 시 중단하지 않고 접근 방식을 변경하여 재시도
- 커밋 전 사용자 확인 없이 자동 커밋

---

## 에이전트

| 에이전트 | 역할 | 모델 | 한다 | 하지 않는다 |
|---------|------|------|------|-----------|
| **planner** | plan 관리 | inherit | plan 작성/수정, TODO 관리, QA 이슈 수신 | 코드 구현, 설계 |
| **architect** | 기술 설계 | inherit | 설계, 영향 분석, 비판적 자기검토 | 코드 작성, 비즈니스 결정 |
| **coder** | 코드 구현 | sonnet | 구현/수정, 빌드/테스트 | PR 머지, 보호 브랜치 커밋 |
| **qa-manager** | 코드 리뷰 | sonnet | 리뷰, 스펙 검증, [WEB-TEST-REQUIRED] 판정 | 직접 코드 수정 |
| **web-tester** | E2E 생성+실행 | sonnet | 브라우저 탐색, 테스트 생성/실행/수정 | 프로덕션 코드 수정 |
| **web-test-runner** | E2E 실행만 | sonnet | 기존 테스트 실행, 실패 수정 | 브라우저 탐색, 테스트 생성 |

---

## 문서 산출물

모든 개발/수정 작업은 문서를 남깁니다.

### plan 파일 (`docs/plan/plan_{작업내용}.md`)

작업 시작 전 **필수** 생성. TODO 리스트 포함. 세션이 끝나도 이 파일을 읽고 작업을 이어갈 수 있습니다.

```markdown
# Plan: 로그인 기능 추가

- 상태: IN_PROGRESS
- 브랜치: feat/PROJ-123/login (base: main)
- Jira: PROJ-123
- 생성일: 2026-04-01

## TODO
- [x] 환경 분석 + plan 작성
- [x] 기술 설계
- [ ] 구현
- [ ] QA 리뷰
- [ ] 커밋

## 요구사항
...
```

### result 파일 (`docs/result/result_{작업내용}.md`)

작업 완료 시 최종 보고. 변경 파일, 검증 결과, 미해결 사항을 포함합니다.

### issue 파일 (`docs/issue/issue_{작업내용}.md`)

QA 루프 5회 초과 시 자동 생성. 미해결 이슈, 시도 이력, 권장 조치를 포함합니다.

---

## 안전 장치

### 훅 (8개)

| 훅 | 이벤트 | 역할 |
|----|--------|------|
| `pre-tool-guard` | Bash 실행 전 | 보호 브랜치 커밋 차단 + [WEB-TEST-REQUIRED] 시 웹 테스트 통과 게이트 |
| `pre-commit-build-check` | Bash 실행 전 (git commit) | 커밋 전 빌드/타입체크 통과 확인 (Gradle/TS/Python) — 실패 시 차단 |
| `version-sync-check` | Bash 실행 전 (git commit) | (oh-my-beom 자체 개발 시) package.json / plugin.json / marketplace.json 버전 일치 확인 — 드리프트 시 차단 |
| `doc-sync-check` | Bash 실행 전 (git commit) | (oh-my-beom 자체 개발 시) agents/skills/hooks/rules 구조 변경(추가·삭제) 시 HTML 문서 동반 갱신 강제 |
| `code-quality-gate` | Write/Edit 전 | 시크릿 하드코딩, eval(), SQL 인젝션 감지 + 플러그인 파일 보호 |
| `error-learner` | Bash 실행 후 | 에러 기록 + 반복 감지 → 접근 방식 변경 유도 |
| `web-test-detector` | SendMessage 후 | QA 응답에서 [WEB-TEST-REQUIRED] 마커 감지 |
| `team-recovery-reminder` | TeamCreate 후 | tmux 환경 감지 + `tmux-team-agent` 호출 명령을 additionalContext로 자동 주입 |

### 금지 사항 (CLAUDE.md)

- PR 머지 금지 (PR 생성까지만)
- 보호 브랜치 직접 커밋 금지
- Co-Authored-By 트레일러 금지
- 팀 실행 생략 금지 (규모와 무관하게 강제)
- plan 파일 생략 금지
- QA 루프 생략 금지
- [WEB-TEST-REQUIRED] 무시 금지
- 민감 파일 커밋 금지
- 환각 금지

---

## 설정

### config.json

```json
{
  "protectedBranches": ["main", "master", "develop", "test", "dev"],
  "projectTypes": {
    "kotlin-java": { "detect": ["build.gradle.kts"], "test": "./gradlew test" },
    "nodejs": { "detect": ["package.json"], "test": "npm test | bun test" },
    "python": { "detect": ["pyproject.toml"], "test": "pytest" }
  }
}
```

프로젝트 타입은 빌드 파일로 자동 감지됩니다. lint/test/build 명령이 타입별로 설정되어 있습니다.

---

## References

- 코딩 가이드라인: [LOOPERS](https://www.loopers.im/)
- Playwright Test Agents: [Playwright](https://playwright.dev/docs/test-agents)
