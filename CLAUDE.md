# CLAUDE.md

oh-my-beom 플러그인의 최상위 지침.

한국어로 응답하세요. 코드와 커밋 메시지도 한국어를 기본으로 합니다.

---

## 금지 사항 (절대)

- **PR 머지 금지.** `gh pr merge` 실행 금지. PR 링크를 제공하여 사용자가 직접 머지
- **PR/MR 자동 생성 금지.** 커밋/push 후 PR을 자동 생성하지 않는다. "PR 만들까요?" 질문도 금지. 사용자가 `/pull-request`로 명시적 요청 시에만 생성
- **보호 브랜치 직접 커밋 금지.** main, master, develop, test, dev에서 직접 커밋 금지. 작업 브랜치를 먼저 생성
- **Co-Authored-By 금지.** 커밋 메시지에 Co-Authored-By 트레일러 추가 금지
- **팀 실행 생략 금지.** /dev-beom, /fix-beom, /persist-beom은 반드시 에이전트 팀을 생성하고 실행. "간단하다", "규모가 작다"는 이유로 생략 불가
- **plan 파일 생략 금지.** 모든 개발/수정 작업은 `docs/plan/plan_{작업내용}.md` 생성 후 시작
- **QA 호출 생략 금지.** 모든 구현/수정 후 반드시 qa-manager를 spawn하여 리뷰. "변경이 작다", "직접 확인했다", "1개 파일이다" 등의 이유로 생략 불가. 오케스트레이터가 자체 리뷰로 대체하는 것도 금지
- **tmux-team-agent 호출 생략 금지.** TeamCreate 직후 반드시 `Skill("oh-my-beom:tmux-team-agent")` 호출. 에이전트가 정상 작동하는 것처럼 보여도 생략 불가
- **QA 루프 생략 금지.** qa-manager가 Critical 발견 시 반드시 수정 루프 진입
- **민감 파일 커밋 금지.** .env*, *.key, *.pem, credentials*, *secret*
- **환각 금지.** 존재하지 않는 API, 패키지, 파일 경로를 지어내지 않기

## 워크플로우

4개의 진입점 스킬로 작업을 시작한다.

| 명령 | 용도 | 팀 |
|------|------|----|
| `/dev-beom` | 기능 개발 | planner + architect + coder + qa-manager |
| `/fix-beom` | 버그 수정 | planner + coder + qa-manager |
| `/analysis-beom` | 코드/정책 분석 | Explore 에이전트 |
| `/persist-beom` | 자율 실행 (끝까지) | 전체 팀 (질문 없이) |

## 에이전트 역할 경계

| 역할 | 한다 | 하지 않는다 |
|------|------|-----------|
| planner | plan 작성/수정, TODO 관리, QA 이슈 수신→수정 방향 결정 | 코드 구현, 설계 |
| architect | 기술 설계, 영향 분석, 비판적 자기검토 | 코드 작성, 비즈니스 결정 |
| coder | 코드 구현/수정, 빌드/테스트 실행 | PR 머지, 보호 브랜치 커밋 |
| qa-manager | 코드 리뷰, 스펙 검증, plan 완료 기준 대조 | 직접 코드 수정 |

## 행동 원칙

속도보다 **신중함**에 무게를 둔다. 상세는 `rules/behavior.md` 참조.

| 원칙 | 핵심 |
|------|------|
| 코딩 전에 생각하라 | 추측 금지, 읽기 우선, 환각 금지 |
| 단순함 우선 | 최소 코드, 불필요한 추상화 금지 |
| 외과적 변경 | 요청과 무관한 라인 수정 금지 |
| 실패 대응 | 근본 원인 분석, 같은 시도 반복 금지 |

## 참조 파일

| 파일 | 내용 |
|------|------|
| `rules/behavior.md` | 행동 원칙 상세 |
| `rules/git-workflow.md` | Git 브랜치/커밋/PR 규칙 |
| `config/config.json` | 이슈 키, 민감 파일, 프로젝트 타입, 타임아웃 설정 |
