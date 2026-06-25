---
name: merge-request
version: 1.3.0
description: GitLab 저장소에서 커밋 히스토리로부터 제목과 본문을 자동 생성하여 MR 생성. target≠base 자동 정렬, 부수 변경 감지, cross-project 링크 정규화 포함.
argument-hint: [base-branch] [target-branch] [--verify]
allowed-tools:
  - Read
  - Bash(git log:*)
  - Bash(git diff:*)
  - Bash(git push:*)
  - Bash(git fetch:*)
  - Bash(git rebase:*)
  - Bash(git remote:*)
  - Bash(git branch:*)
  - Bash(git status:*)
  - Bash(git rev-parse:*)
  - Bash(git rev-list:*)
  - Bash(git config:*)
  - Bash(git update-index:*)
  - Bash(glab:*)
  - Bash(which:*)
  - Bash(brew install:*)
  - AskUserQuestion
---

현재 브랜치의 커밋 히스토리를 분석하여 GitLab Merge Request를 자동 생성한다. 단순 생성에 그치지 않고, 깨끗한 diff를 보장하기 위해 부수 변경 감지, target 정렬(rebase), cross-project 링크 정규화까지 자동 수행한다.

항상 한국어로 응답한다.

## Arguments

- `ARGS[0]` (optional): **베이스 브랜치** — 현재 feature 브랜치가 분기한 브랜치. 미지정 시 자동 감지:
  1. `git config branch.<current>.merge`로 upstream tracking 확인
  2. `git branch --list main master develop` 순으로 존재하는 브랜치 선택
  3. 하나도 없으면 사용자에게 직접 입력 요청
- `ARGS[1]` (optional): **MR target 브랜치** — 머지 대상. 미지정 시 base와 동일. 별도 지정하면 target 위로 자동 rebase 후 push (배포 흐름이 `feat → deploy/{date} → testjenkins`처럼 chain일 때 유용).
- `--verify` (optional, 위치 무관 플래그): 지정 시 Step 5의 빌드/테스트 검증을 실행한다. 미지정 시 Step 5 전체 스킵.

### 자율 실행 환경변수 (선택)

`/persist-beom` 등 자율 흐름에서 호출될 때 AskUserQuestion 빈도를 줄이는 override:
- `MR_AUTO_REBASE=1` — Step 4의 rebase 권유를 묻지 않고 자동 수행
- `MR_KEEP_SIDE_CHANGES=1` — Step 3의 부수 변경을 묻지 않고 그대로 포함 (description "부수 fix"에 자동 명시)
- `MR_FORCE_NEW=1` — 기존 MR이 있어도 묻지 않고 "업데이트" 동작

## 사전 확인 (Step 1 — 게이트, 반드시 순차 실행)

### 1-1. glab CLI 가용성
- `which glab`로 존재 확인.
- 없으면 AskUserQuestion — "glab CLI가 설치되어 있지 않습니다. 설치할까요?"
  - 예 → `brew install glab` (timeout 300000). 실패 시 즉시 종료.
  - 아니오 → "MR 생성을 건너뜁니다." 출력 후 즉시 종료.

### 1-2. origin remote가 GitLab인지
- `git remote get-url origin` 출력 검사.
- `gitlab` 문자열이 포함되어 있지 않으면 AskUserQuestion으로 확인 — "GitLab이 아닌 것 같습니다. 계속할까요?"
- GitHub 저장소라면 `/pull-request` 사용 안내 후 즉시 종료.

### 1-3. HTTP/HTTPS 자동 감지 (내부 GitLab 호환)
- `git remote get-url origin`의 prefix를 확인. SSH(`git@`) 형식이면 별도 처리 없이 hostname만 추출.
- HTTP 전용 GitLab 인스턴스가 있으므로, **이전 인증 실패 이력이 있거나 호스트가 사설망**이면 `--api-protocol http` 옵션을 안내한다.
- 새 인증 시 권장 명령:
  ```
  glab auth login --hostname <host> --api-protocol <http|https> --git-protocol ssh
  ```

### 1-4. glab 인증 상태
- `glab auth status --hostname <extracted-hostname>` 실행.
- 미인증/401/`Token was revoked` 이면 안내 후 즉시 종료:
  ```
  glab auth login --hostname <host> --api-protocol http --git-protocol ssh
  ```
- 토큰 scope에 `api`가 포함되어야 함을 안내 (description 갱신 등 write 작업 필요).

## 사전 확인 (Step 2 — Git 상태)

순차 검증:
- Git 저장소 / origin remote 존재
- `git rev-parse --abbrev-ref HEAD`로 현재 브랜치 확인. detached HEAD이면 즉시 종료.
- 현재 브랜치 ≠ 베이스 브랜치
- 베이스 브랜치명 검증: `^[a-zA-Z0-9._/-]+$`
- 베이스 대비 커밋이 1개 이상 있는지 (`git rev-list --count <base>..HEAD`)
- **미커밋 변경사항이 있으면 경고 + 진행 여부 확인** (커밋하지 않은 채 MR 생성하면 누락됨)

## 부수 변경 감지 (Step 3 — 깨끗한 MR을 위한 필수 단계)

베이스 브랜치 대비 `git diff <base>...HEAD --name-only`로 변경 파일 목록을 얻고, **본 작업과 무관해 보이는 파일**을 휴리스틱으로 감지한다.

### 감지 규칙
1. **권한만 변경된 파일** — `git diff <base>...HEAD --raw`로 `old mode → new mode`만 있고 내용 변화 없음.
   - 예: `gradlew`의 100644 ↔ 100755
   - 조치: **권한만 원복**은 `git update-index --chmod=<+x|-x> <file>` 한 줄로 수행. `git checkout -- <file>`은 호출하지 않는다 (두 명령을 같이 쓰면 chmod 결과가 덮어써짐).
2. **테스트 컴파일 fix 의심** — `*Test.java`가 기존 코드 생성자 시그니처 변경을 따라가는 mock 추가로 보이는 경우.
   - 의도된 테스트 작성과 자동 구분이 어려우므로 **자동 unstage 금지**. 항상 AskUserQuestion으로 사용자에게 확인.
   - 분리 권유 시: 별도 hotfix MR 분리 옵션 제시. PR에 남기는 경우 description "부수 fix" 섹션에 명시.
3. **IDE 메타데이터** — `.idea/`, `.vscode/`, `*.iml` 등.
   - 조치: 자동 unstage (사용자가 명시 추가했을 가능성은 낮음).
4. **dependency lockfile 변경** — `package-lock.json`/`yarn.lock`.
   - "무관 변경" 자동 판별은 신뢰도가 낮으므로 무조건 사용자에게 선택지 제시 (의도된 의존성 업데이트 vs 부수 갱신).

감지 결과를 표로 출력한 뒤:
- `MR_KEEP_SIDE_CHANGES=1`이면 묻지 않고 모두 포함 (description "부수 fix" 섹션에 자동 명시).
- 아니면 AskUserQuestion — "본 PR에 포함할까요?":
  - 모두 제거 (가장 깨끗) — 권장
  - 일부만 제거 (선택지 제시)
  - 그대로 유지 (description에 명시)

## 이슈 키 파싱

- 브랜치명에서 `[A-Z]+-[0-9]+` 패턴 추출.
- 미발견 시 AskUserQuestion (옵션: "건너뛰기").
- 이슈 키 발견 시 **"작업 배경" 섹션 첫 줄에만** 인용 블록으로 삽입한다. 이슈 트래커 호스트는 **저장소에 하드코딩하지 않는다** — 커밋 메시지/브랜치 컨텍스트에 `https://{host}/browse/{KEY}` 형태 URL이 이미 있으면 그 호스트로 마크다운 링크를 만들고, 호스트를 모르면 **이슈 키 텍스트만** 인용한다(링크 없음). 최상단 별도 노출은 하지 않는다 — 중복 표기 금지.

## Target ≠ Base 자동 정렬 (Step 4 — 핵심 신규 기능)

이번 스킬의 핵심 학습: **base(분기 시작점)와 target(머지 대상)이 다르면, MR diff에 target ↔ base 사이의 다른 PR들이 모두 끼어들어 부풀어 보임.**

### 흐름
1. ARGS[1] (target)이 지정되었거나, base와 target이 다르면:
   - `git fetch origin <target>` 실행
   - `git rev-list --count <target>..<base>` 와 `<base>..<target>` 비교
   - target이 base보다 N commits 앞서 있으면 (N > 0):
     - `MR_AUTO_REBASE=1`이면 묻지 않고 즉시 rebase.
     - 아니면 AskUserQuestion — "target이 base보다 N commits 앞서 있어 MR diff에 다른 PR이 포함될 수 있습니다. target 위로 rebase할까요?"
     - 권장: rebase (clean diff 보장)
     - 거부 시: 그대로 진행하되 경고
2. Rebase 수행:
   ```bash
   git fetch origin <target>
   git rebase origin/<target>
   ```
3. 충돌 발생 시:
   - 자동 `git rebase --abort` + 사용자에게 보고
   - 충돌 파일 목록 표시 후 수동 해결 안내
   - rebase 미적용 상태로 그대로 진행할지 확인

## 빌드/테스트 검증 (Step 5 — 선택)

`--verify` 플래그가 지정된 경우에만 실행:
- 프로젝트 타입 감지 (gradle/maven/npm/yarn 등)
- `./gradlew compileJava` 또는 `npm run build` 등 실행
- 실패 시 MR 생성 중단 (사용자 확인)
- 통과 시 description에 "빌드 검증 통과" 자동 추가

## MR 제목 생성

```bash
git log <target>..HEAD --oneline -n 50
```

- 커밋 1개 → 해당 제목을 그대로
- 여러 개 → 한국어 요약
- 50개 초과 → `--oneline` 요약으로 압축
- 포맷: `[ISSUE-KEY] 제목` 또는 `제목`
- 50자 이내

## MR 본문 생성

```bash
git log <target>..HEAD -n 50
git diff <target>...HEAD --stat
```

### 본문 구조

```markdown
## 작업 배경
이슈/문제/비즈니스 맥락. 이슈 키가 있으면 Jira/이슈트래커 인용 + 링크.

## 변경 사항
- 신규: 어떤 파일/기능을 추가했는지 (기능 단위 서술, 파일 나열 아님)
- 수정: 어떤 동작을 어떻게 변경했는지
- 부수 fix (있을 때만): 본 작업과 무관하지만 빌드 통과 위해 포함된 변경

## 영향 범위
이 변경이 다른 모듈/기능에 미칠 수 있는 영향, 격리 보장 방법(try/catch 등).

## 테스트
어떤 단위/통합 테스트를 추가/통과시켰는지. 실 환경 검증 결과가 있으면 명시.

## QA (있을 때)
Codex 등 자동 리뷰 결과를 표로 요약. 발견 사항과 처리 내역.

## 체크리스트
- [x] 단위 테스트 통과
- [x] 빌드 통과
- [ ] CI 통과 확인 (push 후)
- [ ] 운영팀 안내 (해당 시)
- 동적으로 변경 내용에 따라 항목 조정

## 참고 (선택)
- 동일 작업의 다른 프로젝트 MR — **반드시 cross-project 형식 사용**:
  - `[프로젝트명 !번호](http://<host>/<group>/<project>/-/merge_requests/<iid>)`
  - **GitLab short ref(`!1171`)는 같은 프로젝트에서만 작동.** nested group/타 프로젝트는 깨진다 — 항상 명시적 markdown URL을 쓸 것.
```

### 작성 규칙
1. 문장형 서술 (한국어). 체크리스트만 체크박스.
2. 작업 배경 ≠ 변경 사항. 배경은 "왜", 변경은 "무엇을".
3. 변경은 기능 단위. 파일명 나열 금지.
4. 영향 범위와 부수 fix는 리뷰어가 가장 먼저 보고 싶은 정보 — 누락 금지.
5. 코드 변경 이외의 부수 변경이 있으면 반드시 "부수 fix" 섹션에 분리 명시.

## MR 생성

1. **기존 MR 확인**: `glab mr view --output json 2>/dev/null`
   - 출력 JSON에서 `.iid`, `.web_url`을 파싱한다 (jq 또는 python).
   - 존재하면 URL 표시 + AskUserQuestion (단, `MR_FORCE_NEW=1`이면 자동 "업데이트"):
     - 업데이트: push 후 `glab mr update <iid> --description "$(/bin/cat ...)"`로 본문 갱신
     - 신규 생성: push 후 `glab mr create`
     - 취소: 종료
   - **description 갱신 시 cat은 `/bin/cat` 절대경로 사용** — cd 후 PATH 깨질 수 있음.
2. **브랜치 푸시**:
   ```bash
   git push -u origin <branch-name>
   ```
   - rebase 후라면 `git push --force-with-lease` (충돌 시 거부, 안전)
   - timeout 120000
   - 실패 시 종료.
3. **MR 생성** (`--target-branch`는 ARGS[1] 또는 base):
   ```bash
   glab mr create --yes --target-branch <target> --title "<title>" --description "$(/bin/cat <<'EOF'
   ## 작업 배경
   ...
   EOF
   )"
   ```
   - `--yes`는 대화형 프롬프트 건너뛰기용 (예시에 반드시 포함).
   - 실패 시: "push는 완료, 수동 생성 필요" 안내 후 종료.
4. **MR URL 표시**.

## Post-create 검증 (Step 6)

MR 생성/갱신 후:
1. `glab mr view <iid> -F json` 으로 `changes_count` 확인.
2. base 대비 우리가 변경한 파일 수와 비교 — **차이가 5개 이상이면서 동시에 2배 이상**이면 target≠base 정렬이 안 됐을 가능성 → 경고 (작은 PR의 false positive 방지).
3. description 길이가 너무 짧으면(< 300 chars) commit 메시지만 fallback된 것 → 갱신 권유.
4. 동일 PR의 다른 프로젝트 MR이 description "참고"에 명시되어 있다면, 각 링크의 호스트/경로 형식이 올바른지 검증 (`[name](http://...)`).

## 오류 복구 가이드

- **rebase 충돌**: `git rebase --abort` 자동 실행 → 사용자 안내. MR은 미생성/미갱신 상태 유지.
- **push 거부 (--force-with-lease 실패)**: 원격에 누가 push했을 가능성. `git fetch` 후 사용자에게 어떻게 할지 묻기.
- **glab API 401**: 토큰 만료/revoke. `glab auth login` 재실행 안내.
- **HTTP 인증 실패 ("dial tcp ... connection refused")**: GitLab 인스턴스가 HTTPS 아닐 수 있음. `--api-protocol http`로 재로그인 안내.
- **description 빈 값**: cat 경로 문제 가능성. `/bin/cat` 절대경로 사용 + 결과 길이 검증.

## 변경 이력

- **v1.3.0**:
  - **이슈 키 링크 생성 방식 변경** — `JIRA_BASE_URL` env 의존 제거. 커밋/브랜치 컨텍스트에 URL이 있으면 그 호스트로 링크 생성, 없으면 이슈 키 텍스트만 인용. 이슈 트래커 호스트 저장소 하드코딩 금지.
- **v1.2.0**:
  - **명령 충돌 수정** — Step 3-1의 `update-index --chmod` + `checkout --` 동시 사용 제거 (덮어쓰기 버그).
  - **`--verify` 플래그 정식화** — argument-hint와 Arguments 섹션에 명시.
  - **allowed-tools 좁힘** — `Write`/`Edit`/`git reset`/`git restore`/`git checkout`/`git pull` 제거 (스킬 본질과 무관).
  - **자율 흐름 호환** — `MR_AUTO_REBASE` / `MR_KEEP_SIDE_CHANGES` / `MR_FORCE_NEW` 환경변수로 AskUserQuestion 우회.
  - **이슈 키 중복 제거** — "작업 배경" 섹션 첫 줄에만 삽입.
  - **부수 변경 휴리스틱 약화** — 테스트 mock·lockfile 자동 판별 금지, 항상 사용자 확인.
  - **iid 파싱 경로 명시** — `glab mr view --output json`의 `.iid`·`.web_url`.
  - **`glab mr create --yes` 예시 일관성** — 명령 예시에 누락됐던 `--yes` 추가.
  - **Post-create 임계값** — "2배 이상" → "5개 차이 AND 2배 이상"으로 false positive 감소.
- **v1.1.0**: target/base 자동 정렬 (rebase), 부수 변경 감지, cross-project 링크 정규화, HTTP/HTTPS 자동 안내, Post-create 검증, `--verify` 옵션.
- **v1.0.0**: 초기 릴리스.
