# Hooks

oh-my-beom 플러그인의 안전 훅.

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

### pre-commit-build-check (PreToolUse/Bash)

`git commit` 실행 전 프로젝트 빌드/타입체크가 통과하는지 확인한다. 실패 시 커밋을 차단한다.

- 이벤트: PreToolUse (Bash, git commit 명령만 대상)
- 타임아웃: 120초
- 대상 프로젝트:
  - Gradle (`build.gradle(.kts)` 존재 + `gradlew` 실행 가능): `./gradlew compileKotlin compileTestKotlin -q`
  - Node + TypeScript (`package.json` + `tsconfig.json`): `bunx tsc --noEmit` 또는 `npx tsc --noEmit`
  - Python (`pyproject.toml`/`setup.py`): 스테이징된 `.py` 파일에 `python3 -m py_compile`
- 건너뛰기:
  - `git commit --amend`
  - 스테이징된 소스 파일이 없을 때 (docs/config만 변경된 커밋)
  - 환경 변수 `SKIP_BUILD_CHECK=1` 설정 시
- 차단 시: 마지막 에러 로그(최대 800자)와 함께 deny

### version-sync-check (PreToolUse/Bash)

`git commit` 실행 전, 플러그인 메타 3개 파일의 버전이 일치하는지 검증한다. 드리프트 발견 시 커밋을 차단하여 한쪽만 갱신되는 사고를 예방한다.

- 이벤트: PreToolUse (Bash, git commit 명령만 대상)
- 타임아웃: 3초
- 검사 대상:
  - `package.json` → `.version`
  - `.claude-plugin/plugin.json` → `.version`
  - `.claude-plugin/marketplace.json` → `.plugins[source="./"].version` (또는 첫 번째 plugin)
- 건너뛰기:
  - `git commit --amend`
  - 위 3개 파일 중 하나라도 없는 경우 (이 hook의 적용 대상이 아닌 프로젝트)
- 차단 시: 3개 파일의 현재 버전을 표시하고 `/version-bump` 사용 권고
- 짝꿍 스킬: `/version-bump` — 3개 파일을 한 번에 동기화 (semver 규칙 또는 명시 버전)
