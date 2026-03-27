---
name: commit
version: 1.0.0
description: 브랜치명에서 이슈 키를 파싱하여 한국어 커밋 메시지로 Git 커밋. 커밋 전 lint/test pre-check, 민감 파일 감지 포함
argument-hint: [이슈키] [커밋 메시지]
allowed-tools:
  # git - 커밋 핵심
  - Bash(git rev-parse:*)
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git show:*)
  - Bash(git branch:*)
  # lint/test - 커밋 전 pre-check
  - Bash(./gradlew:*)
  - Bash(npm:*)
  - Bash(npx:*)
  - Bash(bun:*)
  - Bash(bunx:*)
  - Bash(yarn:*)
  - Bash(pnpm:*)
  - Bash(ruff:*)
  - Bash(black:*)
  - Bash(pytest:*)
  # 도구 존재 확인 - lint/test 내부 pre-check용
  - Bash(which:*)
  - Bash(test:*)
  # git - 에러 복구, 이력 참고, 빌드 아티팩트 tracking 해제
  - Bash(git reset:*)
  - Bash(git log:*)
  - Bash(git rm:*)
  # 파일 도구
  - Read
  - Glob
  - Grep
  # 사용자 확인 — 민감 파일 경고, 대량 스테이징 확인
  - AskUserQuestion
---

변경사항을 스테이징하고, 브랜치명에서 이슈 키를 파싱하여 한국어 커밋 메시지로 커밋한다.

항상 한국어로 응답한다.

Arguments:
- 인자 없음: 이슈 키는 브랜치에서 파싱, 메시지는 변경 내용에서 자동 생성
- ARGS[0]만: 커밋 메시지로 사용. 이슈 키는 브랜치에서 파싱
- ARGS[0] + ARGS[1]: ARGS[0]은 이슈 키 (`^[A-Z]+-[0-9]+$` 매칭 필수, 불일치 시 에러), ARGS[1]은 커밋 메시지

## 사전 확인

- Git 저장소인지 확인
- **작업 디렉토리 보정**: `git rev-parse --show-toplevel`로 Git 루트를 확인한다. 현재 디렉토리와 다르면, 이후 모든 git/빌드 명령을 Git 루트 기준 서브셸 `(cd <git-root> && <명령>)`로 실행한다.
- 커밋할 변경사항이 있는지 확인 (없으면: "커밋할 변경사항이 없습니다.")
- 커밋 전에 lint와 test를 실행한다:
  - 프로젝트 타입 감지 (빌드/설정 파일 기준):
    | 파일 | 린트 | 테스트 |
    |------|------|--------|
    | `build.gradle.kts` / `build.gradle` | `./gradlew ktlintFormat` | `./gradlew test` |
    | `package.json` | `bun run lint --fix` 또는 `npm run lint -- --fix` | `bun test` 또는 `npm test` |
    | `pyproject.toml` / `setup.py` | `ruff format .` | `pytest --tb=short` |
  - 도구 존재 확인 (`which` / `test -x`) 후 실행. 도구가 없으면 해당 단계를 건너뛴다.
  - Node.js: `which bun` → 있으면 bun, 없으면 npm 사용.
  - Lint 포맷팅 변경은 커밋에 포함.
  - Test 실패 시 커밋을 중단하고 사용자에게 보고.
  - 타임아웃: lint/test Bash 명령에 `timeout: 300000` (5분) 파라미터를 설정한다.

## 이슈 키 파싱

- `git branch --show-current`로 브랜치명을 확인한다.
- 브랜치명에서 이슈 키 패턴 (`[A-Z]+-[0-9]+`)을 추출한다.
- 예시: `feat/JIRA-123/login` → `JIRA-123`, `AFS-6/local-ddl` → `AFS-6`
- 미발견 시: AskUserQuestion으로 입력을 요청한다. "건너뛰기 (이슈 키 없이 진행)" 옵션을 포함한다.

## 커밋 메시지 생성

메시지를 자동 생성할 때:
1. `git diff --stat` (또는 `--cached --stat`)로 변경 요약 확인
2. 변경 파일 50개 이하면 `git diff --cached`로 상세 diff 확인. 50개 초과면 `--stat` 요약만으로 메시지 생성
3. 어떤 파일이 수정/추가/삭제되었는지 파악

**메시지 구조**:
- **제목 (첫 줄)**: 변경의 핵심을 한국어로 요약. 40자 이내.
  - 이슈 키 있으면: `[ISSUE-KEY] 메시지`
  - 이슈 키 없으면: `메시지`
- **본문 (빈 줄 이후)**: 구체적 변경사항을 `-` bullet으로 나열

예시:
```
[JIRA-123] 로그인 기능 추가

- 로그인 API 엔드포인트 구현
- JWT 토큰 발급 로직 추가
- 로그인 폼 UI 구현
```

## 커밋 실행

0. `git diff --cached --name-only`로 기존 staged 파일 목록을 캡처한다. (커밋 실패 시 원래 staged 상태를 복원하기 위함)
1. `git status --short`로 변경 파일 목록을 확인하고, 목록을 사용자에게 표시한다.
2. 빌드 아티팩트 패턴이 tracked 파일 목록에 있으면: `.gitignore`에 있는지 확인하고, 있으면 `git rm -r --cached <pattern>`으로 tracking을 해제한다. **주의: 반드시 `--cached` 플래그를 사용할 것.**
3. 민감 파일 패턴(`.env`, `credentials`, `secret` 등)이 목록에 있으면 사용자에게 경고하고 스테이징에서 제외할지 확인한다.
4. 변경 파일이 20개를 초과하면 사용자에게 전체 스테이징 여부를 확인한다.
5. 스테이징:
   - 제외 파일 없음: `git add -A`
   - 제외 파일 있음: `git add <나머지 파일 각각 지정>`
6. HEREDOC 포맷으로 커밋:
   ```bash
   git commit -m "$(cat <<'EOF'
   [ISSUE-KEY] 제목

   - 변경사항 1
   - 변경사항 2
   EOF
   )"
   ```
7. 커밋이 실패하면 `git reset HEAD`로 스테이징을 원복한 뒤, step 0에서 캡처한 기존 staged 파일이 있으면 `git add <파일>`로 재스테이징하여 원래 상태를 복원하고, 사용자에게 에러를 보고한다.
8. `git show --stat HEAD`로 결과 표시

**금지**: `Co-Authored-By` 라인을 절대 추가하지 말 것.
