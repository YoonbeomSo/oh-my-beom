# Plan: fetch-elk-test 스킬 신규 생성

> ⛔ **폐기됨 (2026-06-04)** — 방향 전환으로 이 plan은 무효.
> 사유: "운영/테스트 두 스킬이 헷갈린다" → 별도 스킬 폐기, **fetch-elk 단일 스킬 환경 스위치**로 통합.
> 후속 plan: **`docs/plan/plan_fetch-elk-환경스위치.md`** 참조.

## 1. 목표 (한 줄)

기존 `fetch-elk` 스킬을 기반으로, **테스트/스테이징 ELK 클러스터 전용** 변형 스킬 `fetch-elk-test`를 신규 생성한다. 운영(real)과 분리된 테스트 환경만 조회하며, 접속 정보는 외부 설정 파일로 분리(하드코딩 금지), 읽기 전용 정책을 유지한다.

## 2. 배경 / 컨텍스트

- 기반: `skills/fetch-elk/SKILL.md` (312줄) — ES HTTP API 직접 호출. 인덱스 디스커버리 → KST→UTC 시간창 검색 → 페이지네이션 → 에러/필드 패턴 추출. 읽기 전용(`_search/_count/_cat/*/_mapping/_msearch` 만).
- 핵심 기술 사실: fetch-elk 설정 스키마가 **이미 `default` + `environments` 구조로 다중 환경을 지원**한다. 즉 `environments.test` 키 추가만으로 테스트 환경 표현이 구조상 가능하다 — 이 사실이 설계 분기(아래 Q1)의 근거다.
- 정책(CLAUDE.md / fetch-elk 계승): 접속 정보 하드코딩 금지(공개 저장소 노출 0건), 읽기 전용 ES 호출만, `auth`는 `none` 고정.
- 선례: weekly-report가 사내 식별자를 `~/.claude/weekly-report.settings.json`으로 외부화. 동일 원칙 적용.

## 3. 요구사항

### 기능 요구사항
- [ ] `skills/fetch-elk-test/SKILL.md` 신규 생성 — fetch-elk의 조회 흐름(인덱스 디스커버리, 시간창 검색, 에러/필드 패턴 추출)을 계승.
- [ ] 접속 대상은 **테스트/스테이징 ELK**로 한정. 운영(real)과 명확히 분리.
- [ ] 접속 정보는 외부 설정 파일에서 로드(esUrl/kibanaUrl). 하드코딩 금지.
- [ ] 설정 파일 누락/빈 값 시 `AskUserQuestion`으로 한 번에 하나씩 질의 후 기록(fetch-elk와 동일 UX).
- [ ] 트리거 description을 운영용 fetch-elk와 구분하여 오발동 방지(Q2 참조).

### 정책/제약 (반드시 유지)
- [ ] 읽기 전용: `_search`, `_count`, `_cat/*`, `_mapping`, `_msearch` 외 호출(PUT/DELETE/POST 인덱스 작업) 절대 금지.
- [ ] `auth`는 `{"type":"none"}` 고정 — 인증 방식을 묻거나 바꾸지 않음.
- [ ] ES 주소/Kibana URL을 SKILL.md 본문·예시에 절대 적지 않음(공개 저장소 노출 0건). 예시는 `<TEST_ES_HOST>` 등 플레이스홀더만.
- [ ] frontmatter는 `name`/`description`만 사용(fetch-elk 패턴 일치).

### 검증 기준 (프로젝트 타입: 마크다운 스킬, 컴파일/테스트 프레임워크 없음)
- [ ] frontmatter 유효성(name/description 존재, YAML 파싱 통과).
- [ ] 스킬 자동발견(skills/ 하위 디렉토리 + SKILL.md 구조).
- [ ] **트리거 충돌 점검**: fetch-elk와 fetch-elk-test가 동일 입력에 동시 반응하지 않음(description 키워드 분리 확인).
- [ ] **접속정보 노출 0건**: SKILL.md 전체에서 실제 호스트/IP/도메인 grep 0건.
- [ ] **읽기전용 정책 유지**: 본문에 쓰기 호출 예시 없음, 금지 규칙 명시.
- [ ] **doc-sync(HTML) 동기화**: `docs/show/harness-architecture.html` 동반 갱신(아래 5절).
- [ ] **버전 동기화**: package.json / plugin.json / marketplace.json 3파일 일치(2.19.0 → 2.20.0 minor 확정).

## 4. 설계 결정 (확정 — 사용자 판단 반영)

> 2026-06-04 사용자 판단으로 아래 3건 모두 **확정**. architect는 이 결정을 전제로 설계한다(재논의 불필요).

### D1. 설정 파일 전략 = (A) 별도 파일 `~/.claude/elk-test.settings.json` **[확정]**

- 운영(`~/.claude/elk.settings.json`)과 **물리적으로 분리**한다. 두 스킬은 서로 다른 파일을 읽으며, fetch-elk-test는 운영 파일을 절대 참조하지 않는다(오접속 위험 0).
- 스키마는 fetch-elk와 동일하게 `default` + `environments` 구조를 유지하되, `default`를 `"test"`로 둔다. `auth`는 `{"type":"none"}` 고정.
- 파일 없으면 Step 1a대로 골격 생성, `esUrl`/`kibanaUrl` 빈 값은 1b에서 `AskUserQuestion` 1개씩 질의 후 기록.

  ```json
  {
    "default": "test",
    "environments": {
      "test": {
        "esUrl": "http://<TEST_ES_HOST>:9200",
        "kibanaUrl": "https://<TEST_KIBANA_HOST>",
        "auth": { "type": "none" }
      }
    }
  }
  ```

### D2. 트리거 충돌 방지 = 권장안 확정 **[확정]**

- fetch-elk-test description은 **테스트/스테이징을 명시한 신호에만** 반응하도록 한정: "테스트 ELK", "스테이징 로그", "test ELK", "staging", "테스트 환경 로그 조회", `test-elk.*` / `staging-elk.*` 류 URL 등.
- description **첫 문장에 "테스트/스테이징 ELK 전용 — 운영은 fetch-elk 사용"** 을 명시.
- 환경 불명 일반 키워드("ELK", "로그 조회")만 들어오면 **운영(fetch-elk)이 기본**. 테스트는 명시적 신호가 있어야 발동.
- **fetch-elk 본문은 수정하지 않는다**(외과적 변경 원칙). 분리는 fetch-elk-test description의 명시성만으로 달성한다.

### D3. 본문 중복 범위 = (A) 전체 자기완결 복제 후 환경 부분만 차등 **[확정]**

- Claude Code 스킬은 개별 로드되어 상호 참조가 런타임에 보장되지 않으므로 **자기완결 복제**한다(다른 SKILL.md 참조 금지).
- **환경 부분만 차등**:
  - 설정 로드(Step 1) — 파일 경로(`elk-test.settings.json`)/`default`(`"test"`)/질문 문구를 테스트용으로 교체.
  - 인덱스 패턴 예시(Step 2) — 테스트 환경 인덱스가 다를 수 있으니 "참고용·실제는 항상 `_cat/indices` 확인"을 더 강하게.
- **그대로 계승**: 시간창(KST→UTC, 월 rotation), search_after 페이지네이션, 정규식/필드 추출, 집계/교차검증, 에러처리, Common Mistakes.

## 5. doc-sync (HTML) 동기화 대상 — `docs/show/harness-architecture.html`

doc-sync-check 훅이 skills/ 추가 시 HTML 동반 stage를 강제한다. 확인된 변경 지점:
- L572: `<h2>Utility Skills (14)</h2>` → **(15)** 로 카운트 증가.
- L594 부근(fetch-elk 카드 다음): `/fetch-elk-test` skill-card 추가 (badge: 외부 연동).
- L990 부근 디렉토리 트리: `fetch-elk-test/` 항목 추가 (주석: 테스트/스테이징 ELK 로그 조회, 읽기 전용).

## 6. 버전 범프

- `/version-bump` 스킬로 3파일 동기화: `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.
- 현재 2.19.0 → 신규 스킬 추가이므로 **minor: 2.20.0 (확정)**.

## 7. TODO 리스트

> D1~D3 모두 확정 — architect는 설계 결정이 아니라 **확정 결정의 구현 설계**(영향 분석/구조)에 집중한다.

- [ ] **T1 (architect)** D1~D3 확정 전제로 구현 설계 — SKILL.md 섹션 구성, fetch-elk 본문 미수정 확인, 영향 범위(트리거 충돌/doc-sync/버전) 점검.
- [ ] **T2 (coder)** `skills/fetch-elk-test/SKILL.md` 생성:
  - frontmatter(name=`fetch-elk-test`, description 첫 문장에 "테스트/스테이징 ELK 전용 — 운영은 fetch-elk" 명시 — D2).
  - Step 1 설정 로드를 D1대로 별도 파일 `~/.claude/elk-test.settings.json` / `default:"test"`로 작성.
  - Step 2~7 + 에러처리 + Common Mistakes 자기완결 계승(D3 — 환경 부분만 차등).
  - 읽기 전용 규칙·접속정보 하드코딩 금지 규칙 명시.
- [ ] **T3 (coder)** `docs/show/harness-architecture.html` 동반 갱신(5절 3개 지점).
- [ ] **T4 (coder)** `/version-bump`로 2.20.0 동기화.
- [ ] **T5 (검증)** 검증 기준 6항목 점검(frontmatter, 트리거 충돌, 접속정보 노출 0건 grep, 읽기전용, doc-sync, 버전).
- [ ] **T6 (qa-manager)** QA 리뷰 — plan 완료 기준 대조, 정책(읽기전용/노출0/auth none) 검증.

## 8. 완료 기준 (Definition of Done)

1. `skills/fetch-elk-test/SKILL.md`가 frontmatter 유효 + 자기완결 + 테스트 전용으로 작성됨.
2. SKILL.md 전체에서 실제 ES 호스트/IP/도메인 노출 0건(grep 확인).
3. fetch-elk와 트리거 키워드가 분리되어 오발동 위험 제거.
4. 읽기 전용 + auth none 정책 본문에 명시.
5. `docs/show/harness-architecture.html` 3개 지점 동반 갱신.
6. 버전 2.20.0 3파일 동기화.
7. qa-manager QA 리뷰 통과(Critical 0).
