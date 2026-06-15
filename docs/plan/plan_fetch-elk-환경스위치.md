# Plan: fetch-elk 환경 스위치 통합 (운영/테스트 단일 스킬)

> **상태: ✅ COMPLETED (2026-06-08)**
> 커밋 `a875d19` · 브랜치 `feat/fetch-elk-test` · PR [#51](https://github.com/YoonbeomSo/oh-my-beom/pull/51) · v2.20.0
> QA: Round1 PASS(Warning 3) → 보완 → 최종 PASS(Critical 0·Warning 0)
> 결과 보고서: `docs/result/result_fetch-elk-환경스위치.md`

> 선행 plan `docs/plan/plan_fetch-elk-test-스킬생성.md`는 **폐기**됨. 본 plan이 유효.

## 1. 목표 (한 줄)

별도 `fetch-elk-test` 스킬을 폐기하고, **fetch-elk 하나로 운영(real)/테스트(test) 환경을 모두 처리**한다. 진입점을 단일화해 "어느 스킬을 호출할지" 혼란을 제거하고, 환경이 모호하면 **추측하지 않고 1회 되묻는다**. 기존 fetch-elk 조회 기능에는 **회귀가 없어야 한다.**

## 2. 배경 / 방향 전환 사유

- 사용자: "운영/테스트 두 스킬이 생기면 elk 조사 시 뭘 호출할지 헷갈린다." → 별도 스킬 폐기, 단일 스킬 + 환경 스위치 결정.
- 핵심 기술 사실: fetch-elk 설정 스키마(`skills/fetch-elk/SKILL.md` L82~99)가 **이미 `default` + `environments` 구조**라 환경 추가에 스키마 변경이 불필요. `environments`에 `real`/`test` 키만 두면 됨.
- 현재 작업 트리(확인됨):
  - `skills/fetch-elk-test/SKILL.md` (untracked) — 삭제 대상.
  - `docs/show/harness-architecture.html` (modified) — `Utility Skills (15)` / `/fetch-elk-test` 카드(L595) / 트리(L992) 추가됨 → 되돌리고 fetch-elk 카드 갱신.
  - 버전 3파일 (modified, 2.20.0) — **유지**(기능 추가 minor, 이미 적용).

## 3. 작업 범위

1. **폐기(삭제)**: `skills/fetch-elk-test/SKILL.md` + `skills/fetch-elk-test/` 디렉토리.
2. **수정**: `skills/fetch-elk/SKILL.md` — 환경 인식(real/test) 추가(아래 4절 요구사항).
3. **HTML 되돌리기 + 갱신**: `docs/show/harness-architecture.html`
   - `Utility Skills (15)` → **(14)** 원복 (L572).
   - `/fetch-elk-test` skill-card 제거 (L595).
   - 디렉토리 트리 `fetch-elk-test/` 항목 제거 (L992).
   - fetch-elk 카드 desc(L594)에 **"운영/테스트 환경 선택"** 반영 (doc-sync-check 충족: skills/fetch-elk 변경 시 HTML 동반 stage 필요).
4. **버전**: **2.20.0 유지**. 이미 3파일 적용됨, 추가 범프 없음.

## 4. 요구사항 (fetch-elk 수정)

### 4-1. 환경 결정 로직 (핵심)
- [ ] 호출 시 사용자 발화에서 환경을 추론한다.
  - **운영 신호** → `real`: "운영", "운영ELK", "real", "prod", "프로덕션", "라이브".
  - **테스트 신호** → `test`: "테스트", "스테이징", "staging", "test", `test-elk.*` / `staging-elk.*` 류 URL.
  - **모호** (환경 신호 없음, 예: "elk 조사해", "로그 조회") → **AskUserQuestion 1회로 '운영 / 테스트?' 되묻기.**
- [ ] **추측 금지·기본값 금지**: 모호할 때 운영을 기본 선택하지 않는다. 운영 오접속 방지를 위해 반드시 명시 선택을 받는다(되묻기 1회).
- [ ] 환경 결정 후 해당 env의 `esUrl`/`kibanaUrl`를 사용. 이후 흐름은 기존과 동일.

### 4-2. 설정 (`~/.claude/elk.settings.json`)
- [ ] `environments`에 `real` + `test` 두 환경을 둔다(스키마 변경 없음, 기존 default+environments 활용). 본문 스키마 예시에 `test` 항목 추가(플레이스홀더 `<TEST_ES_HOST>` 등).
- [ ] **선택된 환경의 필드 누락/빈 값** 처리: 기존 Step 1a(파일 생성)/1b(누락 필드만 `AskUserQuestion` 1개씩) 흐름을 **선택된 env 기준**으로 적용. 예: test 선택했는데 `environments.test.esUrl` 비었으면 test의 esUrl만 질의.
- [ ] `default` 의미 정리: 환경 결정 로직이 우선. `default`는 (구)단일환경 호환/되묻기 회피용 fallback이 아님 — 모호하면 되묻기가 우선이라는 점을 본문에 명시(default를 자동 선택 근거로 쓰지 않음).
- [ ] 로드 헬퍼(L101~113)는 "선택된 env"를 인자로 받도록 조정(하드코딩된 `default` 의존 제거 또는 선택 env 우선).

### 4-3. 정책 유지 (회귀 금지)
- [ ] 읽기 전용(`_search/_count/_cat/*/_mapping/_msearch` 외 금지) 유지.
- [ ] `auth` `{"type":"none"}` 고정 유지(real/test 모두).
- [ ] 접속정보 하드코딩 0건 유지(본문 실제 호스트/IP/도메인 노출 없음, 플레이스홀더만).
- [ ] **기존 조회 기능 회귀 없음**: 인덱스 발견(Step 2), KST→UTC 시간창(Step 3), 쿼리/페이지네이션(Step 4~5), 집계/교차검증(Step 6), 출력 저장(Step 7), 에러처리, Common Mistakes 모두 보존. 환경 결정 단계만 앞단에 추가.

## 5. 판단 항목 (architect 검토 — 권장안 포함)

> 방향은 확정(단일 스킬). 아래는 구현 디테일로, architect가 확정하고 coder가 따른다.

### J1. 환경 키워드 매핑 구체화
- 권장: real = {운영, 운영ELK, real, prod, 프로덕션, 라이브}, test = {테스트, 스테이징, staging, test, `test-elk.*`/`staging-elk.*` URL}. 그 외 = 되묻기.
- 검토: 영/한 혼용·대소문자 무시. URL이 환경을 명시하면 키워드보다 URL 우선.

### J2. 되묻기 UX (모호할 때)
- 권장: `AskUserQuestion` **1회**, 2지선다("운영(real)" / "테스트(test)"). **기본값 두지 않음** — 운영 오접속 방지를 위해 명시 선택 강제(사용자 핵심 요구).
- 검토: 한 번 선택 후 같은 세션 재질문 여부(현 plan은 호출당 1회 결정으로 단순화 권장).

### J3. test 환경 설정 누락 처리
- 권장: 선택된 env(여기선 test) 기준으로 기존 1a/1b 흐름 재사용 — test의 `esUrl`/`kibanaUrl` 누락분만 1개씩 질의 후 `environments.test`에 기록.
- 검토: real만 채워져 있고 test 호출 시, real 값으로 fallback 금지(혼선·오접속 방지). test 필드는 test로만 채운다.

## 6. doc-sync (HTML) — 되돌리기 + 갱신 (`docs/show/harness-architecture.html`)

확인된 변경 지점:
- L572: `<h2>Utility Skills (15)</h2>` → **(14)** 원복.
- L595: `/fetch-elk-test` skill-card **삭제**.
- L992: 디렉토리 트리 `fetch-elk-test/` 항목 **삭제**.
- L594: `/fetch-elk` 카드 desc에 "운영/테스트 환경 선택" 반영(예: "ELK/Elasticsearch 로그 조회·에러 패턴 추출 (운영/테스트 환경 선택, 읽기 전용)").

## 7. 버전

- **2.20.0 유지.** package.json / plugin.json / marketplace.json 이미 적용됨. 추가 version-bump 없음.

## 8. TODO 리스트

- [ ] **T1 (architect)** J1~J3 구현 디테일 확정 + fetch-elk 수정 설계(환경 결정 단계를 Step 1 앞단/내부 어디에 끼울지, 로드 헬퍼 시그니처, 회귀 영향 분석).
- [ ] **T2 (coder)** `skills/fetch-elk-test/` 삭제(SKILL.md + 디렉토리).
- [ ] **T3 (coder)** `skills/fetch-elk/SKILL.md` 수정:
  - 환경 결정 로직(J1) + 되묻기 UX(J2) 추가 — When to Use/Step 1 앞단.
  - 스키마 예시에 `test` 환경 추가, 로드 헬퍼를 "선택 env" 기준으로 조정.
  - 선택 env 누락 필드 1a/1b 질의(J3), default 자동선택 금지 명시.
  - 읽기전용/auth none/하드코딩 0건/기존 흐름 보존.
- [ ] **T4 (coder)** `docs/show/harness-architecture.html` 되돌리기+갱신(6절 4개 지점).
- [ ] **T5 (검증)** 점검:
  - fetch-elk-test 흔적 0건(skills/ grep, HTML grep).
  - 접속정보 노출 0건(SKILL.md grep 실제 호스트/IP).
  - 환경 모호 시 되묻기 명시·기본값 자동선택 없음.
  - 기존 조회 기능(Step 2~7/에러/Common Mistakes) 회귀 없음.
  - frontmatter 유효, 버전 2.20.0 3파일 일치.
- [ ] **T6 (qa-manager)** QA 리뷰 — plan 완료 기준 대조, 정책(읽기전용/노출0/auth none/되묻기) + 회귀 검증.

## 9. 완료 기준 (Definition of Done)

1. `skills/fetch-elk-test/` 완전 삭제(파일·디렉토리·HTML 흔적 0건).
2. `skills/fetch-elk/SKILL.md`가 real/test 환경 인식 + 모호 시 되묻기(기본값 없음)를 수행.
3. 선택 env의 누락 필드만 1a/1b로 질의, test 필드를 real로 fallback하지 않음.
4. 읽기전용 + auth none + 접속정보 노출 0건 유지.
5. 기존 조회 흐름(인덱스/시간창/쿼리/페이지네이션/집계/출력/에러) 회귀 없음.
6. `docs/show/harness-architecture.html`: Utility Skills (14) 원복, fetch-elk-test 카드/트리 제거, fetch-elk 카드 desc 갱신.
7. 버전 2.20.0 3파일 일치 유지.
8. qa-manager QA 리뷰 통과(Critical 0).
