# Phase 5 — QA 리뷰 (공통)

`/dev-beom`, `/fix-beom`, `/persist-beom`이 Phase 5에서 공통으로 사용하는 QA 호출 절차.

> **변경 (2026-05-27)**: Codex QA 분리는 제거되었다. QA 리뷰는 `Agent(subagent_type="oh-my-beom:qa-manager")`로 단일화한다. qa-manager는 Sonnet 모델을 사용하며 페르소나/프로세스는 `agents/qa-manager.md`를 그대로 따른다.

## QA 호출

```
Agent(
  subagent_type="oh-my-beom:qa-manager",
  description="QA 리뷰 (코드 + plan 완료 기준 검증)",
  prompt="""
코드 리뷰를 수행해주세요. 페르소나/프로세스는 본인 시스템 프롬프트(agents/qa-manager.md)를 따릅니다.

리뷰 입력:
- diff 파일: .dev/diff.txt (Read로 확인)
- plan 완료 기준: docs/plan/plan_{작업내용}.md (TODO 섹션)
- 코드 맵: .dev/codemap.md

출력 포맷: references/qa-output-format.md 준수.
첫 줄에 '## 판정: PASS / FAIL (Critical N건)' 형식으로 명시하고,
웹 UI 변경이 있어 E2E 검증이 필요하면 라인 시작에 '### [WEB-TEST-REQUIRED]' 마커를 포함하세요.
"""
)
```

> Agent 일회성 호출이므로 qa-manager 페르소나가 메인 세션 컨텍스트에 영구 진입하지 않는다.

각 호출 응답에서 `## 판정:` 라인을 파싱하여 `qa_result`로 사용한다.

## QA 루프

판정이 **FAIL**이면 루프를 시작한다. **최대 5회.**

```
loop_count = 0
while qa_result == FAIL and loop_count < 5:
    loop_count++

    # 1. planner에게 plan 수정 요청
    SendMessage(to="planner", message="""
    QA 리뷰 Round {loop_count}에서 Critical {N}건 발견.
    이슈 내용: {qa_result의 Critical 항목들}
    plan 파일을 수정하고 coder에게 전달할 수정 방향을 작성해주세요.
    """)

    # 2. coder에게 수정 요청
    SendMessage(to="coder", message="""
    QA 리뷰에서 다음 Critical 이슈가 발견되었습니다. 수정해주세요.
    이슈: {qa_result의 Critical 항목들}
    수정 방향: {planner의 수정 방향}
    """)

    # 3. diff 갱신
    git diff --cached > .dev/diff.txt

    # 4. QA 재리뷰 — 위 Agent 호출을 동일 프롬프트(재리뷰 변형)로 다시 호출
    #
    #    "재리뷰 요청. 이전 라운드 Critical 수정 결과를 검증하세요.
    #     diff: .dev/diff.txt (갱신됨)
    #     이전 라운드 Critical: {qa_result의 Critical 항목들}
    #     판정을 첫 줄에 명시하고 미해결 Critical만 보고하세요."
```

## 웹 테스트 실행

QA 결과에 `### [WEB-TEST-REQUIRED]` 라인이 있으면 `references/web-test-trigger.md` 절차를 즉시 실행. 질문 금지.

## 5회 초과 시

```
SendMessage(to="planner", message="""
QA 루프 5회를 초과했습니다. 미해결 이슈 보고서를 작성해주세요.
미해결 Critical: {남은 이슈들}
QA 이력: {Round 1~5 요약}
docs/issue/issue_{작업내용}.md에 작성해주세요.
""")
```

사용자에게 이슈 보고서 경로를 안내. 자율 모드(`/persist-beom`)는 접근 방식을 변경하여 한 번 더 시도하고, 그래도 실패하면 사용자에게 보고하고 중단.
