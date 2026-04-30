# Phase 5 — QA 디스패처 (공통)

`/dev-beom`, `/fix-beom`, `/persist-beom`이 Phase 5에서 공통으로 사용하는 QA 호출 절차.

> **변경 (2026-04-29)**: QA 리뷰는 토큰 절감을 위해 **Codex로 분리**한다. qa-manager는 더 이상 팀 멤버가 아니며, `Agent(subagent_type="codex:codex-rescue")`로 호출한다. 페르소나/프로세스는 `agents/qa-manager.md`를 Codex가 직접 Read하여 참조한다.

## 사전 점검 (QA 엔진 결정)

**세션 첫 호출이라면** Codex 가용성을 확인하고, 미준비 시 Claude qa-manager로 fallback한다. 결정 결과는 `.dev/.qa-engine` 마커에 저장하여 세션 동안 재사용한다.

```bash
ENGINE_FILE=".dev/.qa-engine"
NEEDS_RECHECK=0
if [ -f "$ENGINE_FILE" ]; then
  # 마커 형식: "engine@unix-ts" 또는 (구버전) "engine"
  STORED=$(cat "$ENGINE_FILE")
  ENGINE="${STORED%@*}"
  TS="${STORED#*@}"
  # ts가 동일 문자열이면 만료 검사 불가 → 재검사
  if [ "$TS" = "$STORED" ] || [ -z "$TS" ]; then
    NEEDS_RECHECK=1
  else
    AGE=$(( $(date +%s) - TS ))
    # 24시간(86400초) 초과 시 재검사
    [ "$AGE" -gt 86400 ] && NEEDS_RECHECK=1
  fi
else
  NEEDS_RECHECK=1
fi

if [ "$NEEDS_RECHECK" = "1" ]; then
  if command -v codex >/dev/null 2>&1 && codex --version >/dev/null 2>&1; then
    ENGINE="codex"
  else
    ENGINE="claude"
  fi
  echo "${ENGINE}@$(date +%s)" > "$ENGINE_FILE"
fi
```

**`needs-setup` 또는 만료된 경우:**
1. (선택) `Skill("codex:setup")` 호출하여 Codex 인증 가이드
2. 결과 분기:
   - **준비 완료** → `.qa-engine = codex@<ts>`. 사용자에게 "Codex로 QA 진행 (토큰 절감 모드)" 안내
   - **미설치/미인증** → `.qa-engine = claude@<ts>`. 사용자 안내:
     ```
     ⚠️ Codex 미준비 — Claude Sonnet (qa-manager)으로 fallback합니다.
        QA가 메인 토큰을 소모합니다. 토큰 절감을 원하시면:
        `claude plugin install codex` 후 `/codex:setup`으로 인증.
     ```
   - 자율 모드(`/persist-beom`)는 사용자에게 묻지 않고 자동 fallback. 사유는 `.dev/issue/codex-unavailable.md`에 기록.

## QA 호출 디스패처 (4-tier)

`.qa-engine` 값과 멀티플렉서 환경 변수를 조합해 4가지 호출 방식 중 1개를 선택한다.

```
ENGINE=$(cut -d@ -f1 < .dev/.qa-engine)

if [ "$ENGINE" = "claude" ]; then
    → Tier D: Claude qa-manager (Codex 미준비 시 fallback)
elif [ -n "$CMUX_SOCKET" ]; then
    → Tier A: cmux 분할 surface + codex exec   (가시성 ✅ + 토큰 절감 ✅)
elif [ -n "$TMUX" ]; then
    → Tier B: tmux 분할 pane + codex exec       (가시성 ✅ + 토큰 절감 ✅)
else
    → Tier C: Agent(codex:codex-rescue) 백그라운드 (가시성 ❌ + 토큰 절감 ✅)
fi
```

### Tier A — cmux 분할 surface

> 첫 호출 시 surface를 만들고 UUID를 `.dev/.qa-surface-uuid`에 저장. 후속 호출(QA 루프)은 마커 파일을 읽어 같은 surface를 재사용. Phase 7에서 일괄 close.
>
> `drag-surface-to-split`은 attach 직후 일부 상황에서 "Surface not found" 에러가 발생하므로 `new-pane + move-surface` 경로를 우선 사용한다.

```bash
# === 첫 호출만 실행 ===
if [ ! -f .dev/.qa-surface-uuid ]; then
  cmux new-surface --workspace "${CMUX_WORKSPACE_ID}" --type terminal
  sleep 0.3
  QA_SURFACE_UUID=$(cmux --id-format both list-pane-surfaces \
    | tail -1 | awk '{print $2}')
  echo "$QA_SURFACE_UUID" > .dev/.qa-surface-uuid

  if cmux drag-surface-to-split --surface "$QA_SURFACE_UUID" right 2>/dev/null; then
    echo "drag-surface-to-split 성공"
  else
    cmux select-workspace --workspace "${CMUX_WORKSPACE_ID}" 2>/dev/null
    TARGET_PANE=$(cmux new-pane --workspace "${CMUX_WORKSPACE_ID}" --direction right 2>&1 | awk '{print $2}')
    sleep 0.3
    cmux move-surface --surface "$QA_SURFACE_UUID" --pane "$TARGET_PANE" --focus true
    echo "$TARGET_PANE" > .dev/.qa-fallback-pane
  fi
  sleep 0.5
fi
QA_SURFACE_UUID=$(cat .dev/.qa-surface-uuid)

# === 매 호출 실행 ===
# QA 프롬프트 작성
cat > .dev/qa-prompt.md <<'EOF'
페르소나/프로세스: <PROJECT_ROOT>/agents/qa-manager.md를 Read하여 그대로 따른다.
출력 포맷: <PROJECT_ROOT>/references/qa-output-format.md 준수.
리뷰 입력:
- diff: .dev/diff.txt
- plan: docs/plan/plan_{작업내용}.md
- 코드 맵: .dev/codemap.md
첫 줄에 '## 판정: PASS / FAIL (Critical N건)' 출력. 조건 충족 시 [WEB-TEST-REQUIRED] 포함.
EOF

# stdin redirect 패턴 (셸 expansion 회피, 따옴표/뉴라인 안전)
cmux send --surface "$QA_SURFACE_UUID" "codex exec --color never < .dev/qa-prompt.md"$'\n'

# 판정 라인 폴링 (Monitor 도구 권장)
#    until cmux read-screen --surface "$QA_SURFACE_UUID" --scrollback --lines 300 \
#          | grep -E '^## 판정:|tokens used'; do sleep 3; done

# 결과 캡처
qa_result=$(cmux read-screen --surface "$QA_SURFACE_UUID" --scrollback --lines 300)

# surface는 Phase 7에서 일괄 close (루프 중 재사용)
```

> **검증 실패 시**: `cmux read-screen`이 빈 결과를 주거나 codex 출력이 화면에 보이지 않으면:
> 1. `cmux tree`로 surface가 실제로 분할 영역에 위치하는지 확인
> 2. `which codex` 확인 (codex CLI 미설치면 `.qa-engine`을 `claude@<ts>`로 갱신하고 Tier D로 재시도)
> 3. surface tty가 살아있는지 확인. 죽었으면 `.dev/.qa-surface-uuid`와 `.dev/.qa-fallback-pane` 삭제 후 재시도

### Tier B — tmux 분할 pane

```bash
# 첫 호출: pane 생성 후 ID 저장
if [ ! -f .dev/.qa-pane-id ]; then
  QA_PANE=$(tmux split-window -h -P -F "#{pane_id}")
  echo "$QA_PANE" > .dev/.qa-pane-id
fi
QA_PANE=$(cat .dev/.qa-pane-id)

# QA 프롬프트는 Tier A와 동일 (.dev/qa-prompt.md 작성)
tmux send-keys -t "$QA_PANE" "codex exec --color never < .dev/qa-prompt.md" Enter
# 폴링: until tmux capture-pane -t "$QA_PANE" -p | grep -E '## 판정:|tokens used'; do sleep 3; done
qa_result=$(tmux capture-pane -t "$QA_PANE" -p -S -200)
# 정리는 Phase 7에서 일괄
```

### Tier C — Agent 백그라운드 (Codex)

```
Agent(
  subagent_type="codex:codex-rescue",
  description="QA 리뷰 (Codex 백그라운드)",
  prompt="""
페르소나/프로세스: agents/qa-manager.md를 Read하여 따른다.
출력 포맷: references/qa-output-format.md 준수.
리뷰 입력:
- diff: .dev/diff.txt
- plan: docs/plan/plan_{작업내용}.md
- 코드 맵: .dev/codemap.md
첫 줄에 '## 판정: PASS / FAIL (Critical N건)' 형식으로 출력하고, 조건 충족 시 [WEB-TEST-REQUIRED] 마커를 라인 시작(### [WEB-TEST-REQUIRED])으로 포함하세요.
"""
)
```

### Tier D — Claude qa-manager (Codex fallback)

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

    # 4. QA 재리뷰 — 위 디스패처를 동일하게 재사용
    #    Tier A/B 사용 중이면 같은 surface/pane에 재호출하여 가시성 유지
    #    Tier C/D 사용 중이면 Agent 호출. 프롬프트는 "재리뷰" 변형:
    #
    #    "재리뷰 요청. 이전 라운드 Critical 수정 결과를 검증하세요.
    #     diff: .dev/diff.txt (갱신됨)
    #     이전 라운드 Critical: {qa_result의 Critical 항목들}
    #     판정을 첫 줄에 명시하고 미해결 Critical만 보고하세요."
```

> **루프 효율화**: Tier A/B에서는 surface/pane을 닫지 말고 재사용한다. 매 라운드 새로 만들면 cmux split이 누적되어 화면이 좁아진다. Phase 7에서 일괄 정리.

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
