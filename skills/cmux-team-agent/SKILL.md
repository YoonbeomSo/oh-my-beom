---
name: cmux-team-agent
description: Use after spawning team agents with Agent tool when agents fail to start in cmux surfaces. Detects empty cmux surfaces and manually re-launches Claude Code CLI in them. Use proactively whenever TeamCreate + Agent spawning is used in cmux environment.
---

# cmux Team Agent Recovery

## Overview

TeamCreate로 팀을 생성하고 Agent tool로 에이전트를 spawn할 때, cmux surface는 생성되지만 Claude Code CLI가 실제로 시작되지 않는 문제가 발생할 수 있다. 이 스킬은 해당 문제를 감지하고 자동 복구한다.

> **이 스킬은 cmux 환경 전용이다.** tmux 환경에서는 `tmux-team-agent` 스킬을 사용한다. 오케스트레이터가 환경을 감지하여 적절한 스킬을 호출한다.

## When to Use

- TeamCreate로 팀 생성 후 Agent tool로 에이전트를 spawn한 직후
- 사용자가 "cmux에 안 뜬다", "분할 화면이 비어있다" 등 보고 시
- 팀 에이전트를 사용하는 모든 워크플로우에서 **항상 proactive하게** 실행

## 문제 원인

Agent tool로 에이전트를 spawn하면:
1. 팀 config에 `backendType: "tmux"`, `tmuxPaneId`가 설정됨 (cmux에서는 surface ID가 이 필드에 저장됨)
2. cmux surface가 생성됨
3. **Claude Code CLI 명령이 surface에 전송되지만 즉시 종료될 수 있음**
4. surface에는 빈 zsh 셸만 남음 (종료 코드 0으로 프롬프트 복귀)

## 복구 절차

### Step 0: 대기 (타이밍 안정화)

Agent spawn 직후에는 surface가 아직 초기화 중일 수 있다. **3초 대기** 후 상태를 확인한다.

```bash
sleep 3
```

### Step 1: 팀 config 읽기

```
Read ~/.claude/teams/{team-name}/config.json
```

각 멤버의 `agentId`, `name`, `agentType`, `model`, `tmuxPaneId` (surface ID), `color`, `cwd`를 확인한다.

> **참고:** config의 `tmuxPaneId` 필드에 cmux surface ID가 저장된다. 필드명은 하위 호환성을 위해 `tmuxPaneId`로 유지된다.

### Step 2: cmux surface 상태 확인

team-lead를 제외한 각 멤버에 대해, `tmuxPaneId`가 비어있지 않은 surface의 화면을 읽는다:

```bash
cmux read-screen --surface {tmuxPaneId} --lines 5
```

마지막 줄을 확인하여 상태를 판별한다:
- 셸 프롬프트 패턴(`$`, `%`, `❯`, `➜`)만 보이면 → **idle** (Claude 미실행, 복구 필요)
- `claude` 또는 `node` 문자열이 포함되어 있으면 → **정상 동작 중** (복구 불필요)

### Step 3: 빈 surface에 Claude Code CLI 수동 실행

team-lead를 제외한 각 멤버에 대해, Claude가 실행 중이지 않은 surface에 다음 명령을 전송한다:

```bash
cmux send --surface {tmuxPaneId} "cd {cwd} && env CLAUDECODE=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 {claude-binary-path} --agent-id {agentId} --agent-name {name} --team-name {team-name} --agent-color {color} --parent-session-id {leadSessionId} --agent-type {agentType} --permission-mode acceptEdits --model {model}\n"
```

> **cmux 참고:** `cmux send`는 문자열 끝의 `\n`을 Enter 키로 해석한다.

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
| `members[].tmuxPaneId` | cmux send의 `--surface` 타겟 |
| `members[].cwd` | `cd` 대상 경로 |

#### Claude 바이너리 경로 찾기:
```bash
which claude
```

#### agentType/agentId 특수문자 처리:
- `--agent-type` 값에 `:`가 포함될 수 있다 (예: `oh-my-beom:architect`). **이스케이프하지 않는다**.
- `--agent-id` 값에 `@`가 포함된다 (예: `architect@team-name`). 마찬가지로 **이스케이프하지 않는다**.

### Step 4: 실행 확인 + 재시도

각 surface에 대해 **5초 대기** 후 확인:
```bash
sleep 5 && cmux read-screen --surface {tmuxPaneId} --lines 5
```

해당 surface가 여전히 idle 상태이면:

#### 재시도 (1회):
1. surface 내용을 캡처하여 에러 확인:
   ```bash
   cmux read-screen --surface {tmuxPaneId} --lines 20
   ```
2. 프롬프트만 보이면 (명령이 실행되었으나 종료됨) → 동일 명령을 다시 전송
3. **5초 추가 대기** 후 재확인

#### 재시도 후에도 실패:
사용자에게 다음을 안내한다:
```
⚠️ cmux surface {tmuxPaneId}에서 에이전트 {name}이 시작되지 않습니다.
Fallback: Agent tool로 직접 에이전트를 호출합니다 (non-team 모드).
```

그리고 **해당 에이전트를 fallback으로 전환**한다:
- 이후 Phase에서 `SendMessage(to="{name}")` 대신 `Agent(subagent_type="{agentType}")` 사용
- 팀 task list는 오케스트레이터가 직접 관리

### Step 5: 결과 보고

복구 시도 결과를 요약 보고:

| surface | agent | 상태 |
|---------|-------|------|
| {id} | {name} | 복구 성공 / 재시도 성공 / fallback 전환 |

## 예방적 사용 (Proactive)

TeamCreate + Agent spawn 직후 각 멤버의 surface에 대해 체크를 자동 수행:

```bash
sleep 3
cmux read-screen --surface {surfaceId} --lines 5
```

셸 프롬프트만 보이는 surface가 있으면 즉시 Step 3을 수행한다.

## 주의사항

- `team-lead` 멤버는 현재 세션이므로 복구 대상에서 **제외**한다
- `tmuxPaneId`가 빈 문자열인 멤버도 제외한다
- 에이전트가 이미 작업을 완료하고 정상 종료된 경우에는 재시작하지 않는다
- 복구 후에도 에이전트의 task 상태는 TaskList/TaskUpdate로 별도 관리해야 한다
- `cwd`가 worktree 경로인 경우, 해당 경로로 `cd`해야 에이전트가 올바른 컨텍스트에서 동작한다
