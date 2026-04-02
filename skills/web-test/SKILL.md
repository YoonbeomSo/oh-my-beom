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
- URL이 없으면 사용자에게 요청한다
- URL 외 나머지 텍스트를 시나리오 설명으로 사용한다

### 1-2. 프로젝트 타입 감지
1. `config/config.json`의 `projectTypes` 규칙으로 프로젝트 타입을 감지한다
2. 감지 결과를 기록한다 (OTP 탐지 패턴 선택에 사용)

### 1-3. Playwright 환경 확인
1. `npx playwright --version` 실행
2. 미설치 시 사용자에게 안내: "Playwright가 설치되어 있지 않습니다. `npm init playwright@latest`로 설치해주세요."
3. 설치 확인 후 진행

### 1-4. 테스트 디렉토리 결정
1. `playwright.config.ts` 또는 `playwright.config.js` 존재 여부 확인
2. 있으면 `testDir` 설정을 읽어 사용
3. 없으면 기본값 `e2e/` 사용

### 1-5. 테스트 계정 정보 확인

로그인이 필요한 서비스 테스트를 위해 계정 정보를 확보한다.

1. `config/config.json`의 `webTest.credentials` 확인
2. URL의 호스트명을 키로 사용 (예: `localhost:3000`, `admin.example.com`)

**credentials에 해당 호스트가 있는 경우:**
```json
{
  "webTest": {
    "credentials": {
      "localhost:3000": { "id": "admin", "pw": "test1234" }
    }
  }
}
```
→ 저장된 계정 정보를 사용한다.

**credentials에 없는 경우:**
```
AskUserQuestion("테스트에 사용할 로그인 계정을 입력해주세요.\n- ID: \n- PW: \n\n입력하신 계정은 config/config.json에 저장되어 다음 테스트에 재사용됩니다.\n로그인이 불필요하면 'skip'을 입력해주세요.")
```

사용자가 계정을 입력하면:
- `config/config.json`의 `webTest.credentials`에 호스트명을 키로 저장
- 이후 같은 호스트 테스트 시 자동으로 사용

### 1-6. .dev 디렉토리 준비
- `.dev/` 디렉토리가 없으면 생성
- `.gitignore`에 `.dev/` 추가 (없으면)

---

## Phase 2: OTP 바이패스 (조건부)

### 2-1. OTP 바이패스 필요 여부 확인

```
AskUserQuestion("이 서비스에 OTP/2FA 인증이 있습니까? 있다면 테스트 중 임시로 비활성화합니다. (y/n)")
```

사용자가 `n` 또는 불필요하다고 답하면 Phase 3으로 건너뛴다.

### 2-2. OTP 코드 탐지

프로젝트 타입에 따라 아래 패턴으로 Grep 탐색한다:

**공통 패턴:**
```
Grep(pattern="(verifyOtp|validateOtp|checkOtp|otpVerif|otpValid|totp\\.verify|mfa\\.verify|verify.*[Oo]tp|validate.*[Oo]tp)", output_mode="content")
Grep(pattern="(OtpService|TotpService|MfaService|OtpFilter|OtpInterceptor)", output_mode="content")
```

**Java/Spring Boot 추가:**
```
Grep(pattern="(@EnableOtp|OtpAuthenticationProvider|AbstractOtpFilter)", glob="*.java")
```

**Node.js/TypeScript 추가:**
```
Grep(pattern="(speakeasy|otplib|authenticator\\.verify|totp\\.verify)", glob="*.{ts,js}")
```

**Python 추가:**
```
Grep(pattern="(pyotp|django_otp|verify_otp|check_otp)", glob="*.py")
```

### 2-3. 탐지 결과 사용자 확인

탐지된 파일과 해당 라인을 사용자에게 표시한다:

```
AskUserQuestion("""
OTP 관련 코드를 다음 파일에서 발견했습니다:

{탐지 결과 목록 - 파일:라인번호 + 코드 스니펫}

위 파일들의 OTP 검증 로직을 임시로 비활성화합니다.
진행하시겠습니까? (y/n)

참고: 테스트 완료 후 git checkout으로 자동 원복됩니다.
""")
```

사용자가 거부하면 OTP 바이패스 없이 Phase 3으로 진행한다.

### 2-4. Git 상태 확인 + Stash

1. `git status --porcelain`으로 워킹 트리 확인
2. OTP 대상 파일에 미커밋 변경이 있으면:
   ```
   git stash push -m "web-test-otp-bypass-backup" -- {대상 파일들}
   ```
3. stash 수행 여부를 `.dev/otp-stash-flag` 파일에 기록

### 2-5. OTP 코드 주석 처리

탐지된 OTP 검증 함수/메서드를 수정한다:

**전략: 검증 함수가 항상 통과를 반환하도록 수정**

- Java: 메서드 본문을 `return true;` 또는 빈 통과 로직으로 교체
- JS/TS: 함수 본문을 `return true;` 또는 `next()` 호출로 교체
- Python: 함수 본문을 `return True` 또는 `pass`로 교체

수정 시 원본 코드를 주석으로 보존:
```
// [WEB-TEST-BYPASS] 원본 코드 시작
// {원본 코드}
// [WEB-TEST-BYPASS] 원본 코드 끝
{바이패스 코드}
```

### 2-6. 수정 파일 목록 기록

수정된 파일 경로를 `.dev/otp-bypass-files.txt`에 한 줄씩 기록한다.

---

## Phase 3: 테스트 계획

`playwright-test-planner` 에이전트에게 테스트 계획을 위임한다.

```
Agent(
  subagent_type="playwright-test-planner",
  prompt="""
  다음 웹 애플리케이션의 E2E 테스트 계획을 수립해주세요.

  대상 URL: {URL}
  시나리오: {시나리오 설명 또는 "전체 주요 기능 테스트"}
  프로젝트 타입: {감지된 타입}
  테스트 계정: {ID/PW 또는 "로그인 불필요"}

  브라우저로 사이트를 탐색하고 주요 사용자 플로우를 파악하여
  테스트 시나리오를 설계해주세요.
  로그인이 필요하면 제공된 계정으로 먼저 로그인해주세요.
  """
)
```

에이전트 결과를 `.dev/test-plan.md`에 저장한다.

---

## Phase 4: 테스트 생성

`playwright-test-generator` 에이전트에게 테스트 코드 생성을 위임한다.

```
Agent(
  subagent_type="playwright-test-generator",
  prompt="""
  다음 테스트 계획을 기반으로 Playwright 테스트 코드를 생성해주세요.

  테스트 계획:
  {.dev/test-plan.md 내용}

  테스트 디렉토리: {테스트 디렉토리 경로}
  대상 URL: {URL}
  테스트 계정: {ID/PW 또는 "로그인 불필요"}

  각 시나리오를 개별 .spec.ts 파일로 생성해주세요.
  테스트 스텝은 한국어 주석으로 작성해주세요.
  로그인이 필요한 테스트는 beforeEach에서 로그인 처리해주세요.
  """
)
```

---

## Phase 5: 테스트 실행 + 수정 루프

`playwright-test-healer` 에이전트에게 테스트 실행과 수정을 위임한다.

```
heal_count = 0
max_heal = 3

while heal_count < max_heal:
    heal_count++

    Agent(
      subagent_type="playwright-test-healer",
      prompt="""
      Playwright 테스트를 실행하고 실패하는 테스트를 수정해주세요.

      테스트 디렉토리: {테스트 디렉토리 경로}

      규칙:
      - 테스트 코드 문제는 직접 수정
      - 앱 코드 문제는 보고만 (수정하지 않음)
      - 수정 불가능한 실패는 test.fixme()로 마킹
      """
    )

    # 결과 확인
    if 모든 테스트 통과 또는 남은 실패가 모두 fixme:
        break
```

3회 루프 후에도 실패가 남으면 실패 목록을 사용자에게 보고한다.

---

## Phase 6: OTP 원복 + 결과 보고

**이 Phase는 어떤 상황에서도 반드시 실행한다.**

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

# OTP 탐지 패턴 레퍼런스

| 프레임워크 | 탐지 키워드 | 일반적 위치 |
|-----------|-----------|-----------|
| Spring Boot | `OtpService`, `TotpService`, `MfaFilter`, `verifyOtp`, `@EnableOtp` | `**/service/**`, `**/filter/**`, `**/interceptor/**` |
| Node.js/Express | `speakeasy`, `otplib`, `authenticator`, `totp.verify` | `**/middleware/**`, `**/auth/**`, `**/routes/**` |
| Django/Flask | `pyotp`, `django_otp`, `verify_otp`, `check_otp` | `**/views/**`, `**/middleware/**`, `**/decorators/**` |
| Next.js/Nuxt | `authenticator.verify`, `verifyTOTP`, `validateOTP` | `**/api/**`, `**/middleware/**`, `**/lib/auth/**` |

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
