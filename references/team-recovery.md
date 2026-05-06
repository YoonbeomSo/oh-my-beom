# 팀 에이전트 복구 절차 (공통)

`/dev-beom`, `/fix-beom`, `/persist-beom`이 TeamCreate 직후 공통으로 수행하는 환경 감지 + 복구 스킬 호출 절차.

## 🛑 필수 1단계 — 환경 감지 + 복구 스킬 호출 (생략 절대 금지)

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

자율 모드(`/persist-beom`)에서도 이 단계는 생략하지 않는다. PostToolUse 훅이 컨텍스트를 주입하므로 그 안내를 무조건 따를 것.
