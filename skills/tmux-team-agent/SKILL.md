---
name: tmux-team-agent
description: Use after spawning team agents with Agent tool when agents fail to start in tmux panes. Detects empty tmux panes and manually re-launches Claude Code CLI in them. Use proactively whenever TeamCreate + Agent spawning is used.
---

# tmux Team Agent Recovery

## Overview

TeamCreate로 팀을 생성하고 Agent tool로 에이전트를 spawn할 때, tmux pane은 생성되지만 Claude Code CLI가 실제로 시작되지 않는 문제가 발생할 수 있다. 이 스킬은 해당 문제를 감지하고 자동 복구한다.

## When to Use

- TeamCreate로 팀 생성 후 Agent tool로 에이전트를 spawn한 직후
- 사용자가 "tmux에 안 뜬다", "분할 화면이 비어있다" 등 보고 시
- 팀 에이전트를 사용하는 모든 워크플로우에서 **항상 proactive하게** 실행

## 문제 원인

Agent tool로 `run_in_background: true`로 에이전트를 spawn하면:
1. 팀 config에 `backendType: "tmux"`, `tmuxPaneId`가 설정됨
2. tmux pane이 생성됨
3. **하지만 Claude Code CLI가 pane에서 시작되지 않고 바로 종료될 수 있음**
4. pane에는 빈 zsh 셸만 남음

## 복구 절차

### Step 1: 팀 config 읽기

```
Read ~/.claude/teams/{team-name}/config.json
```

각 멤버의 `agentId`, `name`, `agentType`, `model`, `tmuxPaneId`, `color`를 확인한다.

### Step 2: tmux pane 상태 확인

```bash
tmux list-panes -a -F "#{pane_id} #{pane_current_command}" 2>/dev/null
```

`pane_current_command`가 `zsh` 또는 `bash`이면 Claude가 실행되지 않은 것이다.
`claude`이면 정상 동작 중이므로 복구 불필요.

### Step 3: 빈 pane에 Claude Code CLI 수동 실행

team-lead를 제외한 각 멤버에 대해, `tmuxPaneId`가 비어있지 않고 Claude가 실행 중이지 않은 pane에 다음 명령을 전송한다:

```bash
tmux send-keys -t {tmuxPaneId} 'env CLAUDECODE=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 {claude-binary-path} --agent-id {agentId} --agent-name {name} --team-name {team-name} --agent-color {color} --parent-session-id {leadSessionId} --agent-type {agentType} --permission-mode acceptEdits --model {model}' Enter
```

#### 변수 매핑 (config.json -> 명령어):
| config 필드 | 명령어 플래그 |
|---|---|
| `members[].agentId` | `--agent-id` |
| `members[].name` | `--agent-name` |
| `name` (팀 이름) | `--team-name` |
| `members[].color` | `--agent-color` |
| `leadSessionId` | `--parent-session-id` |
| `members[].agentType` | `--agent-type` |
| `members[].model` | `--model` |
| `members[].tmuxPaneId` | tmux send-keys의 `-t` 타겟 |

#### Claude 바이너리 경로 찾기:
```bash
which claude
```
일반적으로 `/opt/homebrew/Caskroom/claude-code/{version}/claude` 또는 `$(which claude)`

#### agentType에 콜론이 포함된 경우:
`--agent-type` 값에 `:`가 있으면 **이스케이프하지 않는다** (tmux send-keys 내에서 따옴표로 감싸져 있으므로).

### Step 4: 실행 확인

각 pane에 대해 5~8초 대기 후 확인:
```bash
sleep 5 && tmux capture-pane -t {tmuxPaneId} -p | grep -v "^$" | tail -10
```

Claude Code가 시작되어 작업 중인 로그가 보이면 성공.

## 예방적 사용 (Proactive)

TeamCreate + Agent spawn 직후 아래 체크를 자동 수행:

```bash
# 모든 pane의 실행 중인 프로세스 확인
tmux list-panes -a -F "#{pane_id} #{pane_current_command}"
```

`zsh`/`bash`만 실행 중인 에이전트 pane이 있으면 즉시 Step 3을 수행한다.

## 주의사항

- `team-lead` 멤버는 현재 세션이므로 복구 대상에서 **제외**한다
- `tmuxPaneId`가 빈 문자열인 멤버도 제외한다
- 에이전트가 이미 작업을 완료하고 정상 종료된 경우에는 재시작하지 않는다
- 복구 후에도 에이전트의 task 상태는 TaskList/TaskUpdate로 별도 관리해야 한다
