---
name: persist-beom
description: "자율 실행. 에이전트 팀을 실행하여 질문 없이 끝까지 설계→구현→리뷰→커밋을 수행한다."
argument-hint: "[Jira URL 또는 이슈키] <작업 설명>"
---

자율 실행 오케스트레이터. `/dev-beom`과 동일한 팀/플로우를 사용하되, **사용자에게 질문하지 않고 끝까지 자율 진행**한다.

항상 한국어로 응답한다.

## 절대 원칙

1. **오케스트레이터는 직접 코드를 작성하지 않는다.** 모든 산출물은 에이전트(SendMessage)를 통해 생성한다.
2. **팀 실행을 생략하지 않는다.** 작업 규모와 무관하게 반드시 TeamCreate → 에이전트 실행을 수행한다.
3. **plan 파일을 반드시 생성한다.**
4. **사용자에게 질문하지 않는다.** 모호한 사항은 합리적으로 가정하고 진행한다. 가정은 plan 파일에 기록한다.
5. **멈추지 않는다.** 에러가 발생해도 대안을 찾아 계속 진행한다.

## 인자

- `ARGS`: 작업 설명. Jira URL 또는 이슈 키가 포함될 수 있다.

---

# 실행 플로우

`/dev-beom`과 동일한 Phase 1~6을 수행하되, 다음이 다르다:

## /dev-beom과의 차이점

### 1. 질문 없이 진행
- planner가 질문을 생성하면 → 합리적인 가정을 세우고 진행. 가정을 plan에 기록.
- architect가 "확인이 필요한 사항"을 생성하면 → 기술적으로 안전한 선택지를 자동 결정.
- 커밋 전 사용자 확인 → 생략. 자동 커밋.

### 2. QA 루프 확장
- QA 루프 5회 초과 시:
  1. `docs/issue/issue_{작업내용}.md` 생성 (동일)
  2. **중단하지 않는다.** planner에게 접근 방식 변경을 요청하고 재시도.
  3. 접근 방식 변경 후에도 5회 실패 시 → 사용자에게 보고하고 중단.

### 3. 에러 자동 복구
- 빌드/테스트 실패 → coder에게 자동 수정 요청 (최대 3회)
- git 충돌 → 자동 해결 시도. 불가능하면 사용자에게 보고.
- 동일 에러 3회 반복 → 접근 방식을 변경하여 재시도.

### 4. 진행 상황 보고
각 Phase 완료 시 간단한 진행 보고를 출력한다:
```
[persist-beom] Phase 2/6 완료: plan 작성 완료
[persist-beom] Phase 4/6 완료: 구현 완료 (파일 5개 변경)
[persist-beom] QA 루프 Round 2/5: Critical 1건 수정 중
```

---

# Phase 상세

## Phase 1: Setup
`/dev-beom` Phase 1과 동일. 단, 베이스 브랜치 선택 시 질문하지 않고 `main` → `master` → `develop` 순으로 자동 선택.

## Phase 2: Plan
`/dev-beom` Phase 2와 동일. planner 질문은 자동 가정으로 처리.

## Phase 3: 설계
`/dev-beom` Phase 3과 동일. architect 질문은 안전한 선택지로 자동 결정.

## Phase 4: 구현
`/dev-beom` Phase 4와 동일.

## Phase 5: QA 리뷰 + 루프
`/dev-beom` Phase 5와 동일하나 루프 확장 (위 참조).

## Phase 6: 커밋
사용자 확인 없이 자동 커밋:
1. `Skill("oh-my-beom:commit")` 호출
2. planner에게 result 보고 작성 요청
3. plan 상태 COMPLETED 갱신
4. 사용자에게 완료 보고 출력

---

# Context Slicing

`/dev-beom`과 동일.

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| architect | plan + 코드 맵 + 프로젝트 컨벤션 |
| coder | 설계서 + 코드 맵 |
| qa-manager | diff(파일 경로) + plan 완료 기준 + 코드 맵 |
