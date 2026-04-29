---
name: cmux-team-agent
description: Use after spawning team agents with Agent tool when running inside cmux. TeamCreate spawns agents in a separate claude-swarm tmux server; this skill creates a cmux surface that attaches to that swarm tmux so the agents become visible as a split. Use proactively whenever TeamCreate is used in cmux environment.
---

# cmux Team Agent Visualization

## Overview

TeamCreate는 **자체 tmux 서버**(`/tmp/tmux-501/claude-swarm-{PID}`)를 띄워 그 안에서 에이전트들을 실행한다. cmux는 이 별도 tmux 서버를 직접 보지 못하므로, 사용자에게 보이는 cmux 화면에는 에이전트가 나타나지 않는다.

이 스킬은:
1. claude-swarm tmux 서버를 감지
2. cmux 안에 새 surface를 만들고 그 안에서 swarm tmux에 `tmux attach`
3. 새 pane으로 분리하여 화면 분할 효과를 얻음

> **이 스킬은 cmux 환경 전용이다.** tmux 환경에서는 `tmux-team-agent` 스킬을 사용한다.

## When to Use

- TeamCreate로 팀 생성 직후 (PostToolUse 훅 `team-recovery-reminder`가 자동 안내)
- 사용자가 "cmux에 안 뜬다", "분할 화면이 비어있다" 등 보고 시
- `$CMUX_SOCKET`가 set이고 `$TMUX`가 unset인 환경에서

## 문제 원인 (실제 동작 모델)

| 가정 (잘못된 이전 모델) | 실제 동작 |
|------------------------|-----------|
| 각 에이전트마다 cmux surface가 따로 생긴다 | ❌ — TeamCreate는 하나의 swarm tmux 서버 안에 모두 띄움 |
| `cmux drag-surface-to-split --surface {agentSurfaceUUID}` 호출 가능 | ❌ — 그런 surface는 존재하지 않음. "Surface not found" 발생 |
| config의 `tmuxPaneId`가 cmux surface ID | ❌ — `tmuxPaneId`는 swarm tmux 안의 pane ID(`%0`, `%1` 등) |

따라서 cmux 분할은 **swarm tmux를 attach한 cmux surface를 만드는 방식**으로만 가능하다.

## 복구 절차

### Step 0: 대기

```bash
sleep 2   # swarm tmux 서버가 띄워질 시간 확보
```

### Step 1: claude-swarm tmux 서버 찾기 (LIVE PID 필터링)

socket 이름은 `claude-swarm-{PID}` 패턴이지만, 세션 종료 후에도 stale socket이 남아 있을 수 있다. **반드시 `ps -p`로 LIVE 여부를 확인**한 뒤 가장 최근 LIVE socket을 선택한다:

```bash
SWARM_SOCK=""
for sock in $(ls -t /tmp/tmux-${UID:-501}/claude-swarm-* 2>/dev/null); do
  pid=$(basename "$sock" | sed 's/claude-swarm-//')
  if ps -p "$pid" >/dev/null 2>&1; then
    SWARM_SOCK="$sock"
    break
  fi
done
[ -z "$SWARM_SOCK" ] && { echo "LIVE claude-swarm tmux 서버를 찾지 못했습니다."; exit 1; }
echo "swarm socket: $SWARM_SOCK"
```

세션 이름 확인 (보통 `claude-swarm`이지만 변할 수 있음):

```bash
SWARM_SESSION=$(tmux -S "$SWARM_SOCK" list-sessions -F "#{session_name}" 2>/dev/null | head -1)
echo "swarm session: $SWARM_SESSION"
```

각 pane 정보도 한 번 확인 (멤버 수 = pane 수):

```bash
tmux -S "$SWARM_SOCK" list-panes -a -F "#{pane_id} #{pane_current_command} tty=#{pane_tty}"
```

### Step 2: 기존 attach surface 재사용 여부 확인

이미 같은 swarm tmux에 attach된 cmux surface가 있으면 새로 만들지 않는다 (중복 분할 방지).

```bash
EXISTING=$(cmux tree 2>&1 | grep -F "$SWARM_SOCK attach" | head -1 || true)
if [ -n "$EXISTING" ]; then
  echo "이미 attach된 surface가 있어 재사용합니다."
  # surface UUID는 .dev/.team-surface-uuid에 저장돼 있을 것
fi
```

마커 파일 `.dev/.team-surface-uuid`에 UUID가 저장돼 있고 해당 surface가 살아있으면 재사용. 아니면 Step 3 진행.

### Step 3: 새 cmux surface 생성

현재 workspace에 surface 추가:

```bash
NEW_SURF=$(cmux new-surface --workspace "${CMUX_WORKSPACE_ID}" 2>&1 | awk '{print $2}')
# 예: surface:20
sleep 0.3
```

UUID 매핑 확보 (drag/move 명령은 UUID 필요):

```bash
NEW_SURF_UUID=$(cmux --id-format both list-pane-surfaces \
  | awk -v s="$NEW_SURF" '$1==s || $2==s {print $2}' \
  | head -1)
echo "$NEW_SURF_UUID" > .dev/.team-surface-uuid
```

### Step 4: surface 안에서 swarm tmux에 attach

```bash
cmux send --surface "$NEW_SURF_UUID" "tmux -S $SWARM_SOCK attach -t $SWARM_SESSION\n"
sleep 1.0
# 검증
cmux read-screen --surface "$NEW_SURF_UUID" --lines 5
```

`can't find session` 에러가 나오면 세션 이름이 다른 것이므로 Step 1에서 잡은 정확한 이름인지 재확인.

### Step 5: 분할 (move-surface 우선, drag는 fallback)

`drag-surface-to-split`이 attach 직후 "Surface not found"를 반환하는 케이스가 보고됨 (cmux 내부 상태 동기화 타이밍 추정). 안정적인 우회 경로는 새 pane을 만들고 surface를 그 pane으로 이동시키는 것:

```bash
# 5-1. workspace 활성화 + 새 pane 생성
cmux select-workspace --workspace "${CMUX_WORKSPACE_ID}" 2>/dev/null
TARGET_PANE=$(cmux new-pane --workspace "${CMUX_WORKSPACE_ID}" --direction right 2>&1 | awk '{print $2}')
sleep 0.3

# 5-2. 새로 만든 attach surface를 그 pane으로 이동
cmux move-surface --surface "$NEW_SURF_UUID" --pane "$TARGET_PANE" --focus true
sleep 0.3
```

**대안 (Tier 1 시도)**: 일부 cmux 버전에서는 `drag-surface-to-split`이 잘 동작한다. 먼저 시도하고 실패 시 위 move-surface 경로로 fallback할 수 있다:

```bash
if cmux drag-surface-to-split --surface "$NEW_SURF_UUID" right 2>/dev/null; then
  echo "drag 성공"
else
  # 위 5-1, 5-2 실행
  ...
fi
```

### Step 6: 검증

```bash
cmux tree | grep -A2 "$NEW_SURF_UUID"
cmux read-screen --surface "$NEW_SURF_UUID" --lines 30
```

화면에 `@planner`, `@coder` 등 에이전트 pane이 보이면 성공.

### Step 7: 결과 보고

```
🖥️ cmux 분할 완료
   - swarm socket: /tmp/tmux-501/claude-swarm-{PID}
   - swarm session: claude-swarm
   - cmux surface UUID: {UUID} (저장: .dev/.team-surface-uuid)
   - 위치: workspace:N / pane:M
   에이전트가 attach된 swarm tmux 안에 표시됩니다.
```

## 정리 (Phase 7)

오케스트레이터는 메인 스킬(dev/fix/persist)의 Phase 7에서 다음을 수행한다:

```bash
# attach surface 닫기 (선택 — 다음 세션 위해 남길 수도 있음)
TEAM_UUID=$(cat .dev/.team-surface-uuid 2>/dev/null)
[ -n "$TEAM_UUID" ] && cmux close-surface --surface "$TEAM_UUID"
rm -f .dev/.team-surface-uuid
```

## Fallback (분할 실패 시)

위 절차로 분할에 실패하면:
1. 사용자에게 swarm socket과 session 이름을 노출
2. 수동 attach 안내:
   ```
   tmux -S /tmp/tmux-501/claude-swarm-{PID} attach -t claude-swarm
   ```
3. 메인 워크플로우는 계속 진행 (분할은 가시성 도구일 뿐, 에이전트 동작과 무관)

## 주의사항

- claude-swarm 디렉토리는 세션 종료 후에도 stale 상태로 남을 수 있다. 가장 최근 mtime의 socket을 우선 선택한다.
- workspace를 vlock 상태로 두지 않는다 — `select-workspace`로 활성화 후 작업.
- `drag-surface-to-split`은 short ref(`surface:N`)에서 "Surface not found" 발생, UUID 사용 필수. 그래도 실패 시 move-surface 경로로 fallback.
- `team-lead` 멤버는 메인 세션이므로 별도 처리 불필요 — swarm tmux는 보조 에이전트만 포함.
