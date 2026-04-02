# Hooks

oh-my-beom 플러그인의 안전 훅. 2개만 사용한다.

## Exit Code 규약

| 코드 | 의미 | 사용 |
|------|------|------|
| `0` | 성공 | 정상 진행 |
| `1` | 비차단 에러 | 경고 표시, 진행 허용 |
| `2` | 차단 | 진행 중단, 수정 요구 |

## 훅 목록

### pre-tool-guard (PreToolUse/Bash)

보호 브랜치(main, master, develop, test, dev)에서 `git commit` 실행을 차단한다.

- 이벤트: PreToolUse (Bash)
- 타임아웃: 2초
- 차단 시: exit 2 + 작업 브랜치 생성 안내

### code-quality-gate (PreToolUse/Write|Edit)

Write/Edit 시 보안 위험을 감지하고 플러그인 파일 수정을 보호한다.

- 이벤트: PreToolUse (Write|Edit)
- 타임아웃: 3초
- 차단 항목 (exit 2): AWS/OpenAI/GitHub API 키 하드코딩, eval(), innerHTML, SQL 문자열 연결
- 확인 항목 (ask): hooks/, rules/, config/, agents/, skills/ 등 플러그인 파일 수정
