---
name: persist-beom
description: "자율 실행. 에이전트 팀(planner+architect+coder)을 실행하여 질문 없이 끝까지 설계→구현→리뷰(Codex QA)→커밋을 수행한다."
argument-hint: "[Jira URL 또는 이슈키] <작업 설명>"
---

자율 실행 오케스트레이터. `/dev-beom`과 동일한 팀/플로우를 사용하되, **사용자에게 질문하지 않고 끝까지 자율 진행**한다.

항상 한국어로 응답한다.

## 절대 원칙

CLAUDE.md "금지 사항"을 전부 준수한다. 추가로:
- **오케스트레이터는 직접 코드를 작성하지 않는다.** 모든 산출물은 에이전트(SendMessage)를 통해 생성한다.
- **사용자에게 질문하지 않는다.** 모호한 사항은 합리적으로 가정하고 진행한다. 가정은 plan 파일에 기록한다.
- **멈추지 않는다.** 에러가 발생해도 대안을 찾아 계속 진행한다.

## 인자

- `ARGS`: 작업 설명. Jira URL 또는 이슈 키가 포함될 수 있다.

---

# 실행 플로우

`/dev-beom`의 Phase 0~7을 그대로 수행한다. 차이점만 아래에 명시.

## /dev-beom과의 차이점

### 1. 질문 없이 진행
- planner가 질문을 생성하면 → 합리적인 가정을 세우고 진행. 가정을 plan에 기록.
- architect가 "확인이 필요한 사항"을 생성하면 → 기술적으로 안전한 선택지를 자동 결정.
- 커밋 전 사용자 확인 → 생략. 자동 커밋.
- 베이스 브랜치 선택 시 질문하지 않고 `main` → `master` → `develop` 순으로 자동 선택.

### 2. QA 루프 확장
- QA 루프 5회 초과 시:
  1. `docs/issue/issue_{작업내용}.md` 생성 (동일)
  2. **중단하지 않는다.** planner에게 접근 방식 변경을 요청하고 재시도.
  3. 접근 방식 변경 후에도 5회 실패 시 → 사용자에게 보고하고 중단.

### 3. QA 엔진 fallback 자동 처리
- `.dev/.qa-engine` 사전 점검에서 Codex 미준비 시 사용자에게 묻지 않고 자동으로 `claude@<ts>` fallback. 사유는 `.dev/issue/codex-unavailable.md`에 기록 (사용자 보고용).

### 4. 에러 자동 복구
- 빌드/테스트 실패 → coder에게 자동 수정 요청 (최대 3회)
- git 충돌 → 자동 해결 시도. 불가능하면 사용자에게 보고.
- 동일 에러 3회 반복 → 접근 방식을 변경하여 재시도.

### 5. 진행 상황 보고

각 Phase 완료 시 간단한 진행 보고를 출력한다:

```
[persist-beom] Phase 2/6 완료: plan 작성 완료
[persist-beom] Phase 4/6 완료: 구현 완료 (파일 5개 변경)
[persist-beom] QA 루프 Round 2/5: Critical 1건 수정 중
```

## 환경 감지 + 복구 스킬 호출

자율 모드라도 생략 금지. `references/team-recovery.md` 절차를 그대로 수행한다.

## QA 디스패처

`references/phase5-qa-dispatcher.md`의 4-tier 디스패처를 동일하게 사용. surface/pane 정리는 Phase 7에서 일괄. `### [WEB-TEST-REQUIRED]` 감지 시 `references/web-test-trigger.md` 즉시 실행.

---

# Context Slicing

`/dev-beom`과 동일.

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| architect | plan + 코드 맵 + 프로젝트 컨벤션 |
| coder | 설계서 + 코드 맵 |
| Codex (QA) | agents/qa-manager.md + references/qa-output-format.md + diff(경로) + plan 완료 기준 + 코드 맵 |
