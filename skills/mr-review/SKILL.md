---
name: mr-review
version: 1.0.0
description: Use when the user wants to handle/respond to code-review comments on a GitLab MR — "MR 리뷰 처리", "코드리뷰 확인하고 처리", "AI 리뷰 대응", "리뷰 코멘트 reply/resolve", "MR 스레드 정리". Fetches unresolved review discussions (incl. AI reviewer), asks the user how to handle each finding via AskUserQuestion, applies the decision, then replies to and resolves each thread. Never merges.
argument-hint: "[MR번호 | MR URL] - 생략 시 현재 브랜치의 열린 MR"
allowed-tools:
  - Read
  - Edit
  - Write
  - AskUserQuestion
  - Bash(glab:*)
  - Bash(git:*)
---

# mr-review

GitLab MR 코드리뷰 스레드 대응 스킬. 항상 한국어.
흐름: **① 미해결 리뷰 수집 → ② 처리방향 확인(AskUserQuestion) → ③ 처리 → ④ reply + resolve**

이미 올라간 MR에 달린 리뷰 코멘트(특히 자동 AI 리뷰: `hecto-ai-reviewer` 등)를 사람이 훑고 하나씩 응대하는 반복 작업을 대신한다. 코드 자체 품질검증(구현 직후 QA)이 아니라 **원격 리뷰 스레드 응대**가 목적이다.

## 사전 조건
- **MR이 있는 코드 repo 디렉토리에서 실행**한다.
- glab 인증: `glab auth status`. 사내 GitLab이면 호스트를 함께 지정한다(예: `GITLAB_HOST=<host> glab ...`). 호스트를 모르면 사용자에게 확인.
- glab api의 `projects/:id`는 현재 repo로 자동 치환된다.

## 0. 대상 MR 확정
- 인자에 URL/번호가 있으면 그 MR(`.../merge_requests/{iid}` → iid).
- 없으면 현재 브랜치의 MR: `glab mr view`(인자 없이) 또는 `glab mr list --source-branch <현재브랜치>`.
- 이후 `{iid}`로 참조.

## 1. 미해결 리뷰 스레드 수집
```bash
glab api "projects/:id/merge_requests/{iid}/discussions?per_page=100"
```
- 대상 = **`notes[0].resolvable == true` 이고 `resolved == false`** 인 스레드만(이미 resolve된 건 건너뛴다).
- 각 스레드에서 뽑을 것: `discussion_id`(=`id`), 첫 노트 `body`(지적), DiffNote면 `position`(파일·라인), 심각도 머리표(`🔴/🟠/🔵`).
- "AI 코드리뷰 요약" 성격 노트는 **집계용 정보** → 개별 지적이 아니므로 처리 대상에서 빼고, 지적 정리 후 마지막에 함께 resolve할지 사용자에게 확인.
- 수집 결과를 파일·심각도별 표로 먼저 보여준다(간결하게, 이모지 남발 금지).

## 2. 처리방향 확인 (AskUserQuestion)
- 각 지적마다 **① 지적 요약 ② 코드/근거를 본 판단(유효 / 오탐 / 이미 처리됨)** 을 붙인다. 추측 금지 — 확인 안 되면 그렇게 적는다.
- **AskUserQuestion**으로 스레드별 처리방향을 묻는다(한 번에 최대 4문항, 많으면 나눠서). 선택지:
  - **수정한다** — 코드에 반영 (유효하면 첫 번째·추천)
  - **반영 안 함** — 오탐/의도된 설계 (사유를 reply에 남김)
  - **이미 처리됨** — 다른 커밋·인덱스·설정으로 해소 (근거를 reply에 남김)
  - **보류** — 지금은 안 함 (스레드 열어둠)
- 지적이 많으면 확실한 것(CERTAIN)과 판단 필요(QUESTION)로 나눠 제시.

## 3. 답에 따라 처리
- **수정**: 작업 브랜치에서 최소 수정 → 빌드/테스트 → 커밋(브랜치 push로 MR 반영). 변경이 크면 계획을 먼저 제시하고 진행. 복잡한 수정은 `fix-beom`에 위임 가능.
- **이미 처리됨 / 반영 안 함 / 보류**: 코드 변경 없음.
- 처리 결과(수정 커밋 해시 / 미반영 사유 / 이미 처리된 근거)를 reply용으로 정리.

## 4. 스레드에 reply + resolve
**reply**(처리 결과를 공손·간결하게):
```bash
glab api --method POST \
  "projects/:id/merge_requests/{iid}/discussions/{discussion_id}/notes" \
  --raw-field body="$(cat <<'EOF'
처리 내용을 여기에. 예)
- 반영: 상수를 공유 클래스로 추출 (커밋 abcdef1).
- 확인 후 resolve합니다.
EOF
)"
```
**resolve**(reply 후):
```bash
glab api --method PUT \
  "projects/:id/merge_requests/{iid}/discussions/{discussion_id}?resolved=true"
```
- **resolve 대상**: 수정 완료 / 이미 처리됨 / (사용자와 합의된) 반영 안 함.
- **resolve 금지**: 보류 스레드는 열어둔다. 처리 없이 reply만으로 resolve하지 않는다.
- 마지막에 스레드별 reply/resolve 결과 + 남은 보류 항목을 사용자에게 보고.

## 절대 규칙
- **사용자 확인 없이 임의 resolve 금지.** AI 리뷰 오탐 마커(`<!-- ai-fp:... -->`)가 있어도 반드시 물어본다.
- **merge 금지.** 이 스킬은 리뷰 응대일 뿐 승인/머지가 아니다.
- 미처리 지적을 resolve로 덮지 않는다(추적성 훼손).
- 커밋 메시지·reply는 한국어, AI 관련 기록(Co-Authored-By 등)을 남기지 않는다.
