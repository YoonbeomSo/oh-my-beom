# 플러그인 구조

oh-my-beom 플러그인의 디렉토리 구조와 각 역할을 정의한다.

## 디렉토리 구조

```
oh-my-beom/                  <- 플러그인 루트
├── .claude-plugin/
│   └── plugin.json             <- 플러그인 메타데이터
├── CLAUDE.md                   <- 플러그인 레벨 지침
├── hooks/
│   ├── hooks.json              <- 훅 등록 (SessionStart, UserPromptSubmit, PreToolUse, TaskCompleted, TeammateIdle, Stop)
│   ├── session-start           <- 세션 시작 시 활성 계획 감지
│   ├── prompt-router           <- 사용자 프롬프트 키워드 매칭 -> 스킬 라우팅
│   ├── pre-tool-guard          <- 보호 브랜치 커밋 차단
│   ├── task-verifier           <- TaskCompleted 시 계획 완료 기준 자동 검증
│   ├── idle-checker            <- TeammateIdle 시 미완료 항목 자동 할당
│   └── stop-report             <- Stop 시 /dev 결과 보고서 자동 생성
├── rules/
│   ├── behavior.md             <- 행동 원칙 (코딩 전 사고, 단순함, 외과적 변경 등)
│   ├── git-workflow.md         <- Git 브랜치/커밋/PR 규칙
│   └── workspace-structure.md  <- 이 파일. 플러그인 구조 설명
├── config/
│   └── config.json             <- 이슈 키, 민감 파일, 프로젝트 타입, 타임아웃 등
├── skills/
│   ├── beom/SKILL.md           <- 개발 오케스트레이터 (팀 추천 → 에이전트 작업 → 커밋)
│   ├── research/SKILL.md       <- 조사 파이프라인
│   ├── lens/                   <- 비즈니스 정책 분석
│   ├── persist/SKILL.md        <- 끝까지 실행 모드
│   ├── commit/                 <- 커밋 자동화
│   ├── pull-request/           <- PR 생성
│   ├── worktree/               <- Git worktree 관리
│   └── ...                     <- 기타 스킬
├── agents/                     <- 팀 에이전트 정의 (product-owner, architect, coder, qa-manager, security-auditor)
│   └── ...                     <- /dev 파이프라인 팀 멤버
└── docs/                       <- 프로젝트별 생성됨 (git 추적 대상)
    ├── plan/                   <- 계획 파일 ({이슈키}-plan.md)
    └── show/                   <- 시각화 HTML (자동 생성)
```

## 핵심 규칙

- `rules/`는 모든 세션에 자동 적용되는 규칙이다. 스킬별 규칙은 각 `SKILL.md`에 정의한다.
- `config/config.json`은 스킬과 훅에서 공통으로 참조하는 설정값이다.
- `hooks/`는 세션 시작, 프롬프트 제출, 도구 사용 전, 태스크 완료 시, 팀메이트 유휴 시, 응답 종료 시에 자동 실행된다.
- 새 스킬을 추가할 때는 `skills/{name}/SKILL.md` 형식을 따른다.

## 참조 관계

| 구성 요소 | 참조하는 곳 |
|-----------|------------|
| `config/config.json` | hooks, skills (commit, worktree 등) |
| `rules/behavior.md` | 모든 세션 (자동 적용) |
| `rules/git-workflow.md` | Git 관련 작업 시 |
| `hooks/hooks.json` | Claude Code 플러그인 시스템 |
| `docs/plan/*.md` | /dev 스킬, /todo-verifier 스킬, /plan-visualizer 스킬, 훅 스크립트 |
| `docs/show/*.html` | /plan-visualizer 스킬이 자동 생성 |
