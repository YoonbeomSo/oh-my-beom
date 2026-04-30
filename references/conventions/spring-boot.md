# Spring Boot 컨벤션 (공통)

Spring Boot (Java 17, JPA, QueryDSL) 프로젝트에서 architect, coder, qa-manager가 공통으로 참조하는 컨벤션.
`build.gradle.kts` 또는 `build.gradle` 감지 시에만 로드한다.

---

## 설계 (architect용)

### REST API 설계 가이드

- URL: `/api/v1/{resource}`, 리소스명 복수형 명사, 케밥-케이스
- Method: GET(조회), POST(생성), PUT(전체 수정), PATCH(부분 수정), DELETE(삭제)
- Controller 전용 DTO 사용 (Entity 직접 받지 않음)
- Request: `{Action}{Resource}Request`, Response: `{Resource}Response`
- 에러 응답: `{ "code": "...", "message": "...", "timestamp": "..." }`
- HTTP 상태: 200, 201, 204, 400, 401, 403, 404, 409, 500

### JPA 엔티티 설계 가이드

- Entity = DB 테이블 1:1 매핑, Controller에 직접 노출 금지
- `@Setter` 지양 → 비즈니스 메서드로 상태 변경
- `@NoArgsConstructor(access = AccessLevel.PROTECTED)` 필수
- `@Builder`는 생성 시점 전용, 정적 팩토리 메서드 고려
- `@Column` 제약 조건 명시 (nullable, length)

### 연관관계 매핑

| 상황 | 권장 |
|------|------|
| 양방향 필요? | 대부분 단방향으로 충분 |
| N 쪽 조회 빈번 | N → 1 단방향 `@ManyToOne` |
| 1 쪽에서 N 관리 | 양방향 고려 |
| N:M | 중간 엔티티로 1:N + N:1 |

- 연관관계 주인: 외래키 있는 쪽 (N 쪽)
- `@ManyToOne`: LAZY 필수 (`fetch = FetchType.LAZY`)
- 양방향 시 편의 메서드 필수

### N+1 해결

| 방법 | 시점 |
|------|------|
| fetch join (JPQL) | 특정 조회 |
| `@EntityGraph` | Repository 선언적 |
| QueryDSL fetchJoin() | 동적 쿼리 |
| `@BatchSize` | 전역 완화 |

### 정규화/비정규화

- 정규화 우선 (데이터 무결성, 쓰기 빈번)
- 비정규화: 조회 성능 극도 중요, JOIN 과도 시 → 동기화 전략 문서화

---

## 구현 (coder용)

### Service Read/Write 분리
- 조회: `XxxReadService` + `@Transactional(readOnly = true)`
- 쓰기: `XxxService` + `@Transactional`
- 하나의 Service에 Read/Write 섞지 않음

### DTO/Entity 분리
- Controller ↔ Service: DTO
- Service ↔ Repository: Entity
- Entity를 Controller 응답에 직접 노출 금지

### @Transactional 패턴
- 쓰기: `@Transactional`, 읽기: `@Transactional(readOnly = true)`
- 외부 API 호출은 트랜잭션 밖에서 수행

### JPA 엔티티 규칙
- `@Setter` 지양, `@NoArgsConstructor(access = AccessLevel.PROTECTED)` 필수
- `@ManyToOne(fetch = FetchType.LAZY)` 필수, EAGER 금지
- 단방향 우선, 양방향 필요 시 편의 메서드

### QueryDSL 패턴
- 동적 쿼리는 QueryDSL로 작성
- N+1 방지: `leftJoin().fetchJoin()`
- 복잡한 조회는 별도 QueryRepository 분리

### Lombok
- `@Getter` 사용, `@Setter` 지양
- `@Builder`는 생성 전용, `@AllArgsConstructor` + `@Builder` 시 `@NoArgsConstructor` 누락 주의

---

## 리뷰 (qa-manager용)

### 아키텍처 패턴 검증

**Service 분리**: `XxxReadService` + `XxxService` 분리 확인
**패키지 구조**: common/, constant/, controller/, model/, repository/, service/, feign/, util/
**DTO/Entity**: Controller↔Service(DTO), Service↔Repository(Entity), Entity 직접 노출 금지

### 코딩 컨벤션 체크리스트 (25항목)

**가독성**: 삼항 지양, 한 줄 한 책임, 메서드 짧게, early return, else 최소, 매직넘버→상수, indent 2단계 이내
**네이밍**: boolean 긍정형, 축약어 지양, 역할 드러내는 이름, 주석보다 이름
**안전성**: null→Optional/빈 컬렉션, 명확한 예외 처리, 불필요 public 제거, 테스트 가능 구조

### 추상화 원칙 체크리스트 (20항목)

**추상화 수준**: 한 메서드 한 수준, 비즈니스/기술 분리, 상위=무엇/하위=어떻게, 단방향 의존, 조건 많으면 재설계
**단일 책임**: 클래스 한 책임, 메서드 한 작업, 변경 사유 2+면 분리
**의존성**: 인터페이스 의존, 외부 의존 추상화, 순환 의존 없음
**캡슐화**: 내부 상태 보호, getter/setter 남용 금지→비즈니스 메서드, 불변 객체 우선
**확장성**: 수정 없이 확장, 과도한 추상화 지양, 추상화가 복잡도를 줄이는지
**일관성**: 같은 수준 같은 패턴, 네이밍이 추상화 반영, 예외 처리 일관

### Lombok / JPA+QueryDSL 패턴
- Lombok 활용 확인 (getter/setter 남용 지양)
- N+1 가능성 검토, fetch join/EntityGraph 적절 사용
- `@Transactional` 적절 사용 여부

### 6단계 리뷰 시 [SPRING] 태그
위 체크리스트를 6단계 리뷰의 마지막 단계 `[SPRING]`에서 적용한다.
