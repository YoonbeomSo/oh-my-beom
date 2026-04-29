---
name: tmux-team-agent
description: Use after spawning team agents with Agent tool when running inside tmux. TeamCreate spawns agents in a separate claude-swarm tmux server; this skill creates a split pane in the parent tmux that attaches to the swarm tmux so the agents become visible. Use proactively whenever TeamCreate is used in tmux environment.
---

# tmux Team Agent Visualization

## Overview

TeamCreate는 **자체 tmux 서버**(`/tmp/tmux-{UID}/claude-swarm-{PID}`)를 띄워 그 안에서 에이전트들을 실행한다. 사용자의 부모 tmux 서버($TMUX)와 별개이므로, 분할 화면을 보려면 부모 tmux에 새 pane을 만들고 그 안에서 swarm tmux에 `tmux attach`를 해야 한다.

이 스킬은:
1. claude-swarm tmux 서버 socket을 감지 (LIVE PID 필터링)
2. 부모 tmux에 새 pane을 분할 생성
3. 새 pane에서 swarm tmux에 attach

> **이 스킬은 tmux 환경 전용이다.** cmux 환경에서는 `cmux-team-agent` 스킬을 사용한다.

## When to Use

- TeamCreate로 팀 생성 직후 (PostToolUse 훅 `team-recovery-reminder`가 자동 안내)
- 사용자가 "tmux에 안 뜬다", "분할 화면이 비어있다" 등 보고 시
- `$TMUX`가 set이고 `$CMUX_SOCKET`이 unset인 환경에서

## 문제 원인 (실제 동작 모델)

| 가정 (잘못된 이전 모델) | 실제 동작 |
|------------------------|-----------|
| 부모 $TMUX 안에 에이전트 pane이 생성된다 | ❌ — 별도 claude-swarm tmux 서버에 생성됨 |
| `tmux list-panes -a`로 에이전트 pane을 찾을 수 있다 | ❌ — 그건 부모 tmux의 pane 목록일 뿐 |
| config의 `tmuxPaneId`가 부모 tmux의 pane ID | ❌ — `tmuxPaneId`는 swarm tmux 안의 pane ID |

## 복구 절차

### Step 0: 대기

```bash
sleep 2   # swarm tmux 서버 초기화 시간 확보
```

### Step 1: claude-swarm tmux 서버 찾기 (LIVE PID 필터링)

stale socket을 제외하고 살아있는 가장 최근 socket을 선택한다:

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

세션 이름:

```bash
SWARM_SESSION=$(tmux -S "$SWARM_SOCK" list-sessions -F "#{session_name}" 2>/dev/null | head -1)
echo "swarm session: $SWARM_SESSION"
```

### Step 2: 기존 attach pane 재사용 여부 확인

마커 파일 `.dev/.team-pane-id`에 기존 pane ID가 있으면 재사용:

```bash
if [ -f .dev/.team-pane-id ]; then
  EXISTING_PANE=$(cat .dev/.team-pane-id)
  # 살아있는 pane인지 확인
  if tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -Fxq "$EXISTING_PANE"; then
    echo "기존 attach pane 재사용: $EXISTING_PANE"
    SKIP_CREATE=1
  fi
fi
```

### Step 3: 부모 tmux에 새 pane 생성

```bash
if [ -z "${SKIP_CREATE:-}" ]; then
  TEAM_PANE=$(tmux split-window -h -P -F "#{pane_id}")
  echo "$TEAM_PANE" > .dev/.team-pane-id
  sleep 0.3
fi
TEAM_PANE=$(cat .dev/.team-pane-id)
```

### Step 4: 새 pane에서 swarm tmux에 attach

```bash
tmux send-keys -t "$TEAM_PANE" "tmux -S $SWARM_SOCK attach -t $SWARM_SESSION" Enter
sleep 1.0

# 검증
tmux capture-pane -t "$TEAM_PANE" -p | tail -10
```

`can't find session` 에러가 나오면 세션 이름이 다른 것. Step 1에서 잡은 정확한 이름인지 재확인.

### Step 5: 검증 + 결과 보고

```bash
tmux capture-pane -t "$TEAM_PANE" -p | tail -30
```

화면에 `@planner`, `@coder` 등 에이전트 pane이 보이면 성공.

```
🖥️ tmux 분할 완료
   - swarm socket: /tmp/tmux-{UID}/claude-swarm-{PID}
   - swarm session: claude-swarm
   - 부모 tmux pane ID: %N (저장: .dev/.team-pane-id)
   에이전트가 attach된 swarm tmux 안에 표시됩니다.
```

## 정리 (Phase 7)

오케스트레이터는 메인 스킬(dev/fix/persist)의 Phase 7에서:

```bash
[ -f .dev/.team-pane-id ] && tmux kill-pane -t "$(cat .dev/.team-pane-id)" 2>/dev/null
rm -f .dev/.team-pane-id
```

## Fallback (분할 실패 시)

위 절차로 분할에 실패하면:
1. 사용자에게 swarm socket과 session 이름 노출
2. 수동 attach 안내:
   ```
   tmux -S /tmp/tmux-{UID}/claude-swarm-{PID} attach -t claude-swarm
   ```
3. 메인 워크플로우는 계속 진행 (분할은 가시성 도구일 뿐, 에이전트 동작과 무관)

## 주의사항

- claude-swarm 디렉토리는 세션 종료 후에도 stale 상태로 남는다 — **반드시 PID alive 체크** (`ps -p`)
- `team-lead` 멤버는 메인 세션이므로 별도 처리 불필요 — swarm tmux는 보조 에이전트만 포함
- `cwd`가 worktree 경로인 경우, `cd` 명령은 swarm tmux 내부에서 처리되므로 부모 tmux에서는 신경 쓸 필요 없음
- 부모 tmux($TMUX)가 unset이라면 이 스킬은 적용 불가 — `cmux-team-agent` 또는 mailbox 모드로 동작
