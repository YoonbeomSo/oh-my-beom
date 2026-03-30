# web-test-qa 에이전트 + 테스트 스킬 구조

## 메타데이터
- 상태: IN_PROGRESS
- 생성일: 2026-03-30
- 브랜치: (미정)
- 베이스: main

## 배경
- 현재 playwright-tester + playwright-test-healer 2개 에이전트가 각각 테스트 생성/디버깅을 담당
- "playwright"라는 특정 도구에 종속된 네이밍과 구조
- 2개 에이전트를 1개(web-test-qa)로 통합하고, 기능별 스킬로 분리하여 에이전트가 호출하는 구조로 전환

## 목표
- web-test-qa 에이전트 1개가 E2E 테스트 전체 사이클을 관리
- 3개 스킬로 기능 분리: 계획 → 생성 → 수정
- /dev 파이프라인에서 기존과 동일하게 연동

## 기술 결정
| 결정 사항 | 선택 | 근거 |
|-----------|------|------|
| 에이전트 수 | 1개 (web-test-qa) | 테스트 컨텍스트를 하나의 에이전트가 유지 |
| 스킬 분리 기준 | 계획/생성/수정 | 각 역할이 독립적이고 순차적 |
| MCP 도구 배치 | 에이전트에 전체 도구 부여 | 스킬은 지시문, 도구는 에이전트가 실행 |

## 최종 구조

### web-test-qa 에이전트
- 기존 playwright-tester + playwright-test-healer의 모든 MCP 도구 보유
- Edit/Write 도구 포함 (테스트 코드 수정용)
- 3개 스킬을 순서대로 호출하여 E2E 테스트 사이클 수행

### 스킬 3개
| 스킬 | 역할 | 기존 출처 |
|------|------|---------|
| `/test-plan` | 인증 분석 + 브라우저 탐색 + 시나리오 설계 | playwright-tester Phase 1~2 |
| `/test-generate` | 시나리오 → .spec.ts 코드 생성 | playwright-tester Phase 3 |
| `/test-heal` | 테스트 실행 → 실패 분석 → 코드 수정 | playwright-test-healer 전체 |

### 실행 흐름
```
web-test-qa 에이전트
├── /test-plan 호출 → 시나리오 설계
├── /test-generate 호출 → 코드 생성
├── /test-heal 호출 → 실행 + 디버깅
└── 결과 보고 (통과/수정/fixme/미해결)
```

## 실행 단계

### Step 1: web-test-qa 에이전트 생성
- `agents/web-test-qa.md` 생성
- 기존 2개 에이전트의 MCP 도구 통합
- 완료 기준: [FILE_EXISTS] agents/web-test-qa.md

### Step 2: 3개 스킬 생성
- `skills/test-plan/SKILL.md` — playwright-tester Phase 1~2 로직
- `skills/test-generate/SKILL.md` — playwright-tester Phase 3 로직
- `skills/test-heal/SKILL.md` — playwright-test-healer 전체 로직
- 완료 기준: [FILE_EXISTS] skills/test-plan/SKILL.md, skills/test-generate/SKILL.md, skills/test-heal/SKILL.md

### Step 3: /dev SKILL.md에서 playwright 참조를 web-test-qa로 교체
- `Agent(subagent_type="playwright-tester")` → `Agent(subagent_type="web-test-qa")`
- `Agent(subagent_type="playwright-test-healer")` 호출 제거 (web-test-qa가 내부적으로 /test-heal 호출)
- 완료 기준: [GREP_MATCH] "web-test-qa" in skills/dev/SKILL.md

### Step 4: 기존 에이전트 제거 + README 업데이트
- `agents/playwright-tester.md` 삭제
- `agents/playwright-test-healer.md` 삭제
- README 반영

## 리스크
- [MCP 도구 누락] → 대응: 두 에이전트의 도구 목록을 합집합으로 통합
- [스킬 간 컨텍스트 전달] → 대응: 에이전트가 스킬 결과를 메모리에 유지하며 다음 스킬에 전달

## 변경 이력
- 2026-03-30 초기 계획 수립
