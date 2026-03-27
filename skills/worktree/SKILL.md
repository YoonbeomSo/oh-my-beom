---
name: worktree
version: 2.0.0
description: "Git worktree 자동화. 두 가지 모드 지원: (1) 기본 모드 -- 프로젝트 외부(../worktrees-{name}/)에 워크트리 생성. (2) --workspace 모드 -- 프로젝트 내부(main/ + worktrees/) workspace 구조로 격리된 기능 개발."
argument-hint: "<create|list|switch|status|done|remove|setup> [name] [--workspace]"
allowed-tools:
  # git - worktree 관리 핵심
  - Bash(git worktree:*)
  - Bash(git branch:*)
  - Bash(git checkout:*)
  - Bash(git rev-parse:*)
  - Bash(git -C:*)
  - Bash(git log:*)
  - Bash(git status:*)
  - Bash(git remote:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git push:*)
  # 파일시스템 - worktree 생성/이동/정리
  - Bash(pwd:*)
  - Bash(basename:*)
  - Bash(dirname:*)
  - Bash(mkdir:*)
  - Bash(cp:*)
  - Bash(mv:*)
  - Bash(rm:*)
  - Bash(ls:*)
  - Bash(df:*)
  - Bash(test:*)
  - Bash(find:*)
  # 의존성 설치 - worktree 생성 후 환경 세팅
  - Bash(npm:*)
  - Bash(yarn:*)
  - Bash(pnpm:*)
  - Bash(bun:*)
  - Bash(./gradlew:*)
  - Bash(./mvnw:*)
  - Bash(mvn:*)
  - Bash(pip:*)
  - Bash(poetry:*)
  # 파일 도구
  - Read
  - Write
  - Glob
  - Grep
  # 사용자 확인
  - AskUserQuestion
---

# Worktree 스킬

Git worktree를 관리하여 격리된 기능 개발을 지원한다. 두 가지 모드를 제공한다.

항상 한국어로 응답한다.

## 두 가지 모드

### 기본 모드 (Default)

워크트리를 **프로젝트 외부** 형제 디렉토리에 생성한다. `.gitignore` 수정이 불필요하고, 빌드 도구 간섭이 없다.

```
~/projects/
├── shopping-api/                        # Main project (git root)
├── worktrees-shopping-api/              # Worktrees for shopping-api
│   ├── auth-feature/
│   └── hot-deals-api/
├── shopping-curation/                   # Another project
└── worktrees-shopping-curation/
    └── slot-refactor/
```

**Path formula:** `../worktrees-{project-name}/<branch-name>`

Where `project-name` = `basename $(git rev-parse --show-toplevel)`

### Workspace 모드 (`--workspace`)

워크트리를 **프로젝트 내부** `worktrees/` 디렉토리에 생성한다. Claude Code의 파일 도구가 세션 시작 디렉토리 기준으로 동작하므로, 별도 `cd` 없이 모든 워크트리에 접근할 수 있다. `/worktree setup`으로 구조를 초기화한다.

```
workspace/              <- Claude 세션 시작점
├── main/               <- git repo 본체
└── worktrees/          <- 모든 워크트리
    ├── feature-x/      <- Read("worktrees/feature-x/src/...") OK
    └── feature-y/      <- Glob(path="worktrees/feature-y") OK
```

## 모드 자동 감지

모든 명령 전에 환경을 감지한다:
1. `test -d main/.git` 성공 → **Workspace 모드**로 동작
2. `git rev-parse --is-inside-work-tree` 성공 → **기본 모드**로 동작
3. 둘 다 실패 → git 프로젝트에서 실행하라고 안내

`--workspace` 플래그가 지정되면 workspace 모드를 강제한다.

## 명령어

### `/worktree setup` (Workspace 모드 전용)

기존 git 프로젝트를 workspace 구조로 변환한다. (프로젝트당 1회)

1. 이미 workspace면 (`main/.git` 존재) 안내 후 종료
2. git repo 내부인지 확인 (`.git` 존재). 아니면 에러
3. 기존 worktree가 있으면 경고 (이동 시 참조가 깨짐)
4. 사용자 확인 후 진행
5. **프로젝트 내부에서** workspace 구조로 변환 (부모 디렉토리 접근 금지):
   ```bash
   mkdir -p main worktrees
   ```

   **Phase A -- 이동 대상 확인**:
   ```bash
   find . -maxdepth 1 ! -name '.' ! -name '..' ! -name '.git' ! -name 'main' ! -name 'worktrees' | sort
   ```
   이동 대상 목록을 사용자에게 표시하고, AskUserQuestion으로 확인한다.

   **Phase B -- 일반 파일/디렉토리 이동** (.git 제외):
   ```bash
   find . -maxdepth 1 ! -name '.' ! -name '..' ! -name '.git' ! -name 'main' ! -name 'worktrees' -exec mv {} main/ \;
   ```

   **Phase C -- .git 이동** (마지막에 실행):
   ```bash
   mv .git main/
   ```

   **Phase D -- 이동 검증**:
   잔류 항목이 있으면 사용자에게 수동 이동을 안내하고 즉시 종료.

6. `main/CLAUDE.md`가 있으면 workspace root에 복사
7. 변환 검증: `test -d main/.git && test -d worktrees && echo "OK"`
8. Claude 재시작 안내

### `/worktree create <name>`

새 워크트리 + 브랜치를 생성한다.

**기본 모드 workflow:**
1. Resolve project name: `basename $(git rev-parse --show-toplevel)`
2. Set worktree dir: `../worktrees-{project-name}/<name>`
3. Create parent dir: `mkdir -p ../worktrees-{project-name}`
4. 브랜치 중복 체크 (중복 시: 기존 사용 / 다른 이름 / 기존 삭제 중 선택)
5. Create worktree: `git worktree add ../worktrees-{project-name}/<name> -b <name>`
6. 환경 파일 복사 + 빌드 도구 감지 후 의존성 설치 제안 (`timeout: 300000`)
7. Verify: `git -C ../worktrees-{project-name}/<name> status` + `git worktree list`
8. `cd` into the new worktree
9. Report path and instructions

**Workspace 모드 workflow:**
1. Workspace 구조 확인
2. 브랜치 중복 체크
3. `git -C main worktree add ../worktrees/<name> -b <name>`
4. 환경 파일 복사 + 빌드 도구 감지 후 의존성 설치 제안
5. 포커스를 새 워크트리로 전환
6. Report

**공통 규칙:**
- 브랜치명은 사용자 입력 그대로 사용 (prefix 추가 금지)
- Claude가 브랜치명을 임의로 생성하지 않는다 -- 반드시 사용자가 지정

### `/worktree list`

모든 워크트리 목록을 표시한다.

- **기본 모드**: `git worktree list`
- **Workspace 모드**: `git -C main worktree list` + 현재 포커스 표시

### `/worktree switch <name>`

작업 대상 워크트리를 전환한다.

1. `git worktree list`에서 `<name>` 매칭 경로를 찾는다
2. 미발견 시 사용 가능한 워크트리 목록을 보여주고 선택 요청
3. `cd` to the matched worktree path
4. (Workspace 모드) 포커스 갱신

### `/worktree status`

현재 워크트리의 상태를 표시한다:
- Current branch
- Uncommitted changes (`git status`)
- Recent commits (`git log --oneline -n 10`)

### `/worktree done`

현재 워크트리 작업을 마무리한다.

1. 현재 디렉토리가 워크트리(비 main)인지 확인
2. uncommitted changes + unpushed commits 표시
3. 미커밋/미푸시 변경이 있으면 경고하고, `/commit`과 `/pull-request` 사용을 안내
4. main 워크트리로 `cd` 전환
5. (Workspace 모드) 포커스를 main으로 전환
6. 워크트리 삭제 여부 확인

### `/worktree remove <name>`

워크트리를 삭제한다.

1. uncommitted changes + unpushed commits 확인 -> 위험 시 경고
2. 현재 삭제 대상 안에 있으면 main으로 먼저 `cd`
3. 사용자 확인 후 삭제:
   - **기본 모드**: `git worktree remove ../worktrees-{project-name}/<name>`
   - **Workspace 모드**: `git -C main worktree remove worktrees/<name>` (`--force`는 명시적 확인 후만)
4. 브랜치 삭제 여부 확인
5. `git worktree prune`
6. 포커스 갱신 (삭제 대상이 active였으면 main으로)

## Build Tool Detection

워크트리 생성 후 빌드 도구를 감지하고 의존성 설치를 제안한다. 아래 순서로 확인:

| File | Build Tool | Install Command |
|------|-----------|----------------|
| `build.gradle.kts` or `build.gradle` | Gradle | `./gradlew build` (또는 사용자에게 스킵 여부 확인) |
| `pom.xml` | Maven | `./mvnw install -DskipTests` or `mvn install -DskipTests` |
| `package-lock.json` | npm | `npm install` |
| `yarn.lock` | Yarn | `yarn install` |
| `pnpm-lock.yaml` | pnpm | `pnpm install` |
| `bun.lockb` | Bun | `bun install` |
| `requirements.txt` | pip | `pip install -r requirements.txt` |
| `pyproject.toml` | Poetry/pip | `poetry install` or `pip install -e .` |
| `Gemfile` | Bundler | `bundle install` |
| `go.mod` | Go | `go mod download` |

Gradle/Maven 프로젝트는 시간이 오래 걸릴 수 있으므로 실행 여부를 사용자에게 확인한다.

## Environment Files

새 워크트리에 복사하는 환경 파일:

| File | Purpose |
|------|---------|
| `.env` | Environment variables |
| `.env.local` | Local overrides |
| `.env.development` | Development config |
| `.nvmrc` | Node version |
| `.node-version` | Node version (alternative) |
| `.npmrc` | npm configuration |
| `.tool-versions` | asdf version manager |

복사 시 파일이 없으면 건너뛴다 (`cp ... 2>/dev/null || true`).

## 동작 규칙

### 반드시 수행
- 모든 명령 전에 환경 감지 (기본 모드 vs workspace 모드)
- 환경 파일 복사 + 빌드 도구 감지 후 의존성 설치 제안
- 워크트리 생성 후 `cd` 또는 포커스 전환
- 삭제 전 uncommitted changes + unpushed commits 확인 -> 경고 -> 사용자 확인
- 브랜치명은 사용자 입력 그대로 사용 (prefix 추가 금지)
- 워크트리 생성 후 verification: `git status` + `git worktree list`

### 금지 사항
- (Workspace 모드) `main/` 디렉토리 안에 워크트리 생성
- (기본 모드) 프로젝트 디렉토리 안에 워크트리 생성
- 사용자 확인 없이 `--force` 삭제
- orphaned 워크트리 방치
- create/switch/done/remove 후 포커스/cd 갱신 누락
- 워크트리 디렉토리 직접 `rm -rf` (반드시 `git worktree remove` 우선)
- `feat/` 등 prefix를 브랜치명에 임의 추가

## Safety

**Before removal, check:**
- No uncommitted changes in worktree
- No unpushed commits on branch
- Warn user if either condition exists
- Only use `--force` after explicit user confirmation

**Recovery:**
- Worktrees can be recovered with `git worktree add` if directory deleted manually
- Branches are not deleted unless explicitly requested
- Run `git worktree prune` after manual directory deletions

## Error Handling

| 상황 | 대응 |
|------|------|
| workspace도 git repo도 아님 | git 프로젝트에서 실행 안내 |
| 이미 workspace 구조 | `/worktree create <name>` 사용 안내 |
| 브랜치명 중복 | 기존 사용 / 다른 이름 / 기존 삭제 선택지 제공 |
| 워크트리 디렉토리 이미 존재 | `git worktree list`로 확인 -> orphan이면 삭제 확인 |
| 의존성 설치 실패 | 워크트리는 생성됨, 수동 해결 안내 |
| setup 중단 (Phase B) | `.git`은 원래 위치에 있으므로 프로젝트는 정상 |
| setup 중단 (Phase C) | `mv .git main/` 수동 실행 안내 |
| create 실패 (부분 생성) | `git worktree prune`으로 정리 |
| 디스크 공간 부족 | 사용자에게 정리 여부 확인 후 partial worktree cleanup |
| 워크트리 locked | `git worktree unlock` 시도 후 재시도 |
| Invalid name (공백 등) | 자동 sanitize 후 사용자에게 변경 안내 |

## Decision Matrix: Worktree vs Branch

| Situation | Use Worktree | Use Branch |
|-----------|--------------|------------|
| Working on two features simultaneously | YES | NO |
| Quick hotfix while mid-feature | YES | NO |
| Sequential feature development | NO | YES |
| Code review while continuing work | YES | NO |
| Different dependencies needed | YES | NO |
| Just want to save work in progress | NO | YES (stash or branch) |

**Rule of thumb:**
- **Parallel work** = worktree (isolated directories, no context switching)
- **Sequential work** = branch (single directory, normal git workflow)
- **Different dependencies** = worktree (each has own node_modules / build output)

## Permission 참고

이 스킬의 `allowed-tools`는 **스킬 실행 중에만** 유효하다. 워크트리 안에서 일반 개발(테스트, 빌드 등)을 할 때는 사용자의 `settings.json` permission이 적용된다.

**Note:** 이 스킬은 워크트리 관리만 담당한다. 커밋, 푸시 등은 `/commit`, `/pull-request` 등을 사용한다.
