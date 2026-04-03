---
name: web-test
description: "E2E 웹 테스트. Playwright로 테스트 계획→생성→실행→수정까지 수행한다. OTP 바이패스 지원."
argument-hint: "<테스트 대상 URL> [테스트 시나리오 설명]"
---

E2E 웹 테스트 스킬. Playwright 에이전트를 활용하여 테스트 계획 → 코드 생성 → 실행/수정까지 수행한다.
OTP 인증이 있는 서비스의 경우 로컬 코드의 OTP 검증을 임시 비활성화하고, 테스트 완료 후 반드시 원복한다.

항상 한국어로 응답한다.

## 절대 원칙

1. **OTP 원복은 무조건 실행한다.** 테스트 성공/실패와 무관하게 Phase 6은 반드시 수행한다.
2. **프로덕션 코드를 영구 수정하지 않는다.** OTP 바이패스는 테스트 중에만 유효하며, `git checkout`으로 원복한다.
3. **사용자 확인 없이 OTP 코드를 수정하지 않는다.** 탐지 결과를 보여주고 승인을 받은 후 수정한다.

## QA 에이전트 호출 조건

qa-manager가 코드 리뷰 후, 다음 조건 중 하나라도 해당하면 `/web-test` 호출을 오케스트레이터에게 권고한다:

1. **프론트엔드 프로젝트**: 변경 파일에 `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.html` 포함
2. **어드민/백오피스 프로젝트**: 변경 경로에 `admin`, `backoffice`, `back-office`, `management` 포함
3. **UI 변경 포함**: 변경 diff에 컴포넌트 렌더링, 라우팅, 폼 로직 변경이 포함된 경우

`config/config.json`의 `webTest.detectPatterns`에서 탐지 패턴을 커스터마이징할 수 있다.

## 인자

- `ARGS`: 테스트 대상 URL + 선택적 시나리오 설명

ARGS 없이 호출 시: "테스트할 URL을 입력해주세요. 예: `/web-test http://localhost:3000 로그인 및 대시보드 테스트`"

---

# 실행 플로우

## Phase 1: Setup

### 1-1. 인자 파싱
- ARGS에서 URL을 추출한다 (http/https로 시작하는 첫 번째 토큰)
- URL이 없으면 아래 1-2의 자동 결정 로직으로 URL을 결정한다
- URL 외 나머지 텍스트를 시나리오 설명으로 사용한다

### 1-2. 프로젝트 타입 감지
1. `config/config.json`의 `projectTypes` 규칙으로 프로젝트 타입을 감지한다
   - `build.gradle.kts` 또는 `build.gradle` → **spring-boot** (kotlin-java)
   - `package.json` → **nodejs**
   - `pyproject.toml` 또는 `setup.py` → **python**
2. 감지 결과를 기록한다 (서버 기동 방식, OTP 탐지 패턴 선택에 사용)
3. 프로젝트 디렉토리명을 `PROJECT_NAME`으로 저장한다 (예: `store-admin`)

### 1-3. 서버 프로필 확인 및 저장

1. `config/config.json`의 `webTest.serverProfiles[PROJECT_NAME]` 조회
2. **프로필 있음** → 저장된 설정 사용
3. **프로필 없음** → AskUserQuestion으로 Active Profiles, Environment Variables 요청 후 config에 저장

저장 키: `type`, `activeProfiles`, `envVars`, `port` (기본: spring-boot=8080, nodejs=3000), `otpBypass`

### 1-4. 서버 빌드 및 기동

프로젝트 타입에 따라 서버를 빌드하고 기동한다. PID를 `.dev/server.pid`에 기록.

- **Spring Boot**: `./gradlew build -x test` → JAR 탐색 → `{ENV_VARS} java -jar {JAR} --server.port={port} &` → `/actuator/health` 대기 (최대 60초)
- **Node.js**: `playwright.config.ts`에 webServer 있으면 생략. 없으면 `{bun|npm} run dev &` → 대기 (최대 30초)

**URL 결정 우선순위:** ARGS URL > `playwright.config.ts`의 `use.baseURL` > `serverProfiles[PROJECT_NAME].port` > 기본값(8080/3000)

### 1-5. Playwright 환경 확인
1. `npx playwright --version` 실행
2. 미설치 시 사용자에게 안내: "Playwright가 설치되어 있지 않습니다. `npm init playwright@latest`로 설치해주세요."
3. 설치 확인 후 진행

### 1-6. 테스트 디렉토리 결정
1. `playwright.config.ts` 또는 `playwright.config.js` 존재 여부 확인
2. 있으면 `testDir` 설정을 읽어 사용
3. 없으면 기본값 `e2e/` 사용

### 1-7. 테스트 계정 정보 확인

1. `config/config.json`의 `webTest.credentials[호스트명]` 조회 (호스트명 = URL의 host:port)
2. **있음** → 저장된 ID/PW 사용
3. **없음** → AskUserQuestion으로 ID/PW 요청 (skip 가능) 후 config에 저장

### 1-8. .dev 디렉토리 준비
- `.dev/` 디렉토리가 없으면 생성
- `.gitignore`에 `.dev/` 추가 (없으면)

---

## Phase 2: OTP 바이패스

### 2-1. OTP 바이패스 필요 여부 판단

`config/config.json`의 `webTest.serverProfiles[PROJECT_NAME].otpBypass` 값을 확인한다:

- **`otpBypass: true`** → 사용자 확인 없이 **자동으로** 2-2 ~ 2-6 실행
- **`otpBypass: false`** → Phase 3으로 건너뛴다
- **`otpBypass` 키 없음 (최초 실행)** → 사용자에게 1회 질문 후 결과를 저장:
  ```
  AskUserQuestion("이 서비스에 OTP/2FA 인증이 있습니까? 있다면 테스트 중 임시로 비활성화합니다. (y/n)")
  ```
  답변에 따라 `serverProfiles[PROJECT_NAME].otpBypass`를 `true`/`false`로 저장.

### 2-2. OTP 코드 탐지 및 바이패스

1. `Read(skills/web-test/references/otp-patterns.md)`로 프로젝트 타입별 Grep 패턴과 바이패스 전략을 확인한다
2. 해당 패턴으로 Grep 탐색 수행
3. **`otpBypass: true`**: 확인 없이 즉시 바이패스 진행. "다음 파일의 OTP를 바이패스합니다: {목록}" 출력
4. `git status --porcelain` 확인 후, 대상 파일에 미커밋 변경이 있으면 `git stash push -m "web-test-otp-bypass-backup" -- {파일들}` + `.dev/otp-stash-flag` 기록
5. 탐지된 OTP 검증 함수를 바이패스 전략에 따라 수정
6. 수정 파일 경로를 `.dev/otp-bypass-files.txt`에 기록

---

## Phase 3: 기존 테스트 확인

테스트 디렉토리에서 기존 Playwright 테스트를 탐색한다:

```
Glob(pattern="**/*.spec.ts", path="{테스트 디렉토리}")
```

- **기존 테스트 있음** → `MODE = "실행만"` (Phase 4에서 탐색/생성 생략, 실행만 수행)
- **기존 테스트 없음** → `MODE = "생성+실행"`

## Phase 4: 테스트 실행

MODE에 따라 경량 에이전트 또는 통합 에이전트를 spawn한다.

### MODE == "실행만" (기존 테스트 있음)

```
Agent(
  name="web-test-runner",
  prompt="""
  기존 E2E 테스트를 실행해주세요.

  URL: {URL}
  기존 테스트: {파일 경로 목록}
  테스트 디렉토리: {테스트 디렉토리 경로}
  """
)
```

### MODE == "생성+실행" (기존 테스트 없음)

```
Agent(
  name="web-tester",
  prompt="""
  E2E 웹 테스트를 생성하고 실행해주세요.

  URL: {URL}
  테스트 계정: {ID/PW 또는 "로그인 불필요"}
  시나리오: {시나리오 설명}
  테스트 디렉토리: {테스트 디렉토리 경로}
  """
)
```

에이전트 결과를 `.dev/test-result.md`에 저장한다.

---

## Phase 5: 웹 테스트 통과 마커 생성

Phase 4 완료 후, 커밋 게이트용 통과 마커를 생성한다:
```
Bash(command="date +%Y%m%dT%H%M%S > .dev/web-test-passed")
```

이 마커가 없으면 `pre-tool-guard` 훅이 `git commit`을 차단한다.

## Phase 6: 정리 (서버 종료 + OTP 원복 + 결과 보고)

**이 Phase는 어떤 상황에서도 반드시 실행한다.**

### 6-0. dev 서버 종료

Phase 1에서 서버를 직접 기동한 경우 (`playwright.config.ts`의 `webServer` 사용 시 생략):

1. `.dev/server.pid` 파일이 존재하면 PID를 읽는다
2. `kill {PID}` 실행
3. `.dev/server.pid` 삭제
4. 종료 확인: `kill -0 {PID}` 가 실패하면 성공

### 6-1. OTP 원복

`.dev/otp-bypass-files.txt` 파일이 존재하면:

1. 파일 목록을 읽는다
2. 각 파일에 대해 `git checkout -- {파일경로}` 실행
3. 원복 검증: `git diff -- {파일경로}`가 비어있는지 확인
4. `.dev/otp-stash-flag` 존재 시 `git stash pop` 실행
5. `.dev/otp-bypass-files.txt`와 `.dev/otp-stash-flag` 삭제

**원복 실패 시:**
```
사용자에게 즉시 알림:
"OTP 원복에 실패했습니다. 다음 명령어로 수동 원복해주세요:
git checkout -- {실패한 파일 목록}
또는 전체 원복: git checkout -- ."
```

### 6-2. 결과 보고

테스트 결과를 요약하여 사용자에게 보고한다:

```
## 웹 테스트 결과

- 대상 URL: {URL}
- 테스트 시나리오: {N}건
- 통과: {N}건
- 실패: {N}건 (fixme 포함)
- OTP 바이패스: {사용함/사용 안 함} → {원복 완료/해당 없음}
- 테스트 파일 위치: {테스트 디렉토리}
- 테스트 계획: .dev/test-plan.md

{실패 테스트가 있으면 주요 실패 원인 요약}
```

---

# 에러 처리

| 상황 | 대응 |
|------|------|
| Playwright 미설치 | 설치 안내 후 중단 |
| URL 접근 불가 | 사용자에게 URL 확인 요청 |
| OTP 탐지 결과 없음 | "OTP 코드를 찾지 못했습니다" 안내 후 바이패스 없이 진행 |
| OTP 원복 실패 | 수동 복구 명령어 안내 |
| 테스트 생성 실패 | 에러 내용 보고, 사용자에게 시나리오 수정 요청 |
| Healer 3회 초과 | 미해결 실패 목록 보고 후 종료 |

# 금지 사항

- OTP 원복 없이 스킬을 종료하지 않는다
- 앱의 프로덕션 코드를 테스트 목적으로 영구 수정하지 않는다
- 사용자 확인 없이 OTP 코드를 수정하지 않는다
- 테스트 코드에서 하드코딩된 비밀번호/토큰을 사용하지 않는다 (config에서 읽어 사용)
- 계정 정보를 로그나 출력에 노출하지 않는다
