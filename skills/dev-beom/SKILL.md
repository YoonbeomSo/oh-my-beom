---
name: dev-beom
description: "기능 개발. 에이전트 팀(planner+architect+coder+qa-manager)을 실행하여 설계→구현→리뷰→커밋까지 수행한다."
argument-hint: "[Jira URL 또는 이슈키] <작업 설명>"
---

기능 개발 오케스트레이터. 에이전트 팀을 **반드시** 실행하여 plan→설계→구현→리뷰→커밋까지 전체 사이클을 수행한다.

항상 한국어로 응답한다.

## 절대 원칙

CLAUDE.md "금지 사항"을 전부 준수한다. 추가로:
- **오케스트레이터는 직접 코드를 작성하지 않는다.** 모든 산출물은 에이전트(SendMessage)를 통해 생성한다.

## 인자

- `ARGS`: 작업 설명. Jira URL(`*/browse/ISSUE-KEY`) 또는 이슈 키(`PROJECT-123`)가 포함될 수 있다.

ARGS 없이 호출 시: "개발할 기능을 설명해주세요. 예: `/dev-beom https://jira.example.com/browse/PROJ-123 로그인 기능 추가`"

---

# 실행 플로우

아래 Phase를 순서대로 실행한다. Phase를 건너뛰지 않는다.

## Phase 1: Setup

### 1-0. 이전 세션 마커 정리
```
Bash(command="rm -f .dev/web-test-required .dev/web-test-passed .dev/diff.txt .dev/design.md .dev/codemap.md .dev/jira-context.md .dev/cleanup-report.md .dev/*.pid")
```

### 1-1. Jira 조회 (선택)
ARGS에서 Jira URL 또는 이슈 키 패턴(`[A-Z]+-[0-9]+`)을 감지하면:
- `Skill("oh-my-beom:fetch-jira-issue", args="{URL 또는 이슈키}")` 호출
- 결과를 `.dev/jira-context.md`에 저장

### 1-2. Git 환경 준비
1. `git status`로 현재 상태 확인
2. 베이스 브랜치 감지: `git branch --list main master develop` → 첫 번째 존재하는 브랜치 선택. 없으면 사용자에게 질문
3. 베이스 브랜치 최신화: `git pull origin {base}`
4. 작업 브랜치 생성: `feat/{설명}` (이슈 키는 커밋 메시지에서 관리)
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

**팀 생성 후 환경을 감지하여 적절한 복구 스킬을 호출한다:**
```bash
if [ -n "$CMUX_SOCKET" ]; then echo "cmux"; elif [ -n "$TMUX" ]; then echo "tmux"; else echo "none"; fi
```
- `cmux` → `Skill("oh-my-beom:cmux-team-agent")`
- `tmux` → `Skill("oh-my-beom:tmux-team-agent")`
- `none` → 스킬 호출 생략 (에이전트는 mailbox 모드로 동작)

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

### Phase 4.5: 빌드/테스트 자동 교정

coder 구현 완료 후, QA 리뷰 전에 빌드/테스트를 실행한다. **실패 시 coder에게 자동 수정을 요청한다. 최대 3회.**

1. 프로젝트 타입별 테스트 명령 실행 (`config/config.json` projectTypes 참조)
2. 성공 → Phase 5로 진행
3. 실패 시:
   - 에러 출력을 캡처
   - `SendMessage(to="coder", message="빌드/테스트 실패. 에러: {에러 출력 앞 50줄}. 수정해주세요.")`
   - 수정 후 재실행
4. 동일 에러 3회 반복 → 사용자에게 보고하고 지시 요청

### coder 완료 후 정리:
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

## Phase 7: 마무리 점검

커밋 완료 후 다음을 수행한다:

1. **임시 파일 정리**: `rm -f .dev/diff.txt .dev/design.md .dev/codemap.md .dev/jira-context.md`
2. **에러 로그 분석**: `.dev/error-log.md`에 반복 에러(3회+)가 있으면 사용자에게 안내:
   "반복 에러 패턴이 감지되었습니다. rules 승격을 고려하세요: {패턴 요약}"
3. **중복 코드 경고**: 변경 파일이 10개 이상이면, 동일 로직 복사 여부를 간단히 확인하고 경고

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
