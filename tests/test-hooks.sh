#!/usr/bin/env bash
# oh-my-beom 훅 스크립트 테스트
# 실행: bash tests/test-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PASS=0
FAIL=0

# 색상
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo -e "  ${GREEN}PASS${NC} $name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" substring="$2" actual="$3"
  if echo "$actual" | grep -q "$substring"; then
    echo -e "  ${GREEN}PASS${NC} $name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $name"
    echo "    expected to contain: $substring"
    echo "    actual: $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local name="$1" substring="$2" actual="$3"
  if echo "$actual" | grep -q "$substring"; then
    echo -e "  ${RED}FAIL${NC} $name"
    echo "    should NOT contain: $substring"
    echo "    actual: $actual"
    FAIL=$((FAIL + 1))
  else
    echo -e "  ${GREEN}PASS${NC} $name"
    PASS=$((PASS + 1))
  fi
}

# ============================================================
echo -e "${YELLOW}=== prompt-router 테스트 ===${NC}"
# ============================================================

ROUTER="${PLUGIN_ROOT}/hooks/prompt-router"

test_router() {
  local prompt="$1"
  echo "{\"prompt\": \"$prompt\"}" | "$ROUTER" 2>/dev/null
}

# beom 키워드
RESULT=$(test_router "beom 로그인 기능 추가")
assert_contains "beom → beom 스킬" "oh-my-beom:beom" "$RESULT"

# lens 키워드
RESULT=$(test_router "정책 영향도 분석해줘")
assert_contains "정책 → lens 스킬" "oh-my-beom:lens" "$RESULT"

RESULT=$(test_router "비즈니스 규칙 확인")
assert_contains "비즈니스 → lens 스킬" "oh-my-beom:lens" "$RESULT"

# research 키워드
RESULT=$(test_router "이 코드 분석해줘")
assert_contains "분석해 → research 스킬" "oh-my-beom:research" "$RESULT"

RESULT=$(test_router "research the codebase")
assert_contains "research → research 스킬" "oh-my-beom:research" "$RESULT"

# persist 키워드
RESULT=$(test_router "끝까지 해줘")
assert_contains "끝까지 → persist 스킬" "oh-my-beom:persist" "$RESULT"

RESULT=$(test_router "멈추지마 이거 완성해")
assert_contains "멈추지마 → persist 스킬" "oh-my-beom:persist" "$RESULT"

# 개발 키워드 → beom
RESULT=$(test_router "이 기능 개발해줘")
assert_contains "개발해 → beom 스킬" "oh-my-beom:beom" "$RESULT"

RESULT=$(test_router "로그인 페이지 만들어줘")
assert_contains "만들어줘 → beom 스킬" "oh-my-beom:beom" "$RESULT"


# 매칭 안 되는 케이스
RESULT=$(test_router "안녕하세요")
assert_contains "일반 인사 → 매칭 없음" "suppressOutput" "$RESULT"

RESULT=$(test_router "이 파일 읽어줘")
assert_contains "일반 요청 → 매칭 없음" "suppressOutput" "$RESULT"

# C3: 'dev' 오탐 방지 — "dev server" 같은 입력이 /beom으로 라우팅되지 않아야 함
RESULT=$(test_router "dev server 설정 확인해줘")
assert_contains "dev server → 매칭 없음" "suppressOutput" "$RESULT"

# 빈 입력
RESULT=$(test_router "")
assert_contains "빈 입력 → 매칭 없음" "suppressOutput" "$RESULT"

# beom 우선순위: "beom 개발해" → beom (개발해가 아님)
RESULT=$(test_router "beom 개발해줘")
assert_contains "beom 개발해 → beom 우선" "oh-my-beom:beom" "$RESULT"

# ============================================================
echo ""
echo -e "${YELLOW}=== pre-tool-guard 테스트 ===${NC}"
# ============================================================

GUARD="${PLUGIN_ROOT}/hooks/pre-tool-guard"

# git commit이 아닌 명령 → 통과
RESULT=$(echo '{"tool_input": {"command": "ls -la"}}' | "$GUARD" 2>/dev/null)
assert_contains "ls → 통과" "continue" "$RESULT"

RESULT=$(echo '{"tool_input": {"command": "git status"}}' | "$GUARD" 2>/dev/null)
assert_contains "git status → 통과" "continue" "$RESULT"

# git commit on current branch (non-protected) → 통과
RESULT=$(echo '{"tool_input": {"command": "git commit -m test"}}' | "$GUARD" 2>/dev/null)
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "unknown")
if [[ ! "$CURRENT_BRANCH" =~ ^(develop|main|master|test|dev)$ ]]; then
  assert_contains "git commit on ${CURRENT_BRANCH} → 통과" "continue" "$RESULT"
else
  assert_contains "git commit on protected ${CURRENT_BRANCH} → 차단" "deny" "$RESULT"
fi

# 빈 입력 → 통과
RESULT=$(echo '{}' | "$GUARD" 2>/dev/null)
assert_contains "빈 입력 → 통과" "continue" "$RESULT"

# ============================================================
echo ""
echo -e "${YELLOW}=== code-quality-gate 테스트 ===${NC}"
# ============================================================

GATE="${PLUGIN_ROOT}/hooks/code-quality-gate"

# 일반 코드 → 통과
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.js", "content": "const x = 1;"}}' | "$GATE" 2>/dev/null)
assert_contains "일반 코드 → 통과" "continue" "$RESULT"

# AWS 키 감지 → 차단
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.js", "content": "const key = \"AKIAIOSFODNN7EXAMPLE1\";"}}' | "$GATE" 2>/dev/null)
assert_contains "AWS 키 → 차단" "deny" "$RESULT"

# eval() 감지 → 차단 (JS 파일)
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.js", "content": "eval(userInput)"}}' | "$GATE" 2>/dev/null)
assert_contains "eval() JS → 차단" "deny" "$RESULT"

# eval() 비JS 파일 → 통과
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.sh", "content": "eval(something)"}}' | "$GATE" 2>/dev/null)
assert_contains "eval() sh → 통과" "continue" "$RESULT"

# innerHTML 감지 → 차단
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.js", "content": "el.innerHTML = data"}}' | "$GATE" 2>/dev/null)
assert_contains "innerHTML → 차단" "deny" "$RESULT"

# TODO placeholder 감지 → 차단
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.js", "content": "// TODO: implement this..."}}' | "$GATE" 2>/dev/null)
assert_contains "TODO placeholder → 차단" "deny" "$RESULT"

# 일반 TODO (구현 완료) → 통과
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.js", "content": "// TODO: 성능 개선 고려"}}' | "$GATE" 2>/dev/null)
assert_contains "일반 TODO → 통과" "continue" "$RESULT"

# 빈 입력 → 통과
RESULT=$(echo '{}' | "$GATE" 2>/dev/null)
assert_contains "빈 입력 → 통과" "continue" "$RESULT"

# Edit (new_string) → 통과
RESULT=$(echo '{"tool_input": {"file_path": "/tmp/test.js", "old_string": "x", "new_string": "y"}}' | "$GATE" 2>/dev/null)
assert_contains "Edit 일반 → 통과" "continue" "$RESULT"

# 플러그인 파일 탬퍼링 감지 (CLAUDE_PLUGIN_ROOT 설정 시)
RESULT=$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" echo '{"tool_input": {"file_path": "'"$PLUGIN_ROOT"'/hooks/hooks.json", "content": "{}"}}' | "$GATE" 2>/dev/null)
# CLAUDE_PLUGIN_ROOT 미설정이면 탬퍼링 미감지 → 통과
assert_contains "탬퍼링 감지 (미설정 시 통과)" "continue" "$RESULT"

# ============================================================
echo ""
echo -e "${YELLOW}=== error-learner 테스트 ===${NC}"
# ============================================================

LEARNER="${PLUGIN_ROOT}/hooks/error-learner"

# 성공한 명령 → 통과
RESULT=$(echo '{"tool_input": {"command": "echo ok"}, "tool_result": {"stdout": "ok", "stderr": "", "exit_code": 0}}' | "$LEARNER" 2>/dev/null)
# 빈 출력 또는 continue
if [ -z "$RESULT" ]; then
  assert_eq "Bash 성공 → 무시 (빈 출력)" "yes" "yes"
else
  assert_contains "Bash 성공 → 무시" "continue" "$RESULT"
fi

# 실패한 명령 (.dev 없으면 기록 안함)
TMPDIR2=$(mktemp -d)
RESULT=$(CLAUDE_CWD="$TMPDIR2" echo '{"tool_input": {"command": "false"}, "tool_result": {"stdout": "", "stderr": "error", "exit_code": 1}}' | "$LEARNER" 2>/dev/null)
# .dev 없으면 기록 안함 → 빈 출력
assert_eq ".dev 없으면 기록 안함" "yes" "yes"
rm -rf "$TMPDIR2"

# ============================================================
echo ""
echo -e "${YELLOW}=== hooks.json 구조 테스트 ===${NC}"
# ============================================================

HOOKS_JSON="${PLUGIN_ROOT}/hooks/hooks.json"

# 모든 이벤트가 등록되어 있는지
for event in SessionStart UserPromptSubmit PreToolUse PostToolUse TaskCompleted TeammateIdle Stop; do
  if python3 -c "
import json
with open('${HOOKS_JSON}') as f:
    data = json.load(f)
assert '$event' in data['hooks']
" 2>/dev/null; then
    assert_eq "hooks.json에 ${event} 등록" "yes" "yes"
  else
    assert_eq "hooks.json에 ${event} 등록" "yes" "no"
  fi
done

# Write|Edit matcher가 있는지
if grep -q 'Write|Edit' "$HOOKS_JSON"; then
  assert_eq "hooks.json에 Write|Edit matcher" "yes" "yes"
else
  assert_eq "hooks.json에 Write|Edit matcher" "yes" "no"
fi

# ============================================================
echo ""
echo -e "${YELLOW}=== session-start 테스트 ===${NC}"
# ============================================================

SESSION="${PLUGIN_ROOT}/hooks/session-start"

# docs/plan이 없는 임시 디렉토리에서 실행 → 워크플로우 가이드
TMPDIR=$(mktemp -d)
RESULT=$(CLAUDE_CWD="$TMPDIR" "$SESSION" 2>/dev/null)
assert_contains "plan 없음 → 워크플로우 가이드" "/beom" "$RESULT"
assert_not_contains "plan 없음 → 구버전 가이드 없음" "/plan" "$RESULT"
assert_not_contains "plan 없음 → 구버전 /dev 없음" "| /dev" "$RESULT"
rm -rf "$TMPDIR"

# ============================================================
echo ""
echo -e "${YELLOW}=== config.json 정합성 테스트 ===${NC}"
# ============================================================

CONFIG="${PLUGIN_ROOT}/config/config.json"

# protectedBranches가 존재하는지
HAS_PROTECTED=$(python3 -c "
import json
with open('${CONFIG}') as f:
    config = json.load(f)
branches = config.get('protectedBranches', [])
print(','.join(branches))
" 2>/dev/null)
assert_contains "config에 main 포함" "main" "$HAS_PROTECTED"
assert_contains "config에 test 포함" "test" "$HAS_PROTECTED"
assert_contains "config에 dev 포함" "dev" "$HAS_PROTECTED"

# pre-tool-guard 정규식과 config 일치 확인
GUARD_LINE=$(grep 'CURRENT_BRANCH.*=~' "$GUARD" 2>/dev/null || echo "")
for branch in main master develop test dev; do
  if echo "$GUARD_LINE" | grep -q "$branch"; then
    assert_eq "guard 정규식에 ${branch} 포함" "yes" "yes"
  else
    assert_eq "guard 정규식에 ${branch} 포함" "yes" "no"
  fi
done

# ============================================================
echo ""
echo -e "${YELLOW}=== 버전 정합성 테스트 ===${NC}"
# ============================================================

PKG_VER=$(python3 -c "import json; print(json.load(open('${PLUGIN_ROOT}/package.json'))['version'])" 2>/dev/null)
PLUGIN_VER=$(python3 -c "import json; print(json.load(open('${PLUGIN_ROOT}/.claude-plugin/plugin.json'))['version'])" 2>/dev/null)
MARKET_VER=$(python3 -c "import json; print(json.load(open('${PLUGIN_ROOT}/.claude-plugin/marketplace.json'))['plugins'][0]['version'])" 2>/dev/null)

assert_eq "package.json == plugin.json" "$PKG_VER" "$PLUGIN_VER"
assert_eq "package.json == marketplace.json" "$PKG_VER" "$MARKET_VER"

# ============================================================
echo ""
echo "=========================================="
echo -e "결과: ${GREEN}PASS ${PASS}${NC} / ${RED}FAIL ${FAIL}${NC}"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
