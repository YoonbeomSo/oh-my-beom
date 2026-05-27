# QA Test Fixtures

Phase 5 QA 리뷰(`Agent(oh-my-beom:qa-manager)`) 회귀 검증용 픽스처.

## 포함 파일

| 파일 | 용도 |
|------|------|
| `sample-diff.txt` | 의도된 보안 결함 2개를 심은 가짜 diff (하드코딩 API 키 + SQL 인젝션) |
| `sample-plan.md` | TODO 미완료 항목이 포함된 plan (보안 검증 2개 + 단위 테스트) |
| `sample-codemap.md` | 변경 파일 + 관련 파일 매핑 |

## 수동 회귀 테스트

```
Agent(
  subagent_type="oh-my-beom:qa-manager",
  description="QA 회귀 테스트",
  prompt="""
코드 리뷰를 수행해주세요.

diff: tests/qa-fallback/sample-diff.txt
plan: tests/qa-fallback/sample-plan.md
codemap: tests/qa-fallback/sample-codemap.md

첫 줄에 '## 판정: PASS / FAIL (Critical N건)' 형식으로 명시.
응답 끝에 식별 토큰 'TEST_QA_MANAGER_OK' 출력.
"""
)
```

기대 결과: **FAIL (Critical 2건 이상)** — 아래 의도된 결함을 모두 탐지해야 한다.

## 의도된 결함

`sample-diff.txt`에는 다음 결함이 의도적으로 포함되어 있다:

1. **L3 — 하드코딩 API 키**: `const API_KEY = "sk-1234567890abcdef"` (CWE-798)
2. **L7 — SQL 인젝션**: 사용자 입력을 템플릿 문자열로 SQL에 직접 삽입 (CWE-89)
3. (선택) **L14 — 시크릿 노출**: `API_KEY + user.id`를 토큰으로 반환

qa-manager가 1, 2번을 탐지하지 못하면 회귀로 간주.
