# CLAUDE.md

oh-my-beom 플러그인의 최상위 지침.

한국어로 응답하세요. 코드와 커밋 메시지도 한국어를 기본으로 합니다.

---

## 작업 범위

- **PR 생성까지만.** `gh pr merge` 등 머지 명령은 절대 실행하지 마세요. 사용자가 직접 머지를 요청하더라도 거절하고, PR 링크를 제공하여 직접 머지하도록 안내하세요.
- 보호 브랜치(`main`, `master`, `develop`, `test`. `dev`)에서 직접 커밋하지 마세요. 작업 브랜치를 먼저 생성하세요.
- 커밋 메시지에 `Co-Authored-By` 트레일러를 추가하지 마세요.

## 행동 원칙 요약

상세 규칙은 `rules/` 디렉토리를 참조하세요.

1. **코딩 전에 생각하라** - 추측하지 마라. 읽기 우선. 환각 금지.
2. **단순함 우선** - 최소한의 코드. 오버엔지니어링 금지.
3. **외과적 변경** - 건드려야 할 것만 건드려라.
4. **목표 중심 실행** - 성공 기준을 정의하고 검증하라.
5. **점진적 실행** - 작은 단위로 나눠서 검증하라.
6. **실패 대응** - 근본 원인부터 파악하라.
7. **피드백 반영** - 지적받은 실수를 반복하지 마라.

## 에이전트 역할 경계

| 역할 | 할 수 있는 것 | 할 수 없는 것 |
|------|-------------|-------------|
| Explorer | 파일 읽기, 구조 파악, 패턴 수집 | 파일 수정, 코드 작성 |
| Planner | 계획 수립, 질문, 선택지 제시 | 코드 구현 |
| Coder | 코드 작성, 수정, 테스트 | PR 머지, 보호 브랜치 커밋 |
| Critic | 리뷰, 평가, 판정 | 직접 코드 수정 |

## 참조 파일

| 파일 | 내용 |
|------|------|
| `rules/behavior.md` | 행동 원칙 상세 |
| `rules/git-workflow.md` | Git 브랜치/커밋/PR 규칙 |
| `rules/workspace-structure.md` | 플러그인 구조 설명 |
| `config/config.json` | 이슈 키, 민감 파일, 프로젝트 타입, 타임아웃, teamAgent 설정 |

## Team Agent 설정

| 설정 | 위치 | 설명 |
|------|------|------|
| `teamAgent.enabled` | `config/config.json` | Team Agent 사용 여부 (기본: true) |
| `teamAgent.mode` | `config/config.json` | 표시 모드: tmux / background |
| `teamAgent.fallbackToTask` | `config/config.json` | Agent 실패 시 Task로 폴백 |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `~/.claude/settings.json` (env) | 실험 기능 활성화 필수 |
| `TeammateIdle` hook | `hooks/idle-checker` | Teammate 유휴 시 미완료 작업 자동 할당 |
| `TaskCompleted` hook | `hooks/task-verifier` | Task 완료 시 품질 게이트 검증 |
