# QA Fallback Test Fixtures

Phase 5 QA 디스패처 회귀 검증용 픽스처.

## 포함 파일

| 파일 | 용도 |
|------|------|
| `sample-diff.txt` | 의도된 보안 결함 2개를 심은 가짜 diff (하드코딩 API 키 + SQL 인젝션) |
| `sample-plan.md` | TODO 미완료 항목이 포함된 plan (보안 검증 2개 + 단위 테스트) |
| `sample-codemap.md` | 변경 파일 + 관련 파일 매핑 |

## 검증 대상 (Phase 5의 4-tier 디스패처)

| Tier | 호출 방식 | 검증 결과 (2026-04-29) |
|------|---------|------------------------|
| A | cmux 분할 surface + `codex exec` | ✅ Critical 3건 탐지 (15,536 tokens / 32s) |
| B | tmux 분할 pane + `codex exec` | (미검증) |
| C | `Agent(codex:codex-rescue)` 백그라운드 | ✅ Critical 2건 탐지 (16,551 tokens / 55s) |
| D | `Agent(oh-my-beom:qa-manager)` Sonnet fallback | ✅ Critical 2건 탐지 (11,750 tokens / 24s) |

## 수동 회귀 테스트 실행 방법

각 Tier의 호출 형식은 `skills/dev-beom/SKILL.md`의 "Phase 5 QA 호출 디스패처" 섹션 참조. 픽스처 경로는 절대경로로 전달:

- diff: `/Users/.../oh-my-beom/tests/qa-fallback/sample-diff.txt`
- plan: `/Users/.../oh-my-beom/tests/qa-fallback/sample-plan.md`
- codemap: `/Users/.../oh-my-beom/tests/qa-fallback/sample-codemap.md`

각 호출의 응답 끝에 식별 토큰을 추가 요청하면 자동 검증 가능 (`TEST_AGENT_QA_MANAGER_OK`, `TEST_CODEX_RESCUE_OK`, `TEST_CMUX_CODEX_OK` 등).

## 의도된 결함

`sample-diff.txt`에는 다음 결함이 의도적으로 포함되어 있다:

1. **L3 — 하드코딩 API 키**: `const API_KEY = "sk-1234567890abcdef"` (CWE-798)
2. **L7 — SQL 인젝션**: 사용자 입력을 템플릿 문자열로 SQL에 직접 삽입 (CWE-89)
3. (선택) **L14 — 시크릿 노출**: `API_KEY + user.id`를 토큰으로 반환 (Codex가 발견한 추가 결함)

QA 엔진이 위 결함을 탐지하지 못하면 회귀로 간주.
