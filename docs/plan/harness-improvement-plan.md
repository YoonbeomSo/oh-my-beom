# 하네스 구조 개선 계획

## 메타 정보
- 상태: COMPLETED
- 브랜치: refactor/beom-harness
- 생성일: 2026-03-31

## 배경: 주요 하네스 벤치마크

| 프로젝트 | Stars | 핵심 특징 | oh-my-beom과의 관계 |
|----------|-------|----------|-------------------|
| **claude-mem** | 43.7K | 세션 간 영속 메모리, Worker Service 아키텍처, Exit Code 전략 | 메모리 자동화 참고 |
| **claude-plugins-official** | 15.5K | Anthropic 공식 표준, Agent Hook (type: "agent"), skills/ 표준 | 구조적 정답 |
| **claude-hud** | 15.5K | 실시간 컨텍스트 모니터링 대시보드 | 관측성 참고 |
| **claude-octopus** | 2.2K | 멀티 AI 모델, Flow 기반 4단계 파이프라인, 50+ 스킬 | 오케스트레이션 비교 |
| **claude-code-harness** | 374 | 3-에이전트 v3, Worker worktree isolation, Effort 스코어링, Agent Memory | **가장 유사 — 직접 비교 대상** |
| **arscontexta** | 2.9K | Generator 패턴, Methodology 디렉토리, Health 스킬 | 지식 구조화 참고 |
| **claude-code-toolkit** | 286 | INDEX.json 카탈로그, 4-Reviewer, Error Learner, Knowledge Graduation | 학습 자동화 참고 |

## oh-my-beom이 이미 잘하는 것

| 항목 | 근거 |
|------|------|
| **적응형 팀 조합** | Light/Full/Hotfix 3단계. 대부분의 프로젝트는 고정 팀 |
| **단일 진입점 `/beom`** | octopus(47개 명령어), toolkit(120+ 스킬)과 비교하면 심플 |
| **역할 경계 명확화** | "한다/하지 않는다" 양면 정의. 다른 프로젝트에 이 수준은 드묾 |
| **정체 에스컬레이션** | SPINNING/NO_DRIFT/OSCILLATION/DIMINISHING_RETURNS 4패턴. 유일 |
| **비즈니스 정책 분석 `/lens`** | 기술 중심인 다른 프로젝트와 차별화 |
| **규모 적정성** | 23스킬/5에이전트. 과포화 없이 관리 가능 |

## 개선 항목

### Step 1: Agent Hook — Write/Edit 전 품질 게이트

**출처**: claude-plugins-official(hookify), claude-code-harness
**검증 수준**: Anthropic 공식 + 커뮤니티 양쪽에서 검증

coder가 Write/Edit 실행 전에 haiku 모델로 코드 품질을 자동 검사하는 훅.

**구현 범위:**
- `hooks/hooks.json`에 PreToolUse `Write|Edit` matcher 추가
- `hooks/code-quality-gate` 스크립트 생성 (type: "agent", model: haiku)
- 검사 항목: 시크릿 하드코딩, TODO 스텁 잔존, SQL 인젝션, 빈 catch 블록
- 발견 시 exit 2로 차단 + 수정 가이드 제공

**완료 기준:**
- [x] [TODO-1.1] hooks.json에 Write/Edit PreToolUse 훅 등록
- [x] [TODO-1.2] code-quality-gate 스크립트 작성 (정적 패턴 매칭 기반)
- [x] [TODO-1.3] 시크릿/TODO 스텁/보안 취약점 감지 규칙 정의
- [x] [TODO-1.4] tests/test-hooks.sh에 code-quality-gate 테스트 추가 (10개)

---

### Step 2: Error Learner — 실패 자동 학습

**출처**: claude-code-toolkit
**검증 수준**: 커뮤니티 검증

에러 발생 시 패턴을 자동 기록하여 반복 방지. rules/behavior.md §6(실패 대응)과 §7(피드백 반영)의 자동화 버전.

**구현 범위:**
- `hooks/hooks.json`에 PostToolUse `Bash` 실패 감지 훅 추가
- `hooks/error-learner` 스크립트 생성
- 에러 패턴을 `.dev/error-log.md`에 기록 (에러 메시지, 컨텍스트, 발생 시점)
- 동일 에러 2회 반복 시 `additionalContext`로 이전 해결 방법 주입
- 세션 종료 시 반복 에러 패턴을 MEMORY.md에 기록 제안

**완료 기준:**
- [x] [TODO-2.1] error-learner 훅 스크립트 작성
- [x] [TODO-2.2] hooks.json에 PostToolUse Bash 실패 감지 등록
- [x] [TODO-2.3] .dev/error-log.md 포맷 정의 (자동 생성)
- [x] [TODO-2.4] 동일 에러 반복 감지 로직 구현 (additionalContext 주입)
- [x] [TODO-2.5] tests/test-hooks.sh에 error-learner 테스트 추가 (2개)

---

### Step 3: Effort 스코어링 — 작업 복잡도 기반 리소스 배분

**출처**: claude-code-harness
**검증 수준**: 커뮤니티 검증

`/beom`이 팀 추천 시 effort level도 함께 결정. 단순 작업에 과도한 리소스 투입 방지.

**구현 범위:**
- `skills/beom/SKILL.md` Phase: setup의 "작업 분석 + 팀 추천" 단계 확장
- effort 3단계: low(단순 수정) / medium(기능 추가) / high(아키텍처 변경)
- effort별 차등 적용:
  - **low**: architect에게 설계 요약만 요청 (상세 설계서 생략)
  - **medium**: 현행 유지
  - **high**: architect에게 대안 비교 포함 상세 설계 요청, design-critic 자동 호출
- state.md에 `effort: low|medium|high` 필드 추가

**완료 기준:**
- [x] [TODO-3.1] beom SKILL.md setup Phase에 effort 판단 기준 추가
- [x] [TODO-3.2] effort별 Phase 분기 로직 정의 (설계/리뷰 차등)
- [x] [TODO-3.3] reference.md state.md 포맷에 effort 필드 추가
- [x] [TODO-3.4] AskUserQuestion 팀 추천 시 effort level 표시

---

### Step 4: Agent Memory — 작업 메트릭 기록 + 피드백 루프

**출처**: claude-code-harness
**검증 수준**: 커뮤니티 검증

각 에이전트 작업 완료 시 메트릭을 기록하여 다음 작업의 스코어링에 활용.

**구현 범위:**
- `.dev/agent-metrics.md`에 Phase별 메트릭 기록
  - effort_applied, turns_used, review_rounds, critical_count
- plan 파일 Phase 기록에 메트릭 섹션 추가
- 다음 `/beom` 실행 시 이전 메트릭을 참고하여 effort 스코어링 보정
- 패턴 감지: "이 프로젝트에서 architect 설계는 평균 1.5회 Q&A가 필요" 같은 학습

**완료 기준:**
- [x] [TODO-4.1] agent-metrics.md 포맷 정의
- [x] [TODO-4.2] beom SKILL.md 각 Phase 완료 시 메트릭 기록 지시 추가
- [x] [TODO-4.3] reference.md에 메트릭 포맷 문서화
- [x] [TODO-4.4] setup Phase에서 이전 메트릭 로드 + effort 보정 로직

---

### Step 5: Exit Code 체계화 — 훅 에러 분류

**출처**: claude-mem
**검증 수준**: 43K stars 프로젝트에서 검증

훅 에러를 3단계로 분류하여 안정성 확보.

**구현 범위:**
- 모든 훅 스크립트에 일관된 exit code 적용:
  - `0`: 성공 (정상 진행)
  - `1`: 비차단 에러 (경고 표시, 진행 허용)
  - `2`: 차단 에러 (진행 중단, 수정 요구)
- 현재 혼재된 패턴 정리 (task-verifier, idle-checker는 이미 0/2 사용 중)
- `hooks/README.md` 작성: 각 훅의 목적, 트리거, exit code 정의

**완료 기준:**
- [x] [TODO-5.1] 모든 훅 exit code 규약 정의 (0/1/2)
- [x] [TODO-5.2] hooks/README.md 작성 (exit code 규약 + 훅 목록 + 검사 항목)
- [x] [TODO-5.3] tests/test-hooks.sh에 hooks.json 구조 검증 테스트 추가 (8개)

---

### Step 6: Tampering Detector — 설정 파일 보호

**출처**: claude-code-harness
**검증 수준**: 커뮤니티 검증

에이전트가 플러그인 자체의 설정/훅/규칙 파일을 의도치 않게 수정하는 것을 감지.

**구현 범위:**
- `hooks/hooks.json`의 PreToolUse `Write|Edit` matcher 확장
- 보호 대상: `hooks/`, `rules/`, `config/`, `agents/`, `CLAUDE.md`, `.claude-plugin/`
- 감지 시 사용자에게 확인 요청 (차단은 아님, 의도적 수정은 허용)

**완료 기준:**
- [x] [TODO-6.1] code-quality-gate에 플러그인 파일 수정 감지 통합
- [x] [TODO-6.2] 보호 대상 경로 목록을 config.json에 정의 (protectedPluginPaths)
- [x] [TODO-6.3] 사용자 확인 메시지 설계 (permissionDecision: "ask")
- [x] [TODO-6.4] tests/test-hooks.sh에 탬퍼링 감지 테스트 추가
