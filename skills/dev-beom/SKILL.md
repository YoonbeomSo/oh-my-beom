---
name: dev-beom
description: "기능 개발. 에이전트 팀(planner+architect+coder)을 실행하여 설계→구현→리뷰(Codex QA)→커밋까지 수행한다."
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
TeamCreate(agents=["planner", "architect", "coder"])
```

### 🛑 필수 1단계 — 환경 감지 + 복구 스킬 호출 (생략 절대 금지)

TeamCreate 직후 **다음 SendMessage보다 먼저** 이 단계를 수행한다. 사용자에게 묻거나 "필요하면 나중에"라는 식의 지연은 금지. PostToolUse 훅(`team-recovery-reminder`)이 자동으로 환경을 알려주지만, 그 컨텍스트 무시도 금지.

1. 환경 감지 후 **사용자에게 announcement 출력**:
   ```bash
   if [ -n "$CMUX_SOCKET" ]; then ENV=cmux
   elif [ -n "$TMUX" ]; then ENV=tmux
   else ENV=none
   fi
   echo "🖥️ 환경: $ENV"
   ```
2. 환경별 스킬 호출 (즉시):

   | 환경 | 호출 | 생략 시 |
   |------|------|---------|
   | `cmux` | `Skill("oh-my-beom:cmux-team-agent")` | 화면 분할 실패. surface가 탭으로 쌓임 |
   | `tmux` | `Skill("oh-my-beom:tmux-team-agent")` | pane이 빈 셸로 남음, 에이전트 미시작 |
   | `none` | 호출 생략 (mailbox 모드) | — |

> **반복 강조**: 사용자가 "왜 화면 분할 안 했어?" 라고 묻는 시점에는 이미 늦었다. TeamCreate → **즉시** 이 단계 → 그 다음에 SendMessage.

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

> **변경 (2026-04-29):** QA 리뷰는 토큰 절감을 위해 **Codex로 분리**한다. qa-manager는 더 이상 팀 멤버가 아니며, `Agent(subagent_type="codex:codex-rescue")`로 호출한다. 페르소나/프로세스는 `agents/qa-manager.md`를 Codex가 직접 Read하여 참조한다.

### Phase 5 사전 점검 (QA 엔진 결정)

**세션 첫 호출이라면** Codex 가용성을 확인하고, 미준비 시 Claude qa-manager로 fallback한다. 결정 결과는 `.dev/.qa-engine` 마커에 저장하여 세션 동안 재사용한다.

```bash
if [ -f .dev/.qa-engine ]; then
  cat .dev/.qa-engine        # 'codex' 또는 'claude' 출력
else
  echo "needs-setup"
fi
```

**`needs-setup`인 경우:**
1. `Skill("codex:setup")` 호출
2. 결과 분기:
   - **준비 완료** → `echo codex > .dev/.qa-engine`. 사용자에게 "Codex로 QA 진행 (토큰 절감 모드)" 안내
   - **미설치/미인증** → `echo claude > .dev/.qa-engine`. 사용자에게 다음 안내 출력 후 진행:
     ```
     ⚠️ Codex 미준비 — Claude Sonnet (qa-manager)으로 fallback합니다.
        QA가 메인 토큰을 소모합니다. 토큰 절감을 원하시면:
        `claude plugin install codex` 후 `/codex:setup`으로 인증.
     ```

### QA 호출 디스패처 (4-tier)

`.dev/.qa-engine` 값과 멀티플렉서 환경 변수를 조합해 4가지 호출 방식 중 1개를 선택한다.

```
QA_ENGINE=$(cat .dev/.qa-engine)

if [ "$QA_ENGINE" = "claude" ]; then
    → Tier D: Claude qa-manager (Codex 미준비 시 fallback)
elif [ -n "$CMUX_SOCKET" ]; then
    → Tier A: cmux 분할 surface + codex exec   (가시성 ✅ + 토큰 절감 ✅)
elif [ -n "$TMUX" ]; then
    → Tier B: tmux 분할 pane + codex exec       (가시성 ✅ + 토큰 절감 ✅)
else
    → Tier C: Agent(codex:codex-rescue) 백그라운드 (가시성 ❌ + 토큰 절감 ✅)
fi
```

#### Tier A — cmux 분할 surface

> 첫 호출 시 surface를 만들고 UUID를 `.dev/.qa-surface-uuid`에 저장. 후속 호출(QA 루프)은 마커 파일을 읽어 같은 surface를 재사용. Phase 7에서 일괄 close.

```bash
# === 첫 호출만 실행 ===
if [ ! -f .dev/.qa-surface-uuid ]; then
  # 1. 새 surface 생성
  cmux new-surface --type terminal
  # --id-format both로 UUID 매핑 (drag/close에서 UUID 필수)
  QA_SURFACE_UUID=$(cmux --id-format both list-pane-surfaces | tail -1 | awk '{print $2}')
  echo "$QA_SURFACE_UUID" > .dev/.qa-surface-uuid

  # 2. 분할 (UUID 필수 — short ref는 'Surface not found' 에러 발생)
  cmux drag-surface-to-split --surface "$QA_SURFACE_UUID" right
  sleep 0.5
fi
QA_SURFACE_UUID=$(cat .dev/.qa-surface-uuid)

# === 매 호출 실행 ===
# 3. QA 프롬프트 작성
cat > .dev/qa-prompt.md <<'EOF'
페르소나/프로세스: /Users/.../oh-my-beom/agents/qa-manager.md를 Read하여 그대로 따른다.
리뷰 입력:
- diff: .dev/diff.txt
- plan: docs/plan/plan_{작업내용}.md
- 코드 맵: .dev/codemap.md
첫 줄에 '## 판정: PASS / FAIL (Critical N건)' 출력. 조건 충족 시 [WEB-TEST-REQUIRED] 포함.
EOF

# 4. codex exec 실행 (cmux send는 \n을 Enter로 해석)
cmux send --surface "$QA_SURFACE_UUID" "codex exec --color never \"\$(cat .dev/qa-prompt.md)\"\n"

# 5. 판정 라인 폴링 (Monitor 도구 권장)
#    until cmux read-screen --surface "$QA_SURFACE_UUID" --scrollback --lines 200 | grep -E '## 판정:|tokens used'; do sleep 3; done

# 6. 결과 캡처
qa_result=$(cmux read-screen --surface "$QA_SURFACE_UUID" --scrollback --lines 200)

# 7. surface는 Phase 7에서 일괄 close (루프 중 재사용)
```

#### Tier B — tmux 분할 pane

```bash
# 첫 호출: pane 생성 후 ID 저장
if [ ! -f .dev/.qa-pane-id ]; then
  QA_PANE=$(tmux split-window -h -P -F "#{pane_id}")
  echo "$QA_PANE" > .dev/.qa-pane-id
fi
QA_PANE=$(cat .dev/.qa-pane-id)

# QA 프롬프트는 Tier A와 동일 (.dev/qa-prompt.md 작성)
tmux send-keys -t "$QA_PANE" "codex exec --color never \"$(cat .dev/qa-prompt.md)\"" Enter
# 폴링: until tmux capture-pane -t "$QA_PANE" -p | grep -E '## 판정:|tokens used'; do sleep 3; done
qa_result=$(tmux capture-pane -t "$QA_PANE" -p -S -200)
# 정리는 Phase 7에서 일괄
```

#### Tier C — Agent 백그라운드 (Codex)

```
Agent(
  subagent_type="codex:codex-rescue",
  description="QA 리뷰 (Codex 백그라운드)",
  prompt="""
페르소나/프로세스: agents/qa-manager.md를 Read하여 따른다.
리뷰 입력:
- diff: .dev/diff.txt
- plan: docs/plan/plan_{작업내용}.md
- 코드 맵: .dev/codemap.md
첫 줄에 '## 판정: PASS / FAIL (Critical N건)' 형식으로 출력하고, 조건 충족 시 [WEB-TEST-REQUIRED] 마커를 포함하세요.
"""
)
```

#### Tier D — Claude qa-manager (Codex fallback)

```
Agent(
  subagent_type="oh-my-beom:qa-manager",
  description="QA 리뷰 (Claude fallback)",
  prompt="""
코드 리뷰를 수행해주세요. (페르소나/프로세스는 본인 시스템 프롬프트를 따름)

diff 파일: .dev/diff.txt (Read로 확인)
plan 완료 기준: docs/plan/plan_{작업내용}.md (TODO 섹션)
코드 맵: .dev/codemap.md

판정을 PASS 또는 FAIL(Critical N건) 형식으로 명시해주세요.
"""
)
```

> qa-manager는 팀 멤버가 아니라 Agent 일회성 호출이므로 메인 세션 컨텍스트에 페르소나가 영구 진입하지 않는다.

각 Tier 응답에서 `## 판정:` 라인을 파싱하여 `qa_result`로 사용한다.

### QA 루프

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

    # 4. QA 재리뷰 — 위 "QA 호출 디스패처"를 동일하게 재사용
    #    Tier A/B 사용 중이면 같은 surface/pane에 재호출하여 가시성 유지
    #    Tier C/D 사용 중이면 Agent 호출. 프롬프트는 "재리뷰" 변형으로 변경:
    #
    #    "재리뷰 요청. 이전 라운드 Critical 수정 결과를 검증하세요.
    #     diff: .dev/diff.txt (갱신됨)
    #     이전 라운드 Critical: {qa_result의 Critical 항목들}
    #     판정을 첫 줄에 명시하고 미해결 Critical만 보고하세요."
```

> **루프 효율화**: Tier A/B에서는 surface/pane을 닫지 말고 재사용한다. 매 라운드 새로 만들면 cmux split이 누적되어 화면이 좁아진다. Phase 7 마무리 점검에서 일괄 정리.

### 웹 테스트 실행 (필수 — 조건 충족 시 자동 실행)

Codex QA 리뷰 결과에 **`[WEB-TEST-REQUIRED]`** 마커가 포함되어 있으면, QA PASS 후 커밋 전에 **질문 없이 즉시** 웹 테스트를 실행한다. "진행할까요?", "서버가 필요합니다" 등의 질문은 금지.

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

Codex QA 판정이 **PASS**이면:

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

1. **임시 파일 정리**: `rm -f .dev/diff.txt .dev/design.md .dev/codemap.md .dev/jira-context.md .dev/qa-prompt.md`
2. **QA surface/pane 정리** (Tier A/B 사용 시):
   - cmux: `cmux close-surface --surface "$(cat .dev/.qa-surface-uuid)"` 후 `rm -f .dev/.qa-surface-uuid`
   - tmux: `tmux kill-pane -t "$(cat .dev/.qa-pane-id)"` 후 `rm -f .dev/.qa-pane-id`
   - `.dev/.qa-engine`은 다음 세션에서 재사용 가능하므로 **남긴다** (Codex 가용성은 안정적이라 재검증 비용 절감)
3. **에러 로그 분석**: `.dev/error-log.md`에 반복 에러(3회+)가 있으면 사용자에게 안내:
   "반복 에러 패턴이 감지되었습니다. rules 승격을 고려하세요: {패턴 요약}"
4. **중복 코드 경고**: 변경 파일이 10개 이상이면, 동일 로직 복사 여부를 간단히 확인하고 경고

---

# Context Slicing

에이전트별 필요한 정보만 전달하여 context window를 효율적으로 사용한다:

| 에이전트 | 전달 정보 |
|---------|----------|
| planner | ARGS + 코드 맵 + Jira 컨텍스트 |
| architect | plan + 코드 맵 + 프로젝트 컨벤션 |
| coder | 설계서 + 코드 맵 |
| Codex (QA) | agents/qa-manager.md(페르소나) + diff(파일 경로) + plan 완료 기준 + 코드 맵 |

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
