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
`/dev-beom` Phase 1과 동일 (이전 세션 마커 정리 포함). 단, 베이스 브랜치 선택 시 질문하지 않고 `main` → `master` → `develop` 순으로 자동 선택.

## Phase 2: Plan
`/dev-beom` Phase 2와 동일. planner 질문은 자동 가정으로 처리.

**TeamCreate 직후 환경을 감지하여 적절한 복구 스킬을 호출한다:**
```bash
if [ -n "$CMUX_SOCKET" ]; then echo "cmux"; elif [ -n "$TMUX" ]; then echo "tmux"; else echo "none"; fi
```
- `cmux` → `Skill("oh-my-beom:cmux-team-agent")`
- `tmux` → `Skill("oh-my-beom:tmux-team-agent")`
- `none` → 스킬 호출 생략 (에이전트는 mailbox 모드로 동작)

## Phase 3: 설계
`/dev-beom` Phase 3과 동일. architect 질문은 안전한 선택지로 자동 결정.

## Phase 4: 구현
`/dev-beom` Phase 4와 동일.

## Phase 5: QA 리뷰 + 루프

> **변경 (2026-04-29):** QA 리뷰는 토큰 절감을 위해 **Codex로 분리**한다. qa-manager는 더 이상 팀 멤버가 아니며, `Agent(subagent_type="codex:codex-rescue")`로 호출한다. 페르소나/프로세스는 `agents/qa-manager.md`를 Codex가 직접 Read하여 참조한다.

### Phase 5 사전 점검 (QA 엔진 결정)

`/dev-beom` Phase 5의 "사전 점검 (QA 엔진 결정)" 절차를 동일하게 수행한다. 단, **자율 실행 모드**이므로 미준비 시 사용자에게 묻지 않고 자동으로 fallback한다:

1. `Skill("codex:setup")` 1회 시도
2. 결과에 따라 `.dev/.qa-engine` 마커 작성:
   - 준비 완료 → `codex`
   - 미설치/미인증 → `claude` (Claude qa-manager로 자동 fallback)
3. fallback 시 `.dev/issue/codex-unavailable.md`에 사유 기록 (사용자 보고용)

이후 QA 호출은 `/dev-beom`의 4-tier 디스패처(cmux split / tmux split / Agent codex / Claude qa-manager)를 그대로 사용. 자율 모드라 surface/pane 정리는 Phase 7에서 일괄 수행. `/dev-beom` Phase 5와 동일하나 루프 확장 (위 참조).

**웹 테스트 필수 시:** Codex QA 리뷰에 `[WEB-TEST-REQUIRED]` 마커가 있으면, QA PASS 후 즉시 서버를 기동하고 웹 테스트를 실행한다. dev-beom의 "웹 테스트 실행" 절차와 동일 (서버 기동 → URL 자동 결정 → 웹 테스트 → 서버 종료).

## Phase 6: 커밋
사용자 확인 없이 자동 커밋:
1. `Skill("oh-my-beom:commit")` 호출
2. planner에게 result 보고 작성 요청
3. plan 상태 COMPLETED 갱신
4. 사용자에게 완료 보고 출력

## Phase 7: 마무리 점검

커밋 완료 후 다음을 수행한다:

1. **임시 파일 정리**: `rm -f .dev/diff.txt .dev/design.md .dev/codemap.md .dev/jira-context.md`
2. **에러 로그 분석**: `.dev/error-log.md`에 반복 에러(3회+)가 있으면 `.dev/cleanup-report.md`에 기록:
   "반복 에러 패턴 감지. rules 승격 권장: {패턴 요약}"
3. **중복 코드 경고**: 변경 파일이 10개 이상이면, 동일 로직 복사 여부를 간단히 확인하고 `.dev/cleanup-report.md`에 기록

---

# Context Slicing

`/dev-beom`과 동일.

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| architect | plan + 코드 맵 + 프로젝트 컨벤션 |
| coder | 설계서 + 코드 맵 |
| Codex (QA) | agents/qa-manager.md(페르소나) + diff(파일 경로) + plan 완료 기준 + 코드 맵 |
