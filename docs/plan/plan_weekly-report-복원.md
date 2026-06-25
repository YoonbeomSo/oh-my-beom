# plan_weekly-report 복원

> **상태: COMPLETED** — 커밋 `f091b51` (브랜치 `feat/restore-weekly-report-skill`), QA Round 2 PASS, v2.19.0. 결과: `docs/result/result_weekly-report-복원.md`

## 목표
유실된 `weekly-report` 스킬을 옛 캐시(`2.14.0`)에서 현재 저장소 `skills/weekly-report/SKILL.md`로 복원한다. 단순 복사가 아니라, 현재 환경(2.18.0)에서 식별자·도구·컨벤션이 유효한지 점검하고 보정한 뒤, 신규 스킬 추가에 맞춰 문서·버전을 동기화하는 것까지 포함한다.

## 확정된 결정 (사용자 판단 완료)
- **Q1 (data source ID 불일치) = 해소됨**: 외부화로 저장소에 실제 ID가 안 들어가므로 저장소 관점에서 불일치 자체가 사라진다. 라이브 Notion 조회 불필요. 단 설정 파일 키 설계 시 "검색용 collection ID"와 "페이지 생성용 data_source_id"가 별개 표현일 수 있으므로 두 용도를 구분하는 키로 설계한다 (원본의 검색용 collection ID vs 생성용 data_source_id 혼선 방지).
- **Q2 (식별자 노출) = 옵션 A 채택**: Notion data source ID 3개 + 부모 페이지 URL + 사용자 UUID를 **모두** 글로벌 설정 파일 `~/.claude/weekly-report.settings.json`으로 외부화한다. 공개 저장소 SKILL.md에는 실제 식별자를 일절 두지 않고, 키 이름/용도만 placeholder로 문서화한다. fetch-elk 선례를 따른다 (파일 없으면 자동 생성 + 누락 키를 사용자에게 하나씩 질의, 설정 파일은 저장소에 절대 커밋 안 함).
- **Q3 (버전) = minor 확정**: 2.18.0 → 2.19.0.

## 배경
- 이 스킬은 2.14.0 시점 로컬에서 작성됐으나 git에 커밋된 적이 없어 유실됨.
- 유일한 원본: `~/.claude/plugins/cache/syb1224/oh-my-beom/2.14.0/skills/weekly-report/SKILL.md` (116줄, version 1.0.0).
- 복원 대상: `skills/weekly-report/SKILL.md`.
- 이 저장소는 공개(MIT) — 사내 식별자 노출 정책 판단이 핵심 쟁점.

## 요구사항
1. 캐시 원본의 기능(이전 주간보고 페치 → 배포 트래커 → TODO 보드 → Notion 페이지 생성)을 그대로 보존한다.
2. 현재 컨벤션(독립 유틸 스킬 frontmatter: name/version/description/argument-hint/allowed-tools)에 맞춘다 — 원본이 이미 이 형식이므로 큰 변경은 없을 것으로 예상.
3. allowed-tools의 MCP 도구명이 현재 환경에서 유효해야 한다.
4. data source ID 불일치를 해소하여 일관성을 확보한다.
5. 사내 식별자 노출 정책을 확정하고 그에 맞게 처리한다.
6. 신규 스킬 추가에 따른 문서 동기화(`docs/show/harness-architecture.html`)와 버전 범프(2.18.0 → 2.19.0)를 수행한다.

## 알려진 이슈 처리 (결정 반영)

### 이슈 1 — data source ID 불일치 (해소됨, 옵션 A로 자연 해소)
- **현상**: 원본 "고정 식별자" 섹션의 주간보고 data source는 `collection://<주간보고-collection-uuid>`인데, 4단계 페이지 생성 JSON의 `data_source_id`는 `<주간보고-datasource-uuid>`. 같은 "주간보고 data source"를 가리키는 두 값이 다름.
- **분석**: `collection://...` URL(검색용)과 `data_source_id`(UUID, 페이지 생성용)는 표기 형식이 다른 별개 표현일 수 있다. 두 용도가 실제로 같은 객체인지 여부와 무관하게, 옵션 A 외부화로 저장소에는 실제 값이 들어가지 않는다.
- **처리(확정)**: 라이브 Notion 조회는 하지 않는다. 대신 **설정 파일 키를 용도별로 분리**하여 혼선을 차단한다 — 검색용 collection ID와 페이지 생성용 data_source_id를 별개 키로 둔다 (예: `weeklyReportCollectionId` vs `weeklyReportDataSourceId`). architect/coder에게 이 키 분리 설계를 전달.

### 이슈 2 — 사내 식별자 노출 (옵션 A 채택, 전부 외부화)
- **현상**: Notion data source ID 3개(주간보고/배포 트래커/TODO), 부모 페이지 URL, 사용자 UUID가 SKILL.md에 하드코딩됨. 저장소는 공개(MIT).
- **선례**: `fetch-elk` 스킬은 사내 ES/Kibana URL을 코드에 박지 않고 글로벌 설정 파일(`~/.claude/elk.settings.json`)에서 읽으며, 파일이 없으면 자동 생성 + 누락 키를 `AskUserQuestion`으로 하나씩 질의하고, "공개 저장소에 사내 주소를 절대 적지 않는다"를 명시적 규칙으로 둔다.
- **처리(확정 — 옵션 A)**: 모든 식별자를 글로벌 설정 파일 `~/.claude/weekly-report.settings.json`으로 외부화한다.
  - SKILL.md에는 실제 식별자를 **일절** 두지 않고, 키 이름/용도만 placeholder(`<...>`)로 문서화한다.
  - 설정 파일은 사내 값을 담으므로 **저장소에 절대 커밋하지 않는다**(글로벌 `~/.claude/` 위치라 저장소와 무관). 저장소 안에는 example/스키마 문서만 둔다.
  - 스킬 시작 시 fetch-elk식 흐름: (1a) 파일 존재 확인 → 없으면 골격 생성, (1b) 누락 키만 `AskUserQuestion`으로 하나씩 질의 → 파일에 기록 → 진행.

### 이슈 3 — allowed-tools 유효성 (확인 완료 + 외부화 도구 추가)
- **현상**: 원본 allowed-tools = `mcp__claude_ai_Notion__notion-search`, `notion-fetch`, `notion-create-pages`, `notion-update-page`, `Bash(date:*)`.
- **확인 결과**: 현재 세션 deferred tool 목록에 `mcp__claude_ai_Notion__notion-search/-fetch/-create-pages/-update-page` 모두 존재 → **유효**. `Bash(date:*)`도 유효.
- **처리(확정)**: 기존 도구명 변경 불필요. 옵션 A 외부화로 설정 파일 읽기/생성 도구를 추가한다 — fetch-elk를 참고해 `Read`(설정 읽기), `Write`(파일 자동 생성), 필요 시 `Bash(cat:*)`를 allowed-tools에 보강. 누락 키 질의는 `AskUserQuestion`(기본 도구).

## TODO

- [x] **1. 설정 파일 키 설계 (옵션 A 핵심)** — `~/.claude/weekly-report.settings.json` 스키마 정의. 외부화할 값과 용도별 키:
  - [x] `weeklyReportCollectionId` — 주간보고 검색용 collection ID (`collection://<uuid>` 계열)
  - [x] `weeklyReportDataSourceId` — 주간보고 페이지 생성용 data_source_id (`<uuid>` 계열) — **검색용과 별개 키로 분리** (이슈 1 혼선 방지)
  - [x] `deployTrackerCollectionId` — 배포 트래커 검색용
  - [x] `todoCollectionId` — TODO 보드 검색용
  - [x] `parentPageUrl` — 부모 페이지 URL
  - [x] `authorUserId` — 작성자 user ID (다른 작성자면 동적 치환)
  - [x] fetch-elk 스키마 스타일(`default` + `environments`)을 따를지, 단일 평면 객체로 갈지 architect가 판단.
- [x] **2. 디렉토리 생성** — `skills/weekly-report/` 생성.
- [x] **3. SKILL.md 복원 작성** — 캐시 원본을 기반으로 작성하되 옵션 A 외부화 반영:
  - [x] frontmatter 현재 컨벤션 준수 (name/version/description/argument-hint/allowed-tools)
  - [x] version은 1.0.0 유지 (스킬 자체 첫 정식 버전)
  - [x] "고정 식별자" 섹션의 실제 ID/URL/UUID를 **모두 제거**하고, 설정 파일 키 이름 + placeholder(`<...>`)로 교체
  - [x] 스킬 시작부에 설정 로드 절차 추가 (fetch-elk식): 파일 존재 확인 → 없으면 골격 자동 생성, 누락 키만 `AskUserQuestion`으로 하나씩 질의 → 기록
  - [x] 4단계 페이지 생성 JSON의 `data_source_id`를 `weeklyReportDataSourceId` 설정값 참조로 교체 (검색용 collection ID와 혼용 금지)
  - [x] allowed-tools에 `Read`/`Write`(설정 읽기·자동생성), 필요 시 `Bash(cat:*)` 추가
  - [x] "공개 저장소에 사내 식별자 금지" 규칙을 본문에 명시 (fetch-elk처럼)
- [x] **4. 로컬 설정 파일 실값 생성** — `~/.claude/weekly-report.settings.json`에 원본 캐시의 실제 식별자를 채워 생성 (사용자가 바로 쓸 수 있도록). **저장소 밖 파일이라 커밋 대상 아님.**
- [x] **5. frontmatter 유효성 검증** — YAML 파싱·필수 필드·도구명 prefix 확인.
- [x] **6. 스킬 자동 발견 확인** — name/description으로 스킬 목록에 정상 노출되는지 점검.
- [x] **7. 문서 동기화** — `docs/show/harness-architecture.html`에 weekly-report 추가:
  - [x] `skill-card` div 추가 (fetch-elk 카드 형식 참고)
  - [x] 디렉토리 트리(`skills/` 하위)에 `weekly-report/` 항목 추가
  - [x] doc-sync-check 훅이 같은 커밋에 HTML stage를 강제하므로 누락 시 커밋 차단됨 — 반드시 동반 갱신.
- [x] **8. 버전 범프** — `/version-bump minor` 로 package.json + plugin.json + marketplace.json 2.18.0 → 2.19.0 동기화 (version-sync-check 훅이 3파일 일치 강제).
- [x] **9. QA 리뷰** — `Agent(oh-my-beom:qa-manager)` 호출. plan 완료 기준 대조 + **사내 식별자 노출 0건(grep으로 SKILL.md/HTML/plan 포함 모든 저장소 추적 파일에 실제 UUID·ID·URL 부재 확인 — `':!docs/plan/*'` 제외를 두지 않아 plan 파일도 검사 대상에 포함)** + 설정 키 용도 분리 + frontmatter 유효성 검증.
- [x] **10. 커밋** — `/commit` (작업 브랜치에서, main 직접 커밋 금지). pre-commit-build-check / version-sync-check / doc-sync-check 훅 통과 확인. 설정 파일(`~/.claude/...`)이 커밋에 포함되지 않았는지 확인.

## 완료 기준 (Definition of Done)
- `skills/weekly-report/SKILL.md`가 저장소에 존재하고 frontmatter가 유효하다.
- 스킬 자동 발견 목록에 weekly-report가 노출된다.
- SKILL.md/HTML/plan **포함 모든 저장소 추적 파일** 어디에도 실제 사내 식별자(Notion ID·부모 페이지 URL·사용자 UUID)가 없다 — placeholder/키 이름만 존재 (이슈 2 해소, grep 검증 시 `docs/plan/*` 제외 없이 plan 파일도 포함).
- 설정 파일 키가 검색용 collection ID와 생성용 data_source_id를 분리한다 (이슈 1 해소).
- `~/.claude/weekly-report.settings.json`이 실값으로 로컬 생성됐고, 커밋에는 포함되지 않는다.
- allowed-tools가 현재 환경에서 전부 유효하다 (Notion 4종 + Bash(date:*) + 설정 읽기/생성 도구) (이슈 3 해소).
- `docs/show/harness-architecture.html`에 weekly-report가 반영됐다.
- package.json/plugin.json/marketplace.json이 2.19.0으로 일치한다.
- QA 리뷰 Critical 0건.

## 리스크 / 주의
- **공개 저장소 노출 (최우선)**: 옵션 A로 외부화하므로 SKILL.md/HTML에 실제 식별자가 절대 들어가면 안 된다. 커밋 전 grep으로 실제 UUID·collection ID·부모 URL이 staged diff에 없는지 검증한다. 한 번 push되면 git 히스토리에서 지우기 어려움.
- **설정 파일 커밋 방지**: `~/.claude/weekly-report.settings.json`은 글로벌 위치라 저장소와 무관하지만, example 파일을 저장소에 둘 경우 실값이 섞이지 않도록 placeholder만 채운다.
- **ID 용도 혼선**: 검색용 collection ID와 페이지 생성용 data_source_id를 한 키로 합치지 않는다 (원본의 검색용 collection ID vs 생성용 data_source_id 불일치의 근본 원인).
- **doc-sync-check 차단**: HTML 미갱신 시 커밋이 막힘. SKIP_DOC_SYNC 우회는 사용하지 않고 정상 갱신.
- **버전 드리프트**: version-bump 스킬로만 범프 (3파일 수동 편집 금지).
- **보호 브랜치**: main에서 직접 작업 금지. 작업 브랜치 선행 생성.
