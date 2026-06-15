---
name: branch-status
description: Use when user asks to see branch merge status across one or more git repos — "브랜치 merge 현황", "머지 현황", "브랜치 상황 표", "어느 브랜치까지 머지됐는지", "배포 브랜치 현황", "branch merge status/matrix". Renders a visual matrix table showing, per project, which target branches (deploy/*, testjenkins, test/dev, master) contain a tracked feature branch — merged ✅ / 미머지 ❌ / 없음 —. Supports a code-marker mode for toggle-style features (활성/비활성) where ancestry alone is misleading.
argument-hint: "[프로젝트경로...] [추적할 feature 브랜치]"
allowed-tools:
  - Read
  - Bash(git -C:*)
  - Bash(git fetch:*)
  - Bash(git ls-remote:*)
  - Bash(git for-each-ref:*)
  - Bash(git merge-base:*)
  - Bash(git show:*)
  - Bash(git rev-parse:*)
---

# Branch Status

여러 git 저장소의 **브랜치 merge 현황**을 하나의 시각적 매트릭스 표로 보여주는 skill.
프로젝트별로 "추적 대상(feature/작업 브랜치)이 어느 통합·배포 브랜치까지 들어가 있는가"를 한눈에 보여준다.

## When to Use

- "브랜치 merge 현황 보여줘", "머지 현황", "브랜치 상황 표"
- "어느 브랜치까지 머지됐어?", "배포 브랜치 현황 정리해줘"
- "이 작업이 master까지 갔어?", "testjenkins엔 들어갔어?"
- 여러 프로젝트의 배포/통합 브랜치 상태를 한 표로 비교하고 싶을 때

## 입력

| 항목 | 설명 | 기본값/추론 |
|------|------|------------|
| 프로젝트 | 대상 git 저장소 경로 목록 | 인자로 받거나, 대화 맥락에서 추론. 불명확하면 질문 |
| 추적 브랜치 | 머지 여부를 추적할 feature/작업 브랜치 | 인자로 받거나 맥락에서 추론 |
| 타깃 브랜치 | 머지 여부를 확인할 통합/배포 브랜치들 | **자동 탐지** (아래) |
| 코드 마커 | (선택) 토글형 기능의 활성 여부를 판정할 파일+정규식 | 명시 시에만 |

입력이 부족하면 추측하지 말고 `AskUserQuestion`으로 프로젝트 경로/추적 브랜치를 먼저 확인한다.

## 절차

### 1. 각 프로젝트 최신화

```bash
git -C "$DIR" fetch -q --prune origin 2>/dev/null
```

### 2. 타깃 브랜치 자동 탐지

프로젝트마다 통합 브랜치 이름이 다르므로(`test` vs `dev`) 존재하는 것만 고른다.

```bash
# 날짜형 배포 브랜치 (deploy/20260617, deploy/deploy_20260617 등 규칙 그대로)
git -C "$DIR" for-each-ref --format='%(refname:short)' refs/remotes/origin \
  | sed 's#origin/##' | grep -E '^deploy/' | sort
# 통합 브랜치: test 우선, 없으면 dev
git -C "$DIR" ls-remote --heads origin test | grep -q test && echo test || \
  { git -C "$DIR" ls-remote --heads origin dev | grep -q dev && echo dev; }
```

기본 타깃 컬럼 순서(존재하는 것만): `testjenkins` → 최신 날짜 배포 브랜치 → `test`(또는 `dev`) → `master`.
사용자가 특정 배포일(예: 6/17)을 지정하면 해당 배포 브랜치를 컬럼에 포함한다.

### 3. 머지 상태 판정 (2가지 모드)

**모드 A — ancestry (기본).** "추적 브랜치가 타깃에 머지됐는가"
```bash
git -C "$DIR" ls-remote --heads origin "$TARGET" | grep -q "$TARGET" || { echo "—없음"; }
git -C "$DIR" merge-base --is-ancestor "origin/$FEATURE" "origin/$TARGET" \
  && echo "✅ 머지" || echo "❌ 미머지"
```

**모드 B — 코드 마커 (토글형 기능).** 머지 후 되돌린(revert/재비활성) 경우 ancestry는 "머지됨"으로 나와 오해를 부른다. 기능의 **현재 활성 상태**가 중요하면 파일 내용으로 판정한다.
```bash
c=$(git -C "$DIR" show "origin/$TARGET:$FILE" 2>/dev/null)
echo "$c" | grep -qE "$INACTIVE_REGEX" && echo "🔴 비활성" \
  || { [ -n "$c" ] && echo "🟢 활성" || echo "— 없음"; }
```
- 토글/플래그/주석처리로 켜고 끄는 기능은 **모드 B 권장**. ancestry만 믿지 말 것.

### 4. 표 렌더링

GitHub-flavored markdown 표로 출력한다. 행 = 프로젝트, 열 = (개발 브랜치 이름) + 타깃 브랜치별 상태 + (선택) 비고.

```markdown
| 프로젝트 | 개발 브랜치 | testjenkins | <배포브랜치> | test/dev | master |
|---|---|---|---|---|---|
| proj-a | `feat/foo` | ✅ 머지 | ✅ 머지 | ❌ 미머지 | ❌ 미머지 |
| proj-b | `feat/foo` | 🟢 활성 | 🟢 활성 | 🟢 활성 | 🔴 비활성 |
```

표 아래에 **요약 한두 줄**(예: "master 미반영: proj-a, proj-c") 과 통합 브랜치가 `test`가 아닌 프로젝트(예: `dev`)는 각주로 명시한다.

## 출력 규칙

- 상태 아이콘 통일: `✅ 머지` / `❌ 미머지` / `🟢 활성` / `🔴 비활성` / `— 없음`.
- 브랜치명은 인라인 코드(`` `feat/...` ``)로.
- 한 프로젝트에 추적 브랜치가 여러 개면 셀에 `+`로 나열.
- origin 기준으로 판정한다(로컬 미push 상태가 섞이면 오해 발생). 필요 시 "origin 기준" 명시.

## Common Mistakes

- `git ls-remote --heads origin <branch>` 출력에 커밋 SHA가 포함되므로, 날짜/문자열 grep 시 **브랜치 이름만** 추출(`refname:short`)해서 매칭한다. SHA의 16진수에 우연히 숫자가 맞아 오탐난다.
- 통합 브랜치를 `test`로 고정하지 말 것 — 없으면 `dev`를 쓰는 저장소가 있다.
- 토글형 기능은 ancestry(모드 A)만으로 판정하면 "머지 후 되돌림"을 놓친다 → 모드 B로 교차 검증.
- 비활성화/disable 전용 브랜치(예: `hotfix/*_disable`)는 추적 대상에서 제외하거나 별도 표기.
