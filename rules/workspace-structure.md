# 플러그인 구조

oh-syb-claude 플러그인의 디렉토리 구조와 각 역할을 정의한다.

## 디렉토리 구조

```
oh-syb-claude/                  <- 플러그인 루트
├── .claude-plugin/
│   └── plugin.json             <- 플러그인 메타데이터
├── CLAUDE.md                   <- 플러그인 레벨 지침
├── hooks/
│   ├── hooks.json              <- 훅 등록 (SessionStart, UserPromptSubmit, PreToolUse)
│   ├── session-start           <- 세션 시작 시 가이드라인 주입
│   ├── prompt-router           <- 사용자 프롬프트 키워드 매칭 -> 스킬 라우팅
│   └── pre-tool-guard          <- 보호 브랜치 커밋 차단
├── rules/
│   ├── behavior.md             <- 행동 원칙 (코딩 전 사고, 단순함, 외과적 변경 등)
│   ├── git-workflow.md         <- Git 브랜치/커밋/PR 규칙
│   └── workspace-structure.md  <- 이 파일. 플러그인 구조 설명
├── config/
│   └── config.json             <- 이슈 키, 민감 파일, 프로젝트 타입, 타임아웃 등
├── skills/
│   ├── plan/SKILL.md           <- 4-Mode 계획 수립
│   ├── research/SKILL.md       <- 조사 파이프라인
│   ├── persist/SKILL.md        <- 끝까지 실행 모드
│   ├── dev/                    <- 개발 사이클 (PCC 포팅)
│   ├── lens/                   <- 비즈니스 정책 분석
│   ├── commit/                 <- 커밋 자동화
│   ├── pull-request/           <- PR 생성
│   ├── worktree/               <- Git worktree 관리
│   └── ...                     <- 기타 스킬
├── guidelines/
│   └── CLAUDE.md               <- 행동 가이드라인 원본
└── agents/                     <- 에이전트 정의
```

## 핵심 규칙

- `rules/`는 모든 세션에 자동 적용되는 규칙이다. 스킬별 규칙은 각 `SKILL.md`에 정의한다.
- `config/config.json`은 스킬과 훅에서 공통으로 참조하는 설정값이다.
- `hooks/`는 세션 시작, 프롬프트 제출, 도구 사용 전에 자동 실행된다.
- 새 스킬을 추가할 때는 `skills/{name}/SKILL.md` 형식을 따른다.

## 참조 관계

| 구성 요소 | 참조하는 곳 |
|-----------|------------|
| `config/config.json` | hooks, skills (commit, worktree 등) |
| `rules/behavior.md` | 모든 세션 (자동 적용) |
| `rules/git-workflow.md` | Git 관련 작업 시 |
| `hooks/hooks.json` | Claude Code 플러그인 시스템 |
