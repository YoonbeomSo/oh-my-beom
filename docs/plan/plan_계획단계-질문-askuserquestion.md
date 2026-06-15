# Plan: 계획(Plan) 단계 사용자 질문을 AskUserQuestion 도구로 통일

- 상태: IN_PROGRESS
- 브랜치: feat/fetch-elk-test (base: main) — coder가 작업 브랜치(`feat/plan-question-askuserquestion` 등) 신규 생성 권장
- Jira: 없음
- 생성일: 2026-06-09

## TODO
- [x] 환경 분석 + plan 작성
- [x] 판단 항목 결정 전환 (a=추가 / b=Plan 단계 한정 / c=minor 2.21.0)
- [ ] `skills/dev-beom/SKILL.md:94` planner 질문 relay 문구를 AskUserQuestion 명시로 수정
- [ ] `skills/fix-beom/SKILL.md` Phase 2(L67) ~ Phase 3(L69) 사이에 planner 결과 확인 + AskUserQuestion relay 문구 추가
- [ ] `agents/planner.md:46` 질문 목록 작성 항목에 "2~4개 구체적 선택지(권장안 우선) 구조화" 보강
- [ ] `agents/planner.md:102~104` plan 작성 프로세스의 "질문 목록" 항목도 동일 보강(선택, 일관성)
- [ ] persist-beom 미변경 확인 (질문 금지 설계 유지)
- [ ] doc-sync-check 훅 비트리거 확인 (M 변경만 → 통과)
- [ ] QA 리뷰
- [ ] 버전 범프 **minor 2.20.0 → 2.21.0** (version-bump 스킬, QA 통과 후 오케스트레이터 수행)
- [ ] 커밋

## 요구사항

계획(Plan) 단계에서 오케스트레이터가 사용자에게 질문할 때 **AskUserQuestion 도구**를 사용하도록 스킬/에이전트 문구를 명시한다. 현재는 "사용자에게 전달"로만 적혀 있어 평문 응답과 AskUserQuestion 도구 사용이 혼용되어 일관성이 없다.

### 적용 범위 (확정)
- **포함:** dev-beom Phase 2, fix-beom Phase 2(버그 분석 모드 planner 호출 직후), planner.md 질문 목록 작성 지침.
- **제외:** persist-beom — "질문 없이 자율 진행"이 설계 의도이므로 변경하지 않는다.
- **이번 작업은 Plan 단계 질문에 한정.** 다른 질문 지점(예: 베이스 브랜치 감지 실패, Phase 6 커밋 확인)은 본 작업 범위 밖 — 결정 사항 (b) 참조.

## 원인 분석

- 계획 단계 질문 relay 경로에 사용할 UI 도구(AskUserQuestion)가 문서에 명시되어 있지 않다.
- dev-beom은 `질문이 있으면 사용자에게 전달`(L94)로만 표현되어, 오케스트레이터가 평문/도구 중 무엇을 쓸지 비결정적.
- fix-beom에는 planner 결과/질문 relay 문구 자체가 없어(Phase 2 → Phase 3 직행) 질문이 발생해도 처리 경로가 불명확.
- planner.md는 `질문 목록 작성`만 지시할 뿐 구조(선택지/권장안)를 규정하지 않아, AskUserQuestion으로 변환하기 어려운 자유서술 질문이 나올 수 있다.

## 수정 계획 (최소 변경 — 문구만)

### 1. `skills/dev-beom/SKILL.md:94`

현재:
```
planner 결과를 확인한다. 질문이 있으면 사용자에게 전달 후 planner에게 답변을 전달한다.
```
수정 방향:
```
planner 결과를 확인한다. planner가 질문 목록을 반환하면 **AskUserQuestion 도구**로 사용자에게 제시한다(각 질문은 planner가 구성한 2~4개 선택지를 옵션으로, 권장안을 첫 옵션으로). 사용자 답변을 planner에게 전달한다. 질문이 없으면 다음 Phase로 진행한다.
```

### 2. `skills/fix-beom/SKILL.md` — Phase 2(L67) ~ Phase 3(L69) 사이

현재 L67(planner 호출 블록 종료) 직후 바로 L69 `## Phase 3`로 이어짐 → relay 문구 없음.
수정 방향: planner 호출 코드 블록(L66 `""")`) 뒤, `## Phase 3` 앞에 한 줄 추가:
```
planner 결과를 확인한다. planner가 질문 목록을 반환하면 **AskUserQuestion 도구**로 사용자에게 제시하고(권장안을 첫 옵션으로), 답변을 planner에게 전달한 뒤 진행한다. 질문이 없으면 다음 Phase로 진행한다.
```

### 3. `agents/planner.md:46`

현재(역할 경계):
```
- 요구사항이 모호하면 질문 목록 작성
```
수정 방향:
```
- 요구사항이 모호하면 질문 목록 작성. 각 질문은 가능하면 2~4개 구체적 선택지(권장안을 첫 번째로)로 구조화하여, 오케스트레이터가 AskUserQuestion 도구로 제시하기 쉽게 한다. 자유 입력이 필요한 질문은 그 점을 명시한다.
```

### 4. `agents/planner.md:102~104` (plan 작성 프로세스) — 선택, 일관성 보강

현재:
```
2. 요구사항이 모호하면 **질문 목록**을 작성하여 반환한다.
```
수정 방향(L46과 동일 취지):
```
2. 요구사항이 모호하면 **질문 목록**을 작성하여 반환한다. 각 질문은 2~4개 선택지(권장안 우선)로 구조화한다.
```

> 방식 메모: AskUserQuestion은 스킬 프론트매터 allowed-tools가 아니라 오케스트레이터(메인 세션)가 사용하는 도구다. dev-beom/fix-beom은 allowed-tools를 쓰지 않는 스킬이므로 **본문 지시만 추가**하면 된다(프론트매터 수정 불필요). 선례: `skills/fetch-jenkins/SKILL.md:113`, `skills/worktree/SKILL.md:117`.

## 설계
{architect 산출물 — 오케스트레이터가 기록. 본 작업은 문구 변경이라 architect 없이 coder 직접 수정도 가능하나, dev-beom 플로우상 architect 호출 시 "외과적 변경, 라인만 교체" 가이드만 확인}

## 변경 사항
{coder 산출물 — 오케스트레이터가 기록}

## 검증 방법

1. **문구 반영 확인:** dev-beom:94, fix-beom Phase2~3 사이, planner.md:46(및 102) 에 "AskUserQuestion" 명시 문자열이 포함되는지 grep.
   - `grep -n "AskUserQuestion" skills/dev-beom/SKILL.md skills/fix-beom/SKILL.md agents/planner.md`
2. **persist-beom 미변경 확인:** `git diff --name-only`에 `skills/persist-beom/SKILL.md`가 포함되지 않을 것. 질문 금지 문구(L15, L31~33) 그대로 유지.
3. **doc-sync-check 비트리거 확인:** 본 변경은 기존 파일 **수정(M)** 만 발생. 훅은 `--diff-filter=AD`(추가/삭제)에만 발동하므로 통과한다(hooks/doc-sync-check:74 확인). → `docs/show/harness-architecture.html` 동반 갱신 **불필요**.
4. **외과적 변경 확인:** 위 4개 위치 외 라인/로직 변경 없음. `git diff`로 무관한 변경 부재 확인.

## 결정 사항 (사용자 확정 — 2026-06-09)

### (a) fix-beom 적용 범위 → **추가 확정**
fix-beom Phase 2~3 사이에 planner 결과 확인 + AskUserQuestion relay 문구를 **신규 추가**한다(현재 relay 문구가 아예 없으므로 일관성 확보). → 수정 계획 2번 그대로 진행.

### (b) 적용 범위 → **Plan 단계 질문만 한정 확정**
이번 작업은 **Plan 단계 질문만** 한정한다. 베이스 브랜치 감지 실패(dev-beom:55) 등 다른 질문 지점은 이번 범위 밖(미변경).

### (c) 버전 범프 → **minor 2.20.0 → 2.21.0 확정**
동작 보정(사용자 노출 동작 변경). version-bump 스킬로 package.json / plugin.json / marketplace.json 3개 동기화. coder는 버전 범프하지 않으며, QA 통과 후 오케스트레이터가 수행.

## QA 이력
{QA 단계에서 기록}
