---
name: pull-request
version: 1.0.0
description: 커밋 히스토리에서 제목과 본문을 자동 생성하여 PR 생성
argument-hint: [base-branch]
allowed-tools:
  - Read
  - Bash(git log:*)
  - Bash(git diff:*)
  - Bash(git push:*)
  - Bash(git remote:*)
  - Bash(git branch:*)
  - Bash(git status:*)
  - Bash(git rev-parse:*)
  - Bash(gh:*)
  - Bash(GH_HOST=github.com gh:*)
  - Bash(which:*)
  - Bash(brew install:*)
  - AskUserQuestion
---

현재 브랜치의 커밋 히스토리를 분석하여 PR을 자동 생성한다.

항상 한국어로 응답한다.

Arguments:
- ARGS[0] (optional): 베이스 브랜치. 미지정 시 자동 감지:
  1. `git branch --list main master develop`로 존재하는 브랜치 확인
  2. `main`이 존재하면 → 베이스로 자동 선택
  3. `main`이 없으면 → 존재하는 `master`/`develop`을 선택지로 사용자에게 제시. 하나도 없으면 직접 입력 요청

## 사전 확인 (반드시 순차 실행)

**Step 1** (게이트 — 반드시 순차 실행):

1. `which gh`로 gh CLI 존재 확인.
   - **없으면**: AskUserQuestion — "gh CLI가 설치되어 있지 않습니다. 설치할까요?"
     - 예 → `brew install gh` 실행 (`timeout: 300000`). 설치 실패 시 **즉시 종료**.
     - 아니오 → "PR 생성을 건너뜁니다." 출력 후 **즉시 종료**.

2. `gh auth status`로 인증 확인.
   - **미인증이면**: "gh 인증이 필요합니다. `gh auth login`을 실행하겠습니다." 안내 후 `gh auth login` 실행.
     - 인증 완료 → 다음 단계 진행.
     - 인증 실패/취소 → "PR 생성을 건너뜁니다." 출력 후 **즉시 종료**.

**Step 2**: 아래를 순차 확인:
- Git 저장소인지 확인
- `git rev-parse --abbrev-ref HEAD`로 현재 브랜치 확인 — detached HEAD이면 즉시 종료
- `git remote get-url origin`으로 origin remote 존재 확인 — 없으면 즉시 종료
- 베이스 브랜치명 검증: `^[a-zA-Z0-9._/-]+$` 패턴 매칭
- 현재 브랜치가 베이스 브랜치가 아닌지 확인
- 베이스 브랜치 대비 커밋이 있는지 확인
- 미커밋 변경사항이 있으면 경고하고 진행 여부 확인

## 이슈 키 파싱

- `git branch --show-current`로 브랜치명을 확인한다.
- 브랜치명에서 이슈 키 패턴 (`[A-Z]+-[0-9]+`)을 추출한다.
- 미발견 시: AskUserQuestion으로 입력을 요청한다. "건너뛰기 (이슈 키 없이 진행)" 옵션을 포함한다.

## PR 제목 생성

```bash
git log <base-branch>..HEAD --oneline -n 50
```

- 커밋 1개: 해당 커밋 제목을 PR 제목으로 사용
- 커밋 여러 개: 전체 변경을 한국어로 요약
- 커밋 50개 초과: `--oneline` 요약만으로 제목 생성
- 포맷: `[ISSUE-KEY] 제목` (이슈 키 있을 때) 또는 `제목`
- 50자 이내

## PR 본문 생성

```bash
git log <base-branch>..HEAD -n 50
git diff <base-branch>...HEAD --stat
```

커밋 메시지와 diff 통계를 분석하여 본문 작성.

```
## Background
이 변경이 필요한 배경을 설명한다. 어떤 문제가 있었는지, 비즈니스 맥락은 무엇인지를
리뷰어가 코드를 읽기 전에 이해할 수 있도록 자연스러운 문장으로 서술한다.

## Summary
이 PR에서 무엇을 했는지 요약한다. 핵심 접근 방식과 설계 판단을
간결한 문장으로 설명한다. 리뷰어가 diff를 열기 전에 전체 그림을 잡을 수 있어야 한다.

## Changes
구체적으로 무엇이 바뀌었는지를 기능 단위로 설명한다. 파일 단위가 아니라
"무엇을 왜 그렇게 바꿨는지"를 문장으로 풀어쓴다.

## Checklist
- [ ] 주요 기능이 로컬에서 정상 동작하는지 확인
- [ ] 기존 테스트가 통과하는지 확인
- [ ] (해당 시) 새로운 테스트를 추가했는지 확인
- [ ] (해당 시) 마이그레이션/설정 변경이 문서화되었는지 확인
```

**작성 규칙**:
1. **문장형 서술**: 모든 섹션은 자연스러운 한국어 문장으로 쓴다. 단, Checklist는 체크박스 형태.
2. **Background != Summary**: Background는 "왜(문제/맥락)", Summary는 "무엇을(해결책)".
3. **Changes는 기능 단위**: 파일명 나열이 아니라 기능 관점에서 서술.
4. **Checklist는 동적 생성**: 변경 내용에 따라 항목을 조정한다.

## PR 생성

1. 기존 PR 확인: `gh pr view --json url` — 이미 존재하면 URL을 표시하고 선택지 제시:
   - "업데이트": push 후 기존 PR 본문을 `gh pr edit`으로 갱신
   - "신규 생성": push 후 `gh pr create`
   - "취소": 스킬 종료
2. 브랜치 푸시: `git push -u origin <branch-name>` (`timeout: 120000`)
   - push 실패 시: 에러 표시 후 **즉시 종료**
3. PR 생성 (HEREDOC으로 body 전달):
   ```bash
   gh pr create --base <base-branch> --title "<title>" --body "$(cat <<'EOF'
   ## Background
   ...

   ## Summary
   ...

   ## Changes
   ...

   ## Checklist
   ...
   EOF
   )"
   ```
   - gh pr create 실패 시: "push는 완료되었으므로 수동으로 PR을 생성해주세요." 안내 후 **즉시 종료**.
4. PR URL을 사용자에게 표시
