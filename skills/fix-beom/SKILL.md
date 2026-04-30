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

## Phase 0: 도구 준비

`/dev-beom` Phase 0과 동일. `ToolSearch(query="select:TeamCreate,SendMessage,Agent,TaskCreate,TaskUpdate")`.

## Phase 1: Setup

`/dev-beom` Phase 1과 동일:
- 이전 세션 마커 정리(stale UUID/pane 포함)
- Jira 조회 (URL/키 감지 시)
- Git 환경 준비 (브랜치명: `fix/{설명}`, 이슈 키는 커밋 메시지에서 관리)
- 프로젝트 정보 수집 + 코드 맵 생성

## Phase 2: Plan (버그 분석 모드)

팀 생성:
```
TeamCreate(agents=["planner", "coder"])
```

### 환경 감지 + 복구 스킬 호출 (필수)

`references/team-recovery.md` 절차 그대로 수행. TeamCreate 직후 즉시.

### planner 호출 (버그 분석 모드)

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

`/dev-beom` Phase 4.5와 동일. 실패 시 coder에게 자동 수정 요청, 최대 3회.

완료 후 diff 수집: `git diff --cached > .dev/diff.txt`

## Phase 5: QA 리뷰 + 루프

`references/phase5-qa-dispatcher.md` 절차 그대로 사용. 4-tier 디스패처 + 루프 + `### [WEB-TEST-REQUIRED]` 자동 실행.

## Phase 6: 커밋

`/dev-beom` Phase 6과 동일:
- 사용자 확인 → `/commit` → result 보고 → plan 상태 COMPLETED

## Phase 7: 마무리 점검

`/dev-beom` Phase 7과 동일:
- 임시 파일 정리(설계 산출물)
- QA/Team surface·pane 일괄 close
- error-log.md 회전(100KB 초과 시)
- 중복 코드 경고(10개 파일 이상 변경 시)

---

# Context Slicing

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| coder | plan + 코드 맵 |
| Codex (QA) | agents/qa-manager.md + references/qa-output-format.md + diff(경로) + plan 완료 기준 + 코드 맵 |
