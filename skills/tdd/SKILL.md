---
name: tdd
description: "TDD 방법론. coder 에이전트가 구현 시 Red-Green-Refactor 사이클을 따른다. 오케스트레이터가 coder에게 구현 지시 시 이 스킬의 규칙을 전달한다."
argument-hint: "[skip] - TDD 생략 (프로토타입/설정 파일 한정)"
---

coder 에이전트의 TDD 구현 방법론. 기능 구현과 버그 수정에서 Red-Green-Refactor 사이클을 따른다.

항상 한국어로 응답한다.

## 핵심 원칙

```
가능한 한 테스트를 먼저 작성하고, 실패를 확인한 뒤 구현한다.
```

테스트 없이 작성한 코드가 있으면 삭제하지 않는다. 대신 사후에 테스트를 추가하여 검증한다.

---

# Red-Green-Refactor 사이클

모든 기능 단위에 대해 아래 사이클을 반복한다.

## 1. RED: 실패하는 테스트 작성

하나의 동작을 검증하는 최소한의 테스트를 작성한다.

**규칙:**
- 테스트 이름은 동작을 서술한다 (예: `"빈 이메일을 거부한다"`)
- 하나의 테스트에 하나의 동작만 검증한다
- 테스트 이름에 "and"가 들어가면 분리한다
- 3A 구조: Arrange(준비) - Act(실행) - Assert(검증)

**Mock 사용 기준:**
- 시스템 경계(외부 API, DB, 파일 I/O)에만 Mock 사용
- 내부 모듈 간 호출은 실제 구현을 사용한다

## 2. RED 검증: 실패 확인

테스트를 실행하여 **올바른 이유로 실패**하는지 확인한다.

```
{프로젝트 타입별 테스트 명령} {테스트 파일 경로}
```

**확인 사항:**
- 테스트가 실패한다 (에러가 아닌 실패)
- 기능이 없어서 실패한다 (오타/문법 오류가 아님)

**테스트가 통과하면?** 이미 존재하는 동작을 테스트한 것이다. 테스트를 수정한다.

## 3. GREEN: 최소 코드 작성

테스트를 통과시키는 **가장 단순한** 코드를 작성한다.

**규칙:**
- 테스트가 요구하지 않는 기능을 추가하지 않는다
- 리팩토링하지 않는다 (다음 단계에서 한다)

## 4. GREEN 검증: 통과 확인

```
{프로젝트 타입별 테스트 명령}
```

**확인 사항:**
- 새 테스트가 통과한다
- 기존 테스트도 모두 통과한다

**테스트가 실패하면?** 코드를 수정한다 (테스트를 수정하지 않는다).

## 5. REFACTOR: 정리

GREEN 상태에서만 리팩토링한다.

**허용:** 중복 제거, 이름 개선, 헬퍼 추출
**금지:** 새 동작 추가, 테스트를 깨뜨리는 변경

리팩토링 후 테스트가 여전히 GREEN인지 확인한다.

## 6. 다음 사이클

다음 기능 단위의 RED로 돌아간다.

---

# 프로젝트 타입별 테스트 명령

`config/config.json`의 `projectTypes`에서 테스트 명령을 가져온다.

| 타입 | 전체 테스트 | 단일 파일 실행 |
|------|-----------|--------------|
| Kotlin/Java | `./gradlew test` | `./gradlew test --tests "패키지.클래스명"` |
| Node.js (bun) | `bun test` | `bun test {파일경로}` |
| Node.js (npm) | `npm test` | `npm test -- --testPathPattern={파일경로}` |
| Python | `pytest --tb=short` | `pytest {파일경로} -v` |

RED/GREEN 검증 시 **단일 파일 실행**으로 빠르게 확인한다.
GREEN 검증 최종 단계에서 **전체 테스트**를 실행한다.

---

# coder 에이전트 구현 흐름

설계서의 "구현 순서" 각 단계에 대해:

```
1. 설계서에서 현재 단계의 수용 기준/테스트 전략 확인
2. RED: 수용 기준을 검증하는 테스트 작성
3. RED 검증: 테스트 실행 → 실패 확인
4. GREEN: 최소 구현 코드 작성
5. GREEN 검증: 테스트 실행 → 전체 통과 확인
6. REFACTOR: 중복 제거, 이름 개선
7. 보고: [N/M] <파일> - <변경 요약> (RED→GREEN 확인됨)
8. 다음 단계로 이동
```

## 보고 형식

기존 `[N/M]` 보고에 TDD 상태를 포함한다:

```
[1/3] src/auth/LoginService.java - 로그인 검증 로직 구현
  - RED: "빈 이메일 거부" 테스트 실패 확인
  - GREEN: 이메일 검증 로직 추가 → 통과
  - RED: "잘못된 비밀번호 거부" 테스트 실패 확인
  - GREEN: 비밀번호 검증 로직 추가 → 전체 통과
  - REFACTOR: 검증 로직 ValidationHelper로 추출
```

## 테스트 우선이 어려운 경우

다음 상황에서는 **구현 후 테스트 추가**를 허용한다:

- 기존 코드에 테스트가 전혀 없어 테스트 인프라부터 세팅해야 하는 경우
- UI/프론트엔드 컴포넌트의 초기 레이아웃 작성
- 외부 시스템 연동 코드에서 API 응답 구조를 탐색 중인 경우

이 경우에도 구현 완료 후 반드시 테스트를 추가한다.

---

# TDD 적용 예외

다음 경우에만 TDD를 생략할 수 있다 (오케스트레이터가 `skip` 인자로 명시):

- 설정 파일 변경 (application.yml, package.json 등)
- 프로토타입/PoC (이후 삭제 예정인 코드)
- 생성 코드 (ORM 마이그레이션, OpenAPI 생성 등)

---

# 테스트 작성 가이드

## 좋은 테스트

| 기준 | 좋음 | 나쁨 |
|------|------|------|
| 최소 | 하나의 동작만 검증 | `"이메일과 도메인과 공백을 검증한다"` |
| 명확 | 이름이 동작을 서술 | `"test1"`, `"검증 테스트"` |
| 독립 | 다른 테스트와 상태 비공유 | 테스트 순서에 의존 |
| 실제 | 실제 코드 실행 | Mock으로 Mock을 검증 |

## 프레임워크별 패턴

### Kotlin/Java (JUnit 5)
```java
@Test
@DisplayName("빈 이메일을 거부한다")
void rejectsEmptyEmail() {
    // Arrange
    var request = new LoginRequest("", "password");

    // Act & Assert
    assertThrows(ValidationException.class,
        () -> loginService.login(request));
}
```

### Node.js/TypeScript (Jest/Vitest)
```typescript
test('빈 이메일을 거부한다', async () => {
  // Arrange
  const request = { email: '', password: 'test' };

  // Act
  const result = await login(request);

  // Assert
  expect(result.error).toBe('이메일은 필수입니다');
});
```

### Python (pytest)
```python
def test_rejects_empty_email():
    # Arrange
    request = LoginRequest(email="", password="test")

    # Act & Assert
    with pytest.raises(ValidationError, match="이메일은 필수"):
        login(request)
```

---

# 버그 수정 TDD

버그 발견 시:

1. 버그를 재현하는 실패 테스트를 작성한다
2. 테스트가 실패하는지 확인한다 (버그 재현 증명)
3. 최소한의 코드로 수정한다
4. 테스트가 통과하는지 확인한다 (수정 증명)
5. 회귀 방지 테스트로 남긴다

---

# 문제 해결

| 상황 | 대응 |
|------|------|
| 테스트 작성법을 모르겠다 | Assert부터 역순으로 작성한다 |
| 테스트가 너무 복잡하다 | 인터페이스를 단순화한다 |
| Mock이 너무 많다 | 결합도가 높은 것이다. 의존성 주입을 사용한다 |
| 테스트 셋업이 크다 | 헬퍼를 추출한다. 여전히 크면 설계를 단순화한다 |
| 기존 코드에 테스트가 없다 | 변경하는 부분에 대해서만 테스트를 추가한다 |
