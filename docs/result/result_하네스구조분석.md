# 분석 보고서: oh-my-beom 하네스 구조 허점 및 개선점

- 유형: 코드 분석
- 대상: oh-my-beom 플러그인 전체 하네스 (스킬 15개, 에이전트 4개, 훅 2개, 룰 2개, 설정 1개)
- 생성일: 2026-04-02

## 요약

하네스의 설계 철학(에이전트 분업, QA 루프, 문서 추적)은 견고하나, **운영 수준에서 14건의 허점**을 확인했다. 특히 안전장치(훅)의 커버리지 갭, 에이전트 통신의 강제성 부재, 실패 복구 메커니즘 미비가 주요 문제다.

---

## 분석 결과

### 1. 안전장치 허점 (HIGH ~ MEDIUM)

#### 1-1. git push 보호 부재 — HIGH

`pre-tool-guard`가 `git commit`만 감지하고, **`git push`는 보호하지 않는다.**

```
git commit -m "직접 커밋"   → 차단됨 ✓
git push origin main        → 차단 안 됨 ✗
```

- 위치: `hooks/pre-tool-guard` 라인 10-31 (`case "$INPUT" in *git*commit*`)
- 보호 브랜치(main/master/dev/test)로의 직접 push가 가능한 상태

**개선**: pre-tool-guard에 `*git*push*` 패턴 추가, 대상 브랜치가 보호 목록에 있으면 차단.

#### 1-2. code-quality-gate Bash 우회 — MEDIUM

Write/Edit 도구만 감시하므로, **Bash로 시크릿을 작성하면 우회된다.**

```
Bash: echo "API_KEY=sk-xxx" >> .env    → 감지 안 됨 ✗
Write: .env에 API_KEY=sk-xxx           → 감지됨 ✓
```

- 위치: `hooks/hooks.json` — `"matcher": "Write|Edit"`만 code-quality-gate 연동
- Bash 리다이렉트(`>`, `>>`)로 민감 파일 작성 시 무방비

**개선**: Bash matcher에도 시크릿 감지 훅 추가. 또는 기존 pre-tool-guard에 Bash 리다이렉트 패턴 감지 로직 통합.

#### 1-3. 파괴적 Git 명령어 미보호 — MEDIUM

`git reset --hard`, `git clean -f`, `git branch -D` 등에 대한 가드 없음.

**개선**: pre-tool-guard에 파괴적 명령 패턴 추가 (경고 또는 차단).

#### 1-4. 보호 브랜치 목록 중복 정의 — LOW

3곳 이상에서 각기 다르게 정의됨:
- `config.json`: `["main", "master", "develop", "test", "dev"]`
- `pre-tool-guard`: `^(develop|main|master|test|dev)$`
- `commit` 스킬: `master, main, dev, test` (develop 누락)
- `git-workflow.md`: 또 다른 목록

**개선**: 훅과 스킬이 `config.json`의 `protectedBranches`를 단일 소스로 참조.

---

### 2. 에이전트 통신 허점 (MEDIUM)

#### 2-1. contextLimits가 강제되지 않음

`config.json`에 에이전트별 입력 라인 제한이 정의되어 있지만, **실제로 읽거나 적용하는 코드가 없다.**

```json
"contextLimits": {
  "planner": { "maxInputLines": 800 },
  "architect": { "maxInputLines": 1500 },
  "coder": { "maxInputLines": 2000 },
  "reviewer": { "maxInputLines": 1500 }
}
```

- 오케스트레이터(dev-beom, fix-beom, persist-beom)에서 contextLimits 참조 없음
- 대규모 프로젝트에서 에이전트 context window 초과 위험

**개선**: 오케스트레이터 Phase에서 SendMessage 전에 config.json의 contextLimits를 읽고, 메시지를 해당 라인 수로 truncate하는 지침 추가.

#### 2-2. 에이전트 실패 시 복구 메커니즘 부재

SendMessage가 실패하거나 에이전트가 크래시하면 **전체 작업이 중단**된다. 재시도 로직, 부분 복구, fallback 경로가 없음.

**개선**: 오케스트레이터에 "SendMessage 실패 시" 섹션 추가 — 재시도 1회 → 실패 시 사용자에게 수동 개입 요청.

#### 2-3. 메시지 크기 제어 미흡

diff가 500줄 이상이면 `--stat`으로 대체하는 규칙은 있지만, 코드 맵이나 설계서 등 다른 입력에 대한 크기 제어는 없음.

---

### 3. 기능 누락 (HIGH ~ MEDIUM)

#### 3-1. 롤백 메커니즘 부재 — HIGH

QA 루프 5회 초과 시 이슈 보고서만 생성하고, **변경된 코드는 그대로 남는다.** 원래 상태로 되돌리는 옵션이 없음.

**개선**: QA 5회 초과 시 사용자에게 3가지 선택지 제시:
1. 변경 유지 + 이슈 보고 (현재 동작)
2. 변경 롤백 (`git checkout -- .` 또는 `git stash`)
3. 재설계 (architect 재호출)

#### 3-2. 동시 실행 방지 없음 — MEDIUM

같은 프로젝트에서 여러 오케스트레이터가 동시에 실행되면 `.dev/` 디렉토리 내 파일(codemap.md, diff.txt, design.md)이 충돌한다.

**개선**: Phase 1에서 `.dev/.lock` 파일로 동시 실행 감지. 이미 실행 중이면 경고 후 중단.

#### 3-3. 에이전트 타임아웃 처리 없음 — MEDIUM

SendMessage에 타임아웃 설정이 없어 에이전트 무응답 시 무한 대기 가능.

**개선**: config.json에 에이전트별 타임아웃 추가, 오케스트레이터에서 참조.

#### 3-4. plan 상태가 2가지뿐 — MEDIUM

`IN_PROGRESS`와 `COMPLETED`만 존재. 중간 중단, QA 5회 초과, 롤백 등의 상태를 표현할 수 없음.

**개선**:
```
PENDING → IN_PROGRESS → AWAITING_REVIEW → QA_LOOP → COMPLETED
                                              ↓
                                       ISSUE_REPORTED → ROLLED_BACK
```

---

### 4. 설정 활용도 문제 (MEDIUM ~ LOW)

#### 4-1. webTest.credentials 평문 저장 — HIGH

테스트 계정 정보가 `config/config.json`에 **평문으로 저장**되며, 이 파일이 Git에 추적되면 비밀 노출 위험.

**개선**: credentials를 `.env.local` 또는 별도 git-ignored 파일로 분리. config.json에는 참조 경로만 유지.

#### 4-2. timeouts 값이 참조되지 않음 — LOW

`config.json`의 timeouts가 정의만 되고 실제 Bash 호출에서 사용되지 않음. commit 스킬만 `timeout: 300000`을 하드코딩.

**개선**: 오케스트레이터와 스킬에서 config.json의 timeouts를 참조하도록 지침 추가.

---

### 5. 훅 커버리지 갭 (MEDIUM)

#### 5-1. Agent/SendMessage 도구에 대한 가드 없음

현재 훅은 Bash와 Write/Edit만 감시. Agent, SendMessage 도구는 **무제한 호출 가능**.

**개선**: 팀 외부 에이전트 호출 감지 훅 추가 (선택적).

---

### 6. 스킬 유지보수성 (LOW)

#### 6-1. dev-beom/fix-beom/persist-beom 공통 로직 중복

Phase 1(Setup), Phase 5(QA), Phase 6(커밋)이 거의 동일하게 반복됨. 하나를 수정하면 나머지도 수동 동기화 필요.

**개선**: 공통 Phase를 별도 참조 문서로 추출하고, 각 스킬에서 "Phase 1은 `_common/setup-phase.md` 참조" 형태로 연결.

#### 6-2. 문서 정리 정책 없음

`docs/plan/`, `docs/result/`, `docs/issue/` 파일이 시간이 지나면서 무한히 쌓임. 정리/아카이빙 규칙 없음.

**개선**: COMPLETED 상태 plan 파일은 일정 기간 후 아카이빙하는 정리 스킬 또는 규칙 추가.

---

## 허점 종합 순위

| # | 허점 | 심각도 | 카테고리 |
|---|------|--------|---------|
| 1 | git push 보호 부재 | HIGH | 안전장치 |
| 2 | webTest.credentials 평문 저장 | HIGH | 보안 |
| 3 | 롤백 메커니즘 부재 | HIGH | 기능 |
| 4 | code-quality-gate Bash 우회 | MEDIUM | 안전장치 |
| 5 | contextLimits 강제 안 됨 | MEDIUM | 에이전트 통신 |
| 6 | 에이전트 실패 복구 부재 | MEDIUM | 에이전트 통신 |
| 7 | 동시 실행 방지 없음 | MEDIUM | 기능 |
| 8 | 파괴적 Git 명령어 미보호 | MEDIUM | 안전장치 |
| 9 | 에이전트 타임아웃 미처리 | MEDIUM | 기능 |
| 10 | plan 상태 부족 | MEDIUM | 기능 |
| 11 | Agent/SendMessage 가드 없음 | MEDIUM | 훅 |
| 12 | 보호 브랜치 목록 중복 정의 | LOW | 일관성 |
| 13 | 공통 로직 중복 | LOW | 유지보수 |
| 14 | 문서 정리 정책 없음 | LOW | 관리 |

---

## 권장 조치

### 1차 (긴급 — 안전장치 보강)
- [ ] pre-tool-guard에 git push 보호 추가
- [ ] webTest.credentials를 git-ignored 파일로 분리
- [ ] QA 5회 초과 시 롤백 옵션 추가

### 2차 (중요 — 안정성 강화)
- [ ] code-quality-gate의 Bash 커버리지 확장
- [ ] contextLimits 오케스트레이터에서 참조/적용
- [ ] 에이전트 실패 시 재시도 + fallback 지침 추가
- [ ] 동시 실행 방지 (lock 메커니즘)

### 3차 (개선 — 유지보수성)
- [ ] 보호 브랜치 목록 config.json 단일 소스화
- [ ] 오케스트레이터 공통 Phase 추출
- [ ] plan 상태 확장 (6단계)
- [ ] docs/ 정리 정책 수립

---

## 다음 단계

- 1차 개선 작업: `/dev-beom pre-tool-guard에 git push 보호 및 파괴적 명령어 가드 추가`
- 보안 개선: `/fix-beom webTest.credentials 평문 저장 문제 수정`
- 구조 개선: `/dev-beom 오케스트레이터 공통 Phase 추출 및 contextLimits 강제`
