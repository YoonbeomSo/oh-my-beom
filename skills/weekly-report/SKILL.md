---
name: weekly-report
version: 1.1.0
description: 주간보고를 Notion에 작성한다. 이전 주간보고 + TODO·배포 통합 트래커를 조합하여 새 주의 페이지를 생성한다. 식별자는 ~/.claude/weekly-report.settings.json에서 읽는다(없으면 자동 생성).
argument-hint: [기준일(YYYY-MM-DD, 생략 시 이번 주 목요일)]
allowed-tools:
  - mcp__claude_ai_Notion__notion-search
  - mcp__claude_ai_Notion__notion-fetch
  - mcp__claude_ai_Notion__notion-create-pages
  - mcp__claude_ai_Notion__notion-update-page
  - Bash(date:*)
  - Read
  - Write
  - AskUserQuestion
---

Notion 워크스페이스(`CFG.workspaceName`)의 주간보고 DB에 새 주의 보고서를 작성한다.

항상 한국어로 응답한다.

## 설정 식별자 (~/.claude/weekly-report.settings.json)

실값은 저장소 밖 설정 파일에서 읽는다. 공개 저장소에는 아래 키 이름과 형식만 기재.

| 설정 키 | 용도 | 표기 형식 |
|---|---|---|
| workspaceName | Notion 워크스페이스 표시명 | <워크스페이스명> |
| parentPageTitle | 부모 페이지 표시명 | <페이지명> |
| authorName | 주간보고 페이지 제목/검색에 쓰이는 작성자 표시명 | <작성자명> |
| weeklyReportCollectionId | 주간보고 DB 검색 | collection://<uuid> |
| weeklyReportDataSourceId | 주간보고 페이지 생성 parent | <uuid> |
| trackerCollectionId | TODO·배포 통합 트래커 검색 | collection://<uuid> |
| parentPageUrl | 부모 페이지 | https://www.notion.so/<id> |
| authorUserId | 작성자 user ID | <uuid> |

> **DB 구조 메모**: 과거에는 `🚀 배포 트래커`와 `✅ TODO`가 별도 DB(+ relation)였으나, 현재는 **`✅ TODO & 🚀 배포` 단일 DB**로 통합되었다. 한 행이 TODO이면서 배포일 수도 있으며, 노션에서는 뷰(view)로 구분한다. 따라서 `trackerCollectionId` 하나만 사용한다.

## 인자 처리

- 인자 없음: `date "+%Y-%m-%d"`로 오늘 날짜를 구한 뒤, 그 주의 **목요일** 날짜를 기준일로 사용한다.
- `YYYY-MM-DD` 인자: 해당 날짜를 기준일로 사용한다.

기준일을 `BASE_DATE`라 하자.
- 주 시작일 = `BASE_DATE` 기준 그 주 금요일의 7일 전 (= 지난 금요일)
- 주 종료일 = `BASE_DATE` 기준 그 주 목요일
- 다음 주 시작일 = 주 종료일 + 1
- 다음 주 종료일 = 주 종료일 + 7

예: 2026-05-14 (목) → This Week: 2026.05.08~2026.05.14 / Next Week: 2026.05.15~2026.05.21

## 통합 트래커 데이터 소스 스키마 (참고)

`trackerCollectionId`가 가리키는 `✅ TODO & 🚀 배포` 데이터 소스의 속성:

| 속성 | 타입 | 값 |
|---|---|---|
| `이름` | title | 항목 제목 |
| `상태` | select | 임시보류 / 할 일 / 진행 중 / 완료 🙌 / 보류 (TODO 진행 상태) |
| `배포 상태` | select | 시작 전 / 보류 / 진행 중 / 리뷰 중 / 승인 완료 / 배포 완료 |
| `배포일` | date | `date:배포일:start` |
| `배포 유형` | select | 메이저 / 마이너 / 픽스 |
| `날짜` | date | `date:날짜:start` (TODO 작업일) |
| `JIRA` | url | 이슈 링크 |
| `작성일시` | created_time | 자동 |

- **배포 항목**: `배포일`이 설정된 행 (배포 트래커 뷰 기준).
- **TODO 항목**: `상태`가 할 일 / 진행 중 / 보류 / 임시보류 인 행 (TODO 뷰 기준).
- 한 행이 `배포일`과 `상태`를 동시에 가질 수 있다.

## 절차

### Step 0: 설정 로드 (~/.claude/weekly-report.settings.json)

스킬 시작 시 **가장 먼저** 설정을 로드한다.

#### 0a. 파일 존재 확인 → 없으면 생성

`Read`로 `~/.claude/weekly-report.settings.json` 읽기를 시도한다. 파일이 없거나 내용이 비어 있으면 아래 골격으로 `Write`로 **새로 생성**한다.

```json
{
  "workspaceName": "",
  "parentPageTitle": "",
  "authorName": "",
  "weeklyReportCollectionId": "",
  "weeklyReportDataSourceId": "",
  "trackerCollectionId": "",
  "parentPageUrl": "",
  "authorUserId": ""
}
```

> **구버전 마이그레이션**: 기존 파일에 `deployTrackerCollectionId` / `todoCollectionId` 키가 남아 있으면 무시한다. 두 DB가 하나로 통합되었으므로 `trackerCollectionId`(통합 DB)만 사용한다. 값이 비어 있으면 0b에서 질문한다.

#### 0b. 누락 키 확인 → 빈 값만 1개씩 질문

각 키 중 값이 비어 있는 것만 `AskUserQuestion`으로 **한 번에 하나씩** 묻는다. 각 키의 응답을 받는 **즉시** `Write`로 설정 파일에 기록하고(일괄 아님), 다음 키로 넘어간다. 모두 채워져 있으면 질문 없이 진행.

질문 순서:
1. `workspaceName` — "Notion 워크스페이스 이름?" (예: `내 팀 개발`)
2. `parentPageTitle` — "주간보고 부모 페이지 표시명?" (예: `주간보고`)
3. `authorName` — "주간보고 페이지 제목에 쓸 작성자 이름?" (예: `<작성자명>`)
4. `weeklyReportCollectionId` — "주간보고 DB collection ID?" (예: `collection://<uuid>`)
5. `trackerCollectionId` — "TODO·배포 통합 트래커 collection ID?" (예: `collection://<uuid>`)
6. `weeklyReportDataSourceId` — "주간보고 페이지 생성용 data_source_id (UUID)?"
7. `parentPageUrl` — "부모 페이지 URL?" (예: `https://www.notion.so/<id>`)
8. `authorUserId` — "작성자 user ID (UUID)?"

이후 Step 1~5의 `CFG.<키>` 표기는 모두 Step 0에서 로드한 설정값으로 **치환**하여 사용한다. `CFG.<키>` 문자열을 그대로 API 호출에 전달하지 않는다.

> ⚠️ 이 파일은 **글로벌 `~/.claude/`에만** 저장한다. 플러그인 저장소는 공개이므로 실제 식별자를 코드/문서에 절대 적지 않는다.

### 1단계: 이전 주간보고 페치

주간보고 DB를 `notion-search`로 "주간보고_" + `CFG.authorName` 검색(data_source_url = `CFG.weeklyReportCollectionId`) 후 가장 최신(`BASE_DATE`보다 이전) 페이지를 찾고 `notion-fetch`로 내용을 가져온다. 이전 보고서의 "Next Week" 항목, "To-Do" 항목을 추출하여 이번 주 진행 컨텍스트로 활용한다.

### 2단계: 통합 트래커 조회 (배포 + TODO)

`notion-search` (data_source_url = `CFG.trackerCollectionId`)로 통합 트래커 페이지들을 수집한다. 이번 주 작업/이번~다음 주 배포 예정 위주로 가져오고, 각 페이지를 `notion-fetch`로 열어 `이름`·`배포일`·`배포 상태`·`배포 유형`·`상태`·`날짜`·`JIRA`를 확인한다. (단일 DB이므로 한 번의 검색으로 배포·TODO 항목을 함께 수집한 뒤 메모리에서 분류한다.)

수집 항목을 아래 기준으로 분류한다.

**This Week** (이번 주 완료/진행):
- `배포일`이 `주 시작일 ≤ 배포일 ≤ 주 종료일` 범위인 항목
- 또는 `배포 상태`가 진행 중 / 리뷰 중 / 승인 완료이며 이번 주 작업한 항목
- 또는 `상태`가 완료 🙌 이고 `날짜`가 이번 주인 TODO

**Next Week** (다음 주 예정):
- `배포일`이 `다음 주 시작일 ≤ 배포일 ≤ 다음 주 종료일` 범위인 항목
- 이전 보고서 "Next Week"에서 이월된 항목
- `상태`가 할 일 / 진행 중이며 `배포일`이 아직 없는 소규모 TODO → **배포일 없이** Next Week에 추가

**To-Do** (장기 / 일정 미정):
- 이전 보고서 To-Do 섹션의 장기 항목(예: 하네스 플러그인 개발, 크롤링 등)
- `배포 상태`가 시작 전 / 보류이거나 배포일정이 미정인 진행 중 항목

**중복 제거**: 한 행이 `배포일`과 `상태`를 동시에 가질 수 있으므로 동일 `이름`(또는 페이지 URL) 기준으로 한 번만 노출한다. `배포일`이 있으면 배포 항목으로 우선 분류하고 TODO 중복은 제거한다.

### 3단계: 페이지 생성

`notion-create-pages`로 주간보고 data source에 생성:

```json
{
  "parent": {"type": "data_source_id", "data_source_id": "<weeklyReportDataSourceId>"},
  "pages": [{
    "properties": {
      "Name": "<BASE_DATE> 주간보고_<CFG.authorName>",
      "date:작성 일시:start": "<BASE_DATE>",
      "date:작성 일시:is_datetime": 0,
      "작성자": "[\"<authorUserId>\"]"
    },
    "icon": "💻",
    "content": "<아래 템플릿>"
  }]
}
```

### 4단계: content 템플릿

```
## 🙆🏻‍♂️ This Week {color="blue"}
> <주 시작일>~<주 종료일>
- <항목><span color="blue"> - <배포 상태 또는 상태> |   <배포일> 배포</span>
- ...

## 🙋🏻‍♂️ Next Week {color="red"}
> <다음 주 시작일>~<다음 주 종료일>
- <항목><span color="blue"> - <배포 상태> |   <배포일> 배포</span>
- <소규모 TODO 항목><span color="blue"> - 할 일</span>
- ...

## ☑️ To-Do {color="orange"}
- <장기 To-Do 항목><span color="blue"> - 개발중 | 배포일정 미정</span>
- ...
<empty-block/>
```

날짜 포맷: `YYYY.MM.DD` (마침표 구분). 항목 텍스트의 `[`, `]`, `|`는 Notion Markdown에서 `\[`, `\]`, `\|`로 이스케이프한다.

### 5단계: 결과 보고

- 생성된 페이지 URL
- This Week / Next Week / To-Do 각 섹션의 항목 수
- 추가/제외 판단이 모호했던 항목이 있으면 보고하여 사용자가 손볼 수 있도록 한다

## 주의사항

- 페이지 생성 후 사용자 수정이 있을 수 있으므로, 추가 항목 요청 시 `notion-update-page`의 `update_content` 명령으로 정확한 `old_str`/`new_str` 페어를 만들어 부분 수정한다. 전체 `replace_content`는 사용자가 다듬은 부분이 사라지므로 금지.
- 중복 페이지 방지: 동일 기준일의 페이지가 이미 있으면 생성 전에 사용자에게 확인을 받는다.
- `작성자` 사용자 ID가 다른 사용자로 작성해야 하면 인자나 환경에서 받아 동적으로 처리한다 (현재 기본값은 설정 파일의 `authorUserId`).
- **공개 저장소 식별자 금지**: collection ID, data_source_id, user ID 등 실제 식별자를 이 파일(SKILL.md) 또는 저장소 내 어떤 파일에도 기재하지 않는다. 실값은 반드시 `~/.claude/weekly-report.settings.json`에만 보관한다.
