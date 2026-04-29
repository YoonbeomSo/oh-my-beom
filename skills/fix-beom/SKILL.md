---
name: fix-beom
description: "버그 수정. 에이전트 팀(planner+coder)을 실행하여 분석→수정→리뷰(Codex QA)→커밋까지 수행한다."
argument-hint: "[Jira URL 또는 이슈키] <버그 설명>"
---

버그 수정 오케스트레이터. 에이전트 팀을 **반드시** 실행하여 버그 분석→수정→리뷰→커밋까지 수행한다.

항상 한국어로 응답한다.

## 절대 원칙

CLAUDE.md "금지 사항"을 전부 준수한다. 추가로:
- **오케스트레이터는 직접 코드를 작성하지 않는다.** 모든 산출물은 에이전트(SendMessage)를 통해 생성한다.

## 인자

- `ARGS`: 버그 설명. Jira URL 또는 이슈 키가 포함될 수 있다.

ARGS 없이 호출 시: "수정할 버그를 설명해주세요. 예: `/fix-beom https://jira.example.com/browse/PROJ-456 결제 오류 수정`"

---

# 실행 플로우

## Phase 1: Setup

`/dev-beom`의 Phase 1과 동일:
0. 이전 세션 마커 정리: `Bash(command="rm -f .dev/web-test-required .dev/web-test-passed .dev/diff.txt .dev/design.md .dev/codemap.md .dev/jira-context.md .dev/cleanup-report.md .dev/*.pid")`
1. Jira 조회 (URL/키 감지 시)
2. Git 환경 준비 (브랜치명: `fix/{설명}`, 이슈 키는 커밋 메시지에서 관리)
3. 프로젝트 정보 수집 + 코드 맵 생성

## Phase 2: Plan (버그 분석 모드)

팀 생성:
```
TeamCreate(agents=["planner", "coder"])
```

**팀 생성 후 환경을 감지하여 적절한 복구 스킬을 호출한다:**
```bash
if [ -n "$CMUX_SOCKET" ]; then echo "cmux"; elif [ -n "$TMUX" ]; then echo "tmux"; else echo "none"; fi
```
- `cmux` → `Skill("oh-my-beom:cmux-team-agent")`
- `tmux` → `Skill("oh-my-beom:tmux-team-agent")`
- `none` → 스킬 호출 생략 (에이전트는 mailbox 모드로 동작)

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

### Phase 4.5: 빌드/테스트 자동 교정

coder 수정 완료 후, QA 리뷰 전에 빌드/테스트를 실행한다. **실패 시 coder에게 자동 수정을 요청한다. 최대 3회.**

1. 프로젝트 타입별 테스트 명령 실행 (`config/config.json` projectTypes 참조)
2. 성공 → Phase 5로 진행
3. 실패 시:
   - 에러 출력을 캡처
   - `SendMessage(to="coder", message="빌드/테스트 실패. 에러: {에러 출력 앞 50줄}. 수정해주세요.")`
   - 수정 후 재실행
4. 동일 에러 3회 반복 → 사용자에게 보고하고 지시 요청

완료 후 diff 수집: `git diff --cached > .dev/diff.txt`

## Phase 5: QA 리뷰 + 루프

> **변경 (2026-04-29):** QA 리뷰는 토큰 절감을 위해 **Codex로 분리**한다. qa-manager는 더 이상 팀 멤버가 아니며, `Agent(subagent_type="codex:codex-rescue")`로 호출한다. 페르소나/프로세스는 `agents/qa-manager.md`를 Codex가 직접 Read하여 참조한다.

### Phase 5 사전 점검 (QA 엔진 결정)

`/dev-beom` Phase 5의 "사전 점검 (QA 엔진 결정)" 절차를 동일하게 수행한다. `.dev/.qa-engine` 마커가 없으면 `Skill("codex:setup")` 호출 후 결과에 따라 `codex` 또는 `claude`로 결정한다.

이후 호출 분기는 `/dev-beom`의 4-tier 디스패처를 그대로 사용:
- Tier A: cmux 분할 surface + `codex exec` (가시성 ✅)
- Tier B: tmux 분할 pane + `codex exec` (가시성 ✅)
- Tier C: `Agent(subagent_type="codex:codex-rescue")` (가시성 ❌)
- Tier D: `Agent(subagent_type="oh-my-beom:qa-manager")` (Codex fallback)

FAIL 시 QA 루프 (최대 5회) — 매 라운드마다 같은 Tier로 재호출 (Tier A/B는 surface/pane 재사용). 5회 초과 시 issue 보고서 생성.

### 웹 테스트 실행

`[WEB-TEST-REQUIRED]` 마커 감지 시 dev-beom Phase 5 "웹 테스트 실행" 절차와 동일하게 즉시 실행한다. 질문 없이 서버 기동 → 웹 테스트 → 서버 종료.

## Phase 6: 커밋

`/dev-beom`의 Phase 6과 동일:
- 사용자 확인 → `/commit` → result 보고 → plan 상태 COMPLETED

## Phase 7: 마무리 점검

커밋 완료 후 다음을 수행한다:

1. **임시 파일 정리**: `rm -f .dev/diff.txt .dev/design.md .dev/codemap.md .dev/jira-context.md`
2. **에러 로그 분석**: `.dev/error-log.md`에 반복 에러(3회+)가 있으면 사용자에게 안내:
   "반복 에러 패턴이 감지되었습니다. rules 승격을 고려하세요: {패턴 요약}"
3. **중복 코드 경고**: 변경 파일이 10개 이상이면, 동일 로직 복사 여부를 간단히 확인하고 경고

---

# Context Slicing

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| coder | plan + 코드 맵 |
| Codex (QA) | agents/qa-manager.md(페르소나) + diff(파일 경로) + plan 완료 기준 + 코드 맵 |
