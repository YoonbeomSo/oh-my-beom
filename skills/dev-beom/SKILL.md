---
name: dev-beom
description: "기능 개발. 에이전트 팀(planner+architect+coder+qa-manager)을 실행하여 설계→구현→리뷰→커밋까지 수행한다."
argument-hint: "[Jira URL 또는 이슈키] <작업 설명>"
---

기능 개발 오케스트레이터. 에이전트 팀을 **반드시** 실행하여 plan→설계→구현→리뷰→커밋까지 전체 사이클을 수행한다.

항상 한국어로 응답한다.

## 절대 원칙

1. **오케스트레이터는 직접 코드를 작성하지 않는다.** 모든 산출물은 에이전트(SendMessage)를 통해 생성한다.
2. **팀 실행을 생략하지 않는다.** 작업 규모와 무관하게 반드시 TeamCreate → 에이전트 실행을 수행한다.
3. **plan 파일을 반드시 생성한다.** `docs/plan/plan_{작업내용}.md`가 없으면 작업을 시작하지 않는다.
4. **qa-manager 호출을 생략하지 않는다.** Phase 5는 변경 크기, 파일 수, 줄 수와 무관하게 반드시 실행한다. 오케스트레이터가 직접 리뷰하여 대체하는 것은 금지한다.
5. **TeamCreate 직후 tmux-team-agent를 호출한다.** `Skill("oh-my-beom:tmux-team-agent")`를 생략하지 않는다.

## 인자

- `ARGS`: 작업 설명. Jira URL(`*/browse/ISSUE-KEY`) 또는 이슈 키(`PROJECT-123`)가 포함될 수 있다.

ARGS 없이 호출 시: "개발할 기능을 설명해주세요. 예: `/dev-beom https://jira.example.com/browse/PROJ-123 로그인 기능 추가`"

---

# 실행 플로우

아래 Phase를 순서대로 실행한다. Phase를 건너뛰지 않는다.

## Phase 1: Setup

### 1-1. Jira 조회 (선택)
ARGS에서 Jira URL 또는 이슈 키 패턴(`[A-Z]+-[0-9]+`)을 감지하면:
- `Skill("oh-my-beom:fetch-jira-issue", args="{URL 또는 이슈키}")` 호출
- 결과를 `.dev/jira-context.md`에 저장

### 1-2. Git 환경 준비
1. `git status`로 현재 상태 확인
2. 베이스 브랜치 감지: `git branch --list main master develop` → 첫 번째 존재하는 브랜치 선택. 없으면 사용자에게 질문
3. 베이스 브랜치 최신화: `git pull origin {base}`
4. 작업 브랜치 생성: 이슈 키가 있으면 `feat/{이슈키}/{설명}`, 없으면 `feat/{설명}`
5. `.gitignore`에 `.dev/` 추가 (없으면)

### 1-3. 프로젝트 정보 수집
1. `config/config.json`의 `projectTypes`로 프로젝트 타입 감지
2. Glob으로 디렉토리 구조 파악
3. 코드 맵 생성: ARGS 키워드 기반으로 관련 파일 탐색 → `.dev/codemap.md`에 저장 (최대 25개)

## Phase 2: Plan

팀을 생성하고 planner에게 plan 작성을 요청한다.

```
TeamCreate(agents=["planner", "architect", "coder", "qa-manager"])
```

**팀 생성 후 반드시 `Skill("oh-my-beom:tmux-team-agent")` 호출하여 빈 pane을 복구한다.**

```
SendMessage(to="planner", message="""
다음 작업의 plan을 작성해주세요.

작업: {ARGS 전체}
Jira 컨텍스트: {.dev/jira-context.md 내용 또는 "없음"}
코드 맵: {.dev/codemap.md 내용}
프로젝트 타입: {감지된 타입}

docs/plan/plan_{작업내용}.md 파일을 생성하세요.
TODO 리스트를 포함하고, 요구사항을 정리해주세요.
""")
```

planner 결과를 확인한다. 질문이 있으면 사용자에게 전달 후 planner에게 답변을 전달한다.

## Phase 3: 설계

architect에게 기술 설계를 요청한다.

```
SendMessage(to="architect", message="""
다음 plan 기반으로 기술 설계를 작성해주세요.

plan: {docs/plan/plan_{작업내용}.md 내용}
코드 맵: {.dev/codemap.md 내용}
프로젝트 컨벤션: {CLAUDE.md 또는 conventions.md 내용}

설계서를 출력해주세요.
""")
```

architect 결과를 `.dev/design.md`에 저장한다.
plan 파일의 "설계" 섹션에 요약을 기록한다.
planner에게 TODO 갱신을 요청한다.

## Phase 4: 구현

coder에게 구현을 요청한다.

```
SendMessage(to="coder", message="""
다음 설계서를 기반으로 Red-Green-Refactor TDD 사이클로 구현해주세요.

설계서: {.dev/design.md 내용}
코드 맵: {.dev/codemap.md 내용}

TDD 규칙 (/tdd 스킬):
1. RED: 수용 기준을 검증하는 실패 테스트 작성 → 실패 확인
2. GREEN: 테스트를 통과시키는 최소 코드 작성 → 통과 확인
3. REFACTOR: 중복 제거, 이름 개선 → GREEN 유지 확인

[N/M] 형식으로 진행 상황을 보고해주세요. 각 단계에 RED→GREEN 상태를 포함해주세요.
""")
```

coder 완료 후:
1. `git add`로 변경 파일 스테이징
2. `git diff --cached > .dev/diff.txt` (500줄 이상이면 `--stat`으로 대체)
3. plan 파일의 "변경 사항" 섹션에 변경 파일 목록 기록

## Phase 5: QA 리뷰 + 루프

qa-manager에게 리뷰를 요청한다.

```
SendMessage(to="qa-manager", message="""
코드 리뷰를 수행해주세요.

diff 파일: .dev/diff.txt (Read로 확인)
plan 완료 기준: {docs/plan/plan_{작업내용}.md의 TODO 섹션}
코드 맵: {.dev/codemap.md 내용}

판정을 PASS 또는 FAIL(Critical N건) 형식으로 명시해주세요.
""")
```

### QA 루프

qa-manager 판정이 **FAIL**이면 루프를 시작한다. **최대 5회.**

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

    # 4. qa-manager 재리뷰
    SendMessage(to="qa-manager", message="재리뷰해주세요. diff: .dev/diff.txt")
```

### 웹 테스트 실행 (조건부)

qa-manager 리뷰 결과에 **"웹 테스트 권고"** 섹션이 포함되어 있으면, QA PASS 후 커밋 전에 반드시 웹 테스트를 실행한다:

```
Skill("oh-my-beom:web-test", args="{대상 URL} {시나리오 설명}")
```

웹 테스트 권고가 있는데 실행하지 않는 것은 금지한다. URL이 불분명하면 사용자에게 질문한다.

### 5회 초과 시

```
SendMessage(to="planner", message="""
QA 루프 5회를 초과했습니다. 미해결 이슈 보고서를 작성해주세요.
미해결 Critical: {남은 이슈들}
QA 이력: {Round 1~5 요약}
docs/issue/issue_{작업내용}.md에 작성해주세요.
""")
```

사용자에게 이슈 보고서 경로를 안내하고 해결 방법을 요청한다.

## Phase 6: 커밋

qa-manager 판정이 **PASS**이면:

1. 사용자에게 커밋 확인: "QA 리뷰를 통과했습니다. 커밋하시겠습니까?"
2. 확인 후 `Skill("oh-my-beom:commit")` 호출
3. planner에게 result 보고 작성 요청:

```
SendMessage(to="planner", message="""
작업이 완료되었습니다. 결과 보고서를 작성해주세요.
브랜치: {branch}
변경 파일: {git diff --stat}
QA 이력: {Round 수, Critical/Warning 수}
docs/result/result_{작업내용}.md에 작성해주세요.
""")
```

4. plan 파일의 상태를 `COMPLETED`로 갱신

---

# Context Slicing

에이전트별 필요한 정보만 전달하여 context window를 효율적으로 사용한다:

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| architect | plan + 코드 맵 + 프로젝트 컨벤션 |
| coder | 설계서 + 코드 맵 |
| qa-manager | diff(파일 경로) + plan 완료 기준 + 코드 맵 |

## Diff 수집

diff가 메인 컨텍스트에 진입하지 않도록 파일로 리다이렉트한다:
1. `git diff --cached > .dev/diff.txt`
2. 500줄 이상이면 `git diff --cached --stat`으로 대체
3. 에이전트에게는 파일 경로만 전달

## 코드 맵

`.dev/codemap.md`에 관련 파일 경로와 역할을 기록한다:
- 생성: setup에서 ARGS 키워드 기반 탐색
- 갱신: 에이전트 출력의 "탐색 추가 항목"을 append (최대 25개)
- 전달: 모든 에이전트 호출 시 포함
