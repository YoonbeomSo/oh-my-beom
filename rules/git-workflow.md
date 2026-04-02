# Git 워크플로우

## 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `master` | 운영 배포 브랜치 |
| `dev` | 개발 브랜치 |
| `test` | 테스트 브랜치 |
| `deploy/deploy_YYYYMMDD` | 배포 브랜치 |
| `feat/*` | 기능 개발 브랜치 |
| `hotfix/*` | 긴급 수정 브랜치 |

## 브랜치 규칙

보호 브랜치(`master`, `main`, `dev`, `test`)에서 직접 커밋하지 마라.

1. **파일을 수정하기 전에** 작업 브랜치를 먼저 생성하라. 수정 후에 브랜치를 만드는 것이 아니라, 브랜치를 만든 뒤 수정을 시작하라.
2. 작업 브랜치는 `dev` 또는 `test`에서 분기한다. 브랜치명은 `feat/{작업내용}` 형식.
3. push는 origin에 동일 이름의 `feat/{작업내용}` 브랜치로만 한다. `master`, `main`, `dev`, `test`에 직접 push 금지.
4. commit, push 등 git 관련 명령은 반드시 개발자의 확인을 받을 것.

### 브랜치 정리 시 안전 규칙

브랜치 삭제, `git clean` 등 정리 작업 전에 반드시 확인하라:

1. `git status`로 미커밋 변경사항(modified, untracked) 확인
2. `git stash list`로 stash 확인
3. **미커밋 변경사항이 있으면 절대 삭제하지 않는다** — 사용자에게 먼저 알리고 지시를 받을 것
4. `--force` 옵션(`git branch -D` 등) 사용 금지 — 사용자가 명시적으로 요청한 경우에만
5. PR이 머지되었더라도 워킹 디렉토리에 새 작업이 시작되었을 수 있으므로 **PR 상태만으로 판단하지 않는다**

## 커밋 규칙

- 커밋 메시지는 한국어로 작성한다. 기능을 명확하게 설명하라.
- 민감 파일(`.env*`, `*.key`, `*.pem`, `credentials*`, `*secret*`)은 절대 커밋하지 마라. `config/config.json`의 `sensitiveFilePatterns`를 참조한다.
- 빌드 산출물(`build/`, `node_modules/`, `dist/` 등)을 커밋하지 마라. `config/config.json`의 `buildArtifactPatterns`를 참조한다.

### Co-Authored-By 금지

커밋 메시지에 `Co-Authored-By` 트레일러를 추가하지 마라. 이 플러그인의 커밋은 사용자 단독 저작이다.

## 최신 상태 유지

**매 요청 시작 전** 아래를 순서대로 실행하라:

1. `git branch --show-current`로 현재 브랜치 확인
2. **main이 아닌 브랜치에 있다면**:
   - PR 상태를 확인하여 merged 상태일 때만 `git checkout main && git pull`로 복귀
   - PR이 open이거나 PR이 없으면 브랜치를 유지 — 임의로 main으로 돌아가지 마라
3. **main 브랜치에 있다면**: uncommitted 변경이 없으면 `git pull --rebase --autostash` 실행

## PR 규칙

- **PR 생성까지만.** `gh pr merge` 등 머지 명령은 절대 실행하지 마라.
- 사용자가 직접 머지를 요청하더라도 거절하고, PR 링크를 제공하여 직접 머지하도록 안내하라.
