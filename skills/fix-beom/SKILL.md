---
name: fix-beom
description: "버그 수정. 에이전트 팀(planner+coder+qa-manager)을 실행하여 분석→수정→리뷰→커밋까지 수행한다."
argument-hint: "[Jira URL 또는 이슈키] <버그 설명>"
---

버그 수정 오케스트레이터. 에이전트 팀을 **반드시** 실행하여 버그 분석→수정→리뷰→커밋까지 수행한다.

항상 한국어로 응답한다.

## 절대 원칙

1. **오케스트레이터는 직접 코드를 작성하지 않는다.** 모든 산출물은 에이전트(SendMessage)를 통해 생성한다.
2. **팀 실행을 생략하지 않는다.** 버그 규모와 무관하게 반드시 TeamCreate → 에이전트 실행을 수행한다.
3. **plan 파일을 반드시 생성한다.** `docs/plan/plan_{작업내용}.md`가 없으면 작업을 시작하지 않는다.
4. **qa-manager 호출을 생략하지 않는다.** Phase 5는 변경 크기, 파일 수, 줄 수와 무관하게 반드시 실행한다. "1줄 수정이라 직접 확인했다"는 이유로 생략 불가.
5. **TeamCreate 직후 tmux-team-agent를 호출한다.** `Skill("oh-my-beom:tmux-team-agent")`를 생략하지 않는다.
6. **`[WEB-TEST-REQUIRED]` 마커 발견 시 즉시 실행한다.** qa-manager 리뷰에 이 마커가 있으면 질문 없이 서버 기동 → 웹 테스트 → 서버 종료를 수행한다. 절차는 Phase 5의 "웹 테스트 실행" 참조.

## 인자

- `ARGS`: 버그 설명. Jira URL 또는 이슈 키가 포함될 수 있다.

ARGS 없이 호출 시: "수정할 버그를 설명해주세요. 예: `/fix-beom https://jira.example.com/browse/PROJ-456 결제 오류 수정`"

---

# 실행 플로우

## Phase 1: Setup

`/dev-beom`의 Phase 1과 동일:
0. 이전 세션 마커 정리: `Bash(command="rm -f .dev/web-test-required .dev/web-test-passed")`
1. Jira 조회 (URL/키 감지 시)
2. Git 환경 준비 (브랜치명: `fix/{이슈키}/{설명}` 또는 `fix/{설명}`)
3. 프로젝트 정보 수집 + 코드 맵 생성

## Phase 2: Plan (버그 분석 모드)

팀 생성:
```
TeamCreate(agents=["planner", "coder", "qa-manager"])
```

**팀 생성 후 반드시 `Skill("oh-my-beom:tmux-team-agent")` 호출.**

planner에게 **버그 분석 모드**로 plan 작성을 요청한다:

```
SendMessage(to="planner", message="""
다음 버그의 분석 및 수정 plan을 작성해주세요.

버그: {ARGS 전체}
Jira 컨텍스트: {.dev/jira-context.md 내용 또는 "없음"}
코드 맵: {.dev/codemap.md 내용}

[버그 분석 모드]
- 재현 경로 추정
- 원인 추정 (코드 맵 기반)
- 수정 계획 (최소 변경 원칙)
- 검증 방법

docs/plan/plan_{작업내용}.md 파일을 생성하세요.
""")
```

## Phase 3: 설계 (영향 범위 분석)

architect 없이, coder에게 직접 영향 범위 확인을 포함하여 수정을 요청한다.
단, 버그의 영향 범위가 넓다고 판단되면 architect를 추가로 TeamCreate하여 설계를 요청할 수 있다.

## Phase 4: 구현

coder에게 수정을 요청한다:

```
SendMessage(to="coder", message="""
다음 plan 기반으로 버그를 수정해주세요.

plan: {docs/plan/plan_{작업내용}.md 내용}
코드 맵: {.dev/codemap.md 내용}

수정 원칙 (TDD 기반):
- 최소 변경 원칙. 버그 원인만 수정.
- RED: 버그를 재현하는 실패 테스트를 먼저 작성한다.
- GREEN: 테스트가 통과하도록 최소한의 수정을 적용한다.
- 전체 테스트가 통과하는지 확인한다.
""")
```

완료 후 diff 수집: `git diff --cached > .dev/diff.txt`

## Phase 5: QA 리뷰 + 루프

`/dev-beom`의 Phase 5와 동일:
- qa-manager에게 리뷰 요청
- FAIL 시 QA 루프 (최대 5회)
- 5회 초과 시 issue 보고서 생성

### 웹 테스트 실행 (필수 — 조건 충족 시 자동 실행)

qa-manager 리뷰 결과에 **`[WEB-TEST-REQUIRED]`** 마커가 포함되어 있으면, QA PASS 후 커밋 전에 **질문 없이 즉시** 웹 테스트를 실행한다. "진행할까요?", "서버가 필요합니다" 등의 질문은 금지.

**실행 절차:**
1. **서버 기동**: 프로젝트의 dev 서버를 직접 기동한다
   - `package.json`의 `scripts`에서 dev/start 명령 감지 (`dev`, `start`, `serve`)
   - `Bash(command="npm run dev &", run_in_background=true)` 또는 해당 런타임 명령
   - 서버가 ready 될 때까지 대기 (URL 접근 가능 확인, 최대 30초)
   - `playwright.config.ts`에 `webServer` 설정이 있으면 Playwright가 자동 기동하므로 이 단계 생략
2. **URL 자동 결정**: 다음 우선순위로 결정 (사용자 질문 금지)
   - `playwright.config.ts`의 `use.baseURL` 값
   - `package.json`의 dev 스크립트에서 포트 추출 → `http://localhost:{port}`
   - 기본값: `http://localhost:3000`
3. **웹 테스트 실행**:
   ```
   Skill("oh-my-beom:web-test", args="{결정된 URL} {변경 사항 기반 시나리오}")
   ```
4. **서버 정리**: 웹 테스트 완료 후 기동한 서버 프로세스를 종료한다

`[WEB-TEST-REQUIRED]`가 있는데 실행하지 않는 것은 **절대 금지**.

## Phase 6: 커밋

`/dev-beom`의 Phase 6과 동일:
- 사용자 확인 → `/commit` → result 보고 → plan 상태 COMPLETED

---

# Context Slicing

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| coder | plan + 코드 맵 |
| qa-manager | diff(파일 경로) + plan 완료 기준 + 코드 맵 |
