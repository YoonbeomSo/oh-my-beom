---
name: jira-api-handoff
description: 백엔드 API 변경사항을 프론트 개발자에게 넘기기 위해 Jira 이슈에 핸드오프 댓글을 작성/갱신한다. 신규/필드추가 색상 뱃지, 필드별 타입+설명, Swagger 딥링크, 공손한 말투로 ADF 댓글을 만든다. "API 변경 프론트한테 넘겨줘", "Jira에 백엔드 수정사항 댓글", "핸드오프 댓글" 등에 사용.
argument-hint: "[Jira URL 또는 이슈키] (선택: 변경 API 설명)"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(curl:*)
---

# Jira API Handoff Comment

## Overview

백엔드 API 변경(신규 API / 기존 응답 필드 추가)을 **프론트 개발자가 보기 좋게** Jira 이슈 댓글로 정리하는 스킬. 색상 상태 뱃지·필드별 타입·설명·Swagger 딥링크를 갖춘 **ADF 댓글**을 공손한 말투로 작성한다. 기존 핸드오프 댓글이 있으면 갱신한다.

항상 한국어로 응답한다.

## 의존 도구

공식 Atlassian MCP(`mcp__claude_ai_Atlassian__*`)가 세션에 로드되어 있어야 한다. 미연결 시 사용자에게 연결 안내 후 중단.
- `getJiraIssue` — 이슈 존재/제목 확인
- `addCommentToJiraIssue` — 댓글 작성(`commentId` 생략) 또는 갱신(`commentId` 지정), `contentFormat: "adf"`
- (보조) `getAccessibleAtlassianResources` — cloudId 못 찾을 때

## 입력

- `ARGS`: Jira URL(`*/browse/ISSUE-KEY`) 또는 이슈키(`[A-Z][A-Z0-9]+-[0-9]+`). 미지정 시 현재 브랜치명에서 이슈키 추출 시도, 실패하면 사용자에게 질문.
- 변경 API 목록: 사용자가 설명했거나, **현재 작업 브랜치의 diff/컨트롤러/DTO에서 자동 도출**한다.

## 절차

### 1. Jira 이슈 해석
- URL이면 호스트(`{site}.atlassian.net`)를 그대로 `cloudId`로 사용한다(별도 조회 불필요). 실패 시에만 `getAccessibleAtlassianResources`.
- `getJiraIssue(cloudId, issueIdOrKey, fields:[summary,status])`로 이슈 제목 확인 후 사용자에게 한 줄 보고.

### 2. 변경 API 식별 + 신규/필드추가 분류
- 근거: MR/브랜치 diff(`git diff <base>...HEAD`), 컨트롤러(`@GetMapping`/`@PostMapping`), DTO(`@Schema`).
- 분류:
  - **신규(green)**: 새 엔드포인트(컨트롤러에 신규 메서드).
  - **필드추가(blue)**: 기존 엔드포인트 응답 DTO에 필드만 추가.
- API별 수집: HTTP 메서드+경로, 추가/주요 응답 필드명, **각 필드의 타입(String/Long/Object/List 등)과 한국어 설명**(DTO `@Schema(description=...)` 또는 코드 맥락에서).
- 배열 필드는 항목 하위 필드를 한 단계 더 들여써서 기술.

### 3. Swagger 딥링크 산출 (tag + operationId)
- **가장 정확한 방법**: 서비스가 떠 있으면 OpenAPI 스펙에서 추출.
  ```bash
  curl -s "{SWAGGER_HOST}{contextPath}/v3/api-docs" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); \
      [print(p, m, o.get('tags'), o.get('operationId')) \
       for p,ms in d['paths'].items() for m,o in ms.items()]"
  ```
  - 서버 미가동 시: operationId = 컨트롤러 메서드명(기본), tag = 컨트롤러 클래스명 또는 springdoc 기본(`xxx-controller`). 불확실하면 사용자에게 확인.
- **딥링크 형식**: `{SWAGGER_HOST}{contextPath}/swagger-ui/index.html#/{tag}/{operationId}`
  - 예: `https://testapi.ttobakcare.com/store-mypage-v2/swagger-ui/index.html#/MySubscriptionController/morePayHistoryByYear`
- `SWAGGER_HOST`/`contextPath`는 사용자에게 확인하거나 프로젝트 설정(`application.yml` `server.servlet.context-path`)에서 읽는다. **localhost 링크는 프론트에게 무의미하므로 지양**하고 test 호스트를 쓴다(모르면 질문).

### 4. ADF 댓글 본문 작성
`contentFormat: "adf"`, `commentBody`는 ADF JSON 문자열. 아래 패턴을 그대로 사용한다.

**전체 구조**
```
doc
├─ heading(L3): "백엔드 수정사항 · {프로젝트명}"
├─ paragraph: 한 줄 요약 + "...Swagger 링크 참고 부탁드립니다."
├─ rule
├─ [신규 API들]  heading(L4: status뱃지+이름) → paragraph(설명+Swagger링크) → bulletList(필드)
├─ rule
├─ [필드추가 API들] 동일 구조
├─ rule
└─ paragraph: "확인 후 문의사항 있으시면 편하게 말씀 부탁드립니다."
```

**상태 뱃지(색상)**
```json
{"type":"status","attrs":{"text":"신규","color":"green"}}
{"type":"status","attrs":{"text":"필드추가","color":"blue"}}
```
heading 안에 뱃지+제목을 같이 넣는다:
```json
{"type":"heading","attrs":{"level":4},"content":[
  {"type":"status","attrs":{"text":"신규","color":"green"}},
  {"type":"text","text":" 회차별 실결제 내역 연도별 조회"}]}
```

**Swagger 링크(굵게)**
```json
{"type":"paragraph","content":[
  {"type":"text","text":"해당 연도 전체 결제내역을 최신순으로 반환합니다.  "},
  {"type":"text","text":"→ Swagger 바로가기","marks":[
    {"type":"link","attrs":{"href":"{딥링크}"}},{"type":"strong"}]}]}
```

**필드 항목(코드체 필드명 + 타입 + 설명)**
```json
{"type":"listItem","content":[{"type":"paragraph","content":[
  {"type":"text","text":"expireDate","marks":[{"type":"code"}]},
  {"type":"text","text":" (String) — 쿠폰 유효기간 마감일 (yyyy-MM-dd)"}]}]}
```

**배열 하위 필드(중첩 bulletList)**: listItem.content = [paragraph(목록 필드 설명), bulletList(항목 필드들)]

### 5. 작성/갱신
- 신규 작성: `addCommentToJiraIssue(cloudId, issueIdOrKey, contentFormat:"adf", commentBody)`
- 갱신: 같은 핸드오프 댓글을 고칠 때는 `commentId`를 함께 전달(전체 본문 교체 방식).
- 완료 후 `https://{site}.atlassian.net/browse/{KEY}` 링크와 요약 보고.

## 말투 규칙 (중요)

- **공손한 존댓말**: "참고 부탁드립니다", "~추가되었습니다", "~반환합니다". 명령형("참고하세요") 금지.
- 마무리 인사: "확인 후 문의사항 있으시면 편하게 말씀 부탁드립니다."
- **이모지 금지.** 시각 강조는 상태 뱃지(색상)와 `→`, 구분선, 코드체로 처리.
- **내부용 정보 제외**: MR 번호, "머지/배포 후 반영" 등 백엔드/배포 사정은 프론트 댓글에 적지 않는다(사용자가 명시 요청하면 예외).

## 작성 규칙

1. 신규 API는 주요 **응답 필드**를, 필드추가 API는 **추가된 필드**를 빠짐없이 나열한다.
2. 모든 필드에 **타입을 표기**한다(신규/필드추가 일관). 배열은 `(List)` + 항목 하위필드.
3. 헤더·요청 파라미터 등 Swagger에 이미 있는 디테일은 과하게 적지 않는다(링크로 대체).
4. 신규/필드추가를 그룹으로 묶고 구분선(rule)으로 나눈다.
5. 같은 이슈에 핸드오프 댓글이 이미 있으면 새로 달지 말고 `commentId`로 갱신한다.

## 주의사항

- cloudId는 사이트 호스트(`xxx.atlassian.net`)를 그대로 넘기면 대부분 동작한다.
- ADF JSON은 유효성이 엄격하다 — status/link/code 마크 구조를 위 패턴대로 유지.
- Swagger 딥링크의 `tag`는 springdoc 기본값이 컨트롤러마다 다를 수 있다(`MySubscriptionController` vs `subscription-controller`). 반드시 `/v3/api-docs`로 실제 값을 확인한다.
- 운영 이슈에 댓글을 다는 것은 외부 노출 행위이므로, 본문을 사용자에게 보여주고 확인받은 뒤 게시하는 것을 권장한다.
