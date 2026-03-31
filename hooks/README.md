# Hooks

oh-my-beom 플러그인의 이벤트 기반 자동화 훅.

## Exit Code 규약

| 코드 | 의미 | 사용 |
|------|------|------|
| `0` | 성공 | 정상 진행 |
| `1` | 비차단 에러 | 경고 표시, 진행 허용 |
| `2` | 차단 에러 | 진행 중단, 수정 요구 |

## 훅 목록

| 훅 | 이벤트 | 매처 | 역할 | 타임아웃 |
|----|--------|------|------|---------|
| **session-start** | SessionStart | startup\|clear\|compact | 활성 계획 감지 + 워크플로우 가이드 표시 | sync |
| **prompt-router** | UserPromptSubmit | * | 키워드 감지 → 스킬 자동 라우팅 | 3s |
| **pre-tool-guard** | PreToolUse | Bash | 보호 브랜치 커밋 차단 | 2s |
| **code-quality-gate** | PreToolUse | Write\|Edit | 시크릿/보안 감지 + 플러그인 파일 보호 | 3s |
| **error-learner** | PostToolUse | Bash | 에러 패턴 기록 + 반복 에러 경고 | 3s |
| **task-verifier** | TaskCompleted | — | 계획 완료 기준 자동 검증 (품질 게이트) | 300s |
| **idle-checker** | TeammateIdle | — | 미완료 항목 감지 → 재할당 지시 | 10s |
| **stop-report** | Stop | — | /beom 세션 종료 시 보고서 자동 생성 | 5s |

## 검사 항목

### code-quality-gate

**코드 품질 (deny):**
- AWS/OpenAI/GitHub 시크릿 하드코딩
- TODO/FIXME 플레이스홀더 잔존
- eval() 사용 (JS/TS/Python)
- innerHTML 직접 할당 (XSS)
- SQL 문자열 연결 (인젝션)

**탬퍼링 감지 (ask):**
- hooks/, rules/, config/, agents/, skills/, .claude-plugin/, CLAUDE.md 수정 시 사용자 확인 요청

### error-learner

- Bash 실패 시 `.dev/error-log.md`에 자동 기록
- 동일 에러 2회 이상 반복 시 경고 + 근본 원인 분석 유도

## 테스트

```bash
bash tests/test-hooks.sh
```
