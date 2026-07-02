# result_weekly-report 복원

유실된 `weekly-report` 스킬을 캐시(2.14.0)에서 현재 저장소로 복원하고, 옵션 A(사내 식별자 전부 외부화)로 공개 노출을 차단한 뒤 v2.19.0으로 범프했다.

관련 plan: `docs/plan/plan_weekly-report-복원.md` (상태: COMPLETED)

## 결과 요약

- **상태**: 완료 (커밋됨, QA Round 2 PASS)
- **버전**: 2.18.0 → 2.19.0 (minor)
- **브랜치**: `feat/restore-weekly-report-skill`
- **커밋**: `f091b51` — "feat: weekly-report 스킬 복원 및 v2.19.0"

## 핵심 성과

1. **유실 스킬 복원** — git에 커밋된 적 없어 캐시에만 남아 있던 `weekly-report` 스킬을 `skills/weekly-report/SKILL.md`(159줄)로 정식 복원. 스킬 자동 발견 가능.
2. **사내 식별자 공개 노출 0건** — 옵션 A 채택. Notion data source ID 3개 + 부모 페이지 URL + 사용자 UUID를 모두 글로벌 설정 파일 `~/.claude/weekly-report.settings.json`으로 외부화. SKILL.md에는 placeholder/키 이름만 존재.
3. **추적 파일 전체 실값 0건 검증** — SKILL.md / HTML / plan을 포함한 모든 저장소 추적 파일에 실제 식별자 부재를 grep으로 확인.
4. **ID 용도 혼선 해소** — 원본의 검색용 collection ID vs 페이지 생성용 data_source_id 불일치를, 설정 파일에서 두 용도를 별개 키로 분리하는 설계로 근본 차단.
5. **문서·버전 동기화** — `docs/show/harness-architecture.html`에 weekly-report 반영(doc-sync-check 통과), 3개 버전 파일 2.19.0 일치(version-sync-check 통과).

## 변경 파일 (커밋 f091b51, 6개)

| 파일 | 변경 |
|------|------|
| `skills/weekly-report/SKILL.md` | 신규 (+159) — 외부화 절차 반영 복원본 |
| `docs/show/harness-architecture.html` | skill-card + 디렉토리 트리에 weekly-report 추가 |
| `package.json` | 2.18.0 → 2.19.0 |
| `.claude-plugin/plugin.json` | 2.18.0 → 2.19.0 |
| `.claude-plugin/marketplace.json` | 2.18.0 → 2.19.0 |
| `.gitignore` | 설정 파일 등 제외 항목 추가 |

> `~/.claude/weekly-report.settings.json`(실값)은 글로벌 위치라 저장소 밖 산출물 — 커밋 비대상.
> `docs/plan/`·`docs/result/` 산출물도 커밋 비대상.

## QA 이력

| 라운드 | 결과 | 내용 |
|--------|------|------|
| Round 1 | FAIL | Critical 1건(plan 파일에 사내 식별자 실값 노출), Warning 3건(SKILL.md 모호 흐름, DoD 스코프 누락 등) |
| Round 2 | PASS | 전부 해소 — plan 실값 placeholder 치환, DoD 스코프를 "추적 파일 전체"로 확장, 추적 파일 실값 0건 grep 검증 |

## 검증

- `git grep`으로 Notion data source ID 등 사내 식별자 검색 → `skills/`·`docs/show/`에서 실값 0건.
- 커밋 변경 파일 6개 = 보고된 목록과 일치. 버전 3파일 2.19.0 일치.
- 빌드/타입체크 없는 마크다운 기반 플러그인 — frontmatter 유효성·자동 발견·식별자 일관성·문서 동기화 중심 검증으로 충족.

## 후속 (사용자 액션)

- PR/MR은 자동 생성하지 않음. 필요 시 `/pull-request`로 사용자가 직접 생성·머지.
- 스킬 최초 실행 시 `~/.claude/weekly-report.settings.json`이 없으면 자동 생성되며 누락 키를 하나씩 질의. (team-lead가 복원 작업 중 실값으로 로컬 생성해 둔 경우 즉시 사용 가능.)
