# OTP 탐지 패턴

## Grep 패턴

### 공통
```
Grep(pattern="(verifyOtp|validateOtp|checkOtp|otpVerif|otpValid|totp\\.verify|mfa\\.verify|verify.*[Oo]tp|validate.*[Oo]tp)", output_mode="content")
Grep(pattern="(OtpService|TotpService|MfaService|OtpFilter|OtpInterceptor)", output_mode="content")
```

### Java/Spring Boot 추가
```
Grep(pattern="(@EnableOtp|OtpAuthenticationProvider|AbstractOtpFilter)", glob="*.java")
```

### Node.js/TypeScript 추가
```
Grep(pattern="(speakeasy|otplib|authenticator\\.verify|totp\\.verify)", glob="*.{ts,js}")
```

### Python 추가
```
Grep(pattern="(pyotp|django_otp|verify_otp|check_otp)", glob="*.py")
```

## 프레임워크별 위치 레퍼런스

| 프레임워크 | 탐지 키워드 | 일반적 위치 |
|-----------|-----------|-----------|
| Spring Boot | `OtpService`, `TotpService`, `MfaFilter`, `verifyOtp`, `@EnableOtp` | `**/service/**`, `**/filter/**`, `**/interceptor/**` |
| Node.js/Express | `speakeasy`, `otplib`, `authenticator`, `totp.verify` | `**/middleware/**`, `**/auth/**`, `**/routes/**` |
| Django/Flask | `pyotp`, `django_otp`, `verify_otp`, `check_otp` | `**/views/**`, `**/middleware/**`, `**/decorators/**` |
| Next.js/Nuxt | `authenticator.verify`, `verifyTOTP`, `validateOTP` | `**/api/**`, `**/middleware/**`, `**/lib/auth/**` |

## 바이패스 전략

검증 함수가 항상 통과를 반환하도록 수정:

- **Java**: 메서드 본문을 `return true;` 또는 빈 통과 로직으로 교체
- **JS/TS**: 함수 본문을 `return true;` 또는 `next()` 호출로 교체
- **Python**: 함수 본문을 `return True` 또는 `pass`로 교체

수정 시 원본 코드를 주석으로 보존:
```
// [WEB-TEST-BYPASS] 원본 코드 시작
// {원본 코드}
// [WEB-TEST-BYPASS] 원본 코드 끝
{바이패스 코드}
```
