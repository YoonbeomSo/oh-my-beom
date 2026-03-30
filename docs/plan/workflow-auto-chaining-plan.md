# 워크플로우 자동 체이닝 + 세션 시작 가이드

## 메타데이터
- 상태: IN_PROGRESS
- 생성일: 2026-03-30
- 브랜치: (미정)
- 베이스: main

## 배경
- 현재 각 스킬(lens, research, plan, dev)은 독립 실행이며, 완료 후 "다음 액션을 제안"만 함
- 사용자가 매번 수동으로 다음 스킬을 호출해야 하는 번거로움
- 세션 시작 시 활성 계획 감지만 하고, 새 작업에 대한 안내가 없음

## 목표
- 스킬 완료 후 자동으로 다음 스킬을 호출하는 체이닝 구현
- 세션 시작 시 작업 의도를 파악하고 시작 스킬을 추천하는 기능 추가
- README에 워크플로우 실행 구조 문서화

## 기술 결정
| 결정 사항 | 선택 | 근거 |
|-----------|------|------|
| 체이닝 구현 방식 | 각 스킬 SKILL.md에 자동 호출 지시 추가 | 별도 오케스트레이터 없이 기존 구조 활용, 최소 변경 |
| 체이닝 옵트아웃 | `--only` 플래그 | 독립 실행이 필요한 경우 대비 |
| plan→dev 전환 | 사용자 확인 후 진행 | plan은 리뷰가 필요하고 dev는 코드 변경이 큰 작업 |
| 세션 가이드 표시 조건 | 활성 계획이 없을 때만 | 활성 계획이 있으면 기존 동작(계획 진행 안내) 유지 |

## 최종 완료 기준
- [ ] [GREP_MATCH] "Skill tool" in skills/lens/SKILL.md
- [ ] [GREP_MATCH] "Skill tool" in skills/research/SKILL.md
- [ ] [GREP_MATCH] "Skill tool" in skills/plan/SKILL.md
- [ ] [GREP_MATCH] "WORKFLOW GUIDE" in hooks/session-start
- [ ] [GREP_MATCH] "자동 체이닝" in README.md
- [ ] [CRITERIA] session-start hook이 정상 실행됨 (exit 0)

## 실행 단계

### Step 1: 스킬 자동 체이닝 추가
상태: TODO

#### TODO 항목
- [ ] [TODO-1.1] lens SKILL.md에 자동 체이닝 섹션 추가
  - 완료 기준: [GREP_MATCH] "oh-my-beom:research" in skills/lens/SKILL.md
  - 검증 상태: PENDING
  - 비고: 파이프라인 연동 섹션 뒤에 추가. 완료 후 `/research` 자동 호출

- [ ] [TODO-1.2] research SKILL.md 다음 액션을 자동 체이닝으로 변경
  - 완료 기준: [GREP_MATCH] "oh-my-beom:plan" in skills/research/SKILL.md
  - 검증 상태: PENDING
  - 비고: 기존 "다음 액션을 제안하라" → 자동 호출로 변경

- [ ] [TODO-1.3] plan SKILL.md 다음 액션을 자동 체이닝으로 변경
  - 완료 기준: [GREP_MATCH] "oh-my-beom:dev" in skills/plan/SKILL.md
  - 검증 상태: PENDING
  - 비고: 사용자 확인 후 `/dev` 호출 (plan은 리뷰 필요)

#### Step 완료 기준
- [ ] [STEP-CRITERIA] 3개 스킬에 체이닝 지시가 추가됨

### Step 2: session-start hook 개선
상태: TODO

#### TODO 항목
- [ ] [TODO-2.1] 활성 계획 없을 때 워크플로우 가이드 컨텍스트 주입
  - 완료 기준: [GREP_MATCH] "WORKFLOW GUIDE" in hooks/session-start
  - 검증 상태: PENDING
  - 비고: 작업 의도 질문 + 상황별 시작 스킬 추천 테이블 주입

- [ ] [TODO-2.2] hook 실행 테스트
  - 완료 기준: [CRITERIA] `bash hooks/session-start` 실행 시 exit 0 + JSON 출력
  - 검증 상태: PENDING

#### Step 완료 기준
- [ ] [STEP-CRITERIA] session-start hook이 새 세션에서 가이드를 표시함

### Step 3: README 워크플로우 문서화
상태: TODO

#### TODO 항목
- [ ] [TODO-3.1] README에 자동 체이닝 워크플로우 섹션 추가
  - 완료 기준: [GREP_MATCH] "자동 체이닝" in README.md
  - 검증 상태: PENDING
  - 비고: 핵심 기능 섹션 내에 체이닝 흐름 + --only 옵트아웃 설명

#### Step 완료 기준
- [ ] [STEP-CRITERIA] README에 워크플로우 실행 방법이 문서화됨

## 리스크
- [체이닝이 무한루프 되는 경우] → 대응: 각 스킬은 한 번만 다음 스킬을 호출하며, dev는 터미널 스킬
- [사용자가 체이닝을 원하지 않는 경우] → 대응: `--only` 플래그로 옵트아웃

## 범위 외
- 체이닝 순서 커스터마이징 (config.json으로 설정 등)
- dev 스킬 완료 후 commit/PR 자동 실행

## 변경 이력
- 2026-03-30 초기 계획 수립
