---
description: 
alwaysApply: true
---

# HectoProject

Hecto Lab의 다양한 프로젝트를 포함하는 모노레포 워크스페이스입니다.

## 프로젝트 구조

```
HectoProject/
├── Config/                    # 인프라 설정 (Gateway, Config Server, DB)
├── Healthcare/                # 헬스케어 API 서비스
├── HectoApp/                  # 메인 앱 서비스
├── HectoHealthcareHomePage/   # 헬스케어 홈페이지 (Gradle)
├── HectoHomePage/             # 헥토 홈페이지
├── Medibuddy/                 # 메디버디 서비스
├── OKHilda/                   # OK힐다 서비스
├── frontend/                  # 프론트엔드 프로젝트
│   ├── ai-assistant/          # AI 어시스턴트
│   ├── user-pc-v2/            # 유저 PC 버전
│   └── user-v2/               # 유저 모바일 버전
├── user-backend-v2/           # 유저 백엔드 v2 서비스들
├── v2/                        # v2 관리자 서비스
└── java-spring-thread-pool-test/  # 테스트 프로젝트
```

## 기술 스택

### Backend
- **Java 17**
- **Spring Boot 3.2.x**
- **Spring Cloud** (Eureka, Gateway, OpenFeign)
- **JPA / QueryDSL 5.0**
- **MySQL**
- **Ehcache** (캐싱)
- **Resilience4j** (서킷 브레이커)

### Build Tools
- **Gradle** (신규 프로젝트)
- **Maven** (레거시 프로젝트)

### Frontend
- Vue.js / Nuxt.js

## 공통 패키지 구조

```
com.hecto.lab/
├── common/          # 공통 설정, 예외 처리
├── constant/        # 상수 정의
├── controller/      # REST API 컨트롤러
├── model/           # JPA 엔티티
├── repository/      # JPA Repository
├── service/         # 비즈니스 로직
├── feign/           # Feign Client 정의
└── util/            # 유틸리티 클래스
```

## 빌드 명령어

### Gradle 프로젝트
```bash
./gradlew clean build
./gradlew bootRun
./gradlew test
```

### Maven 프로젝트
```bash
mvn clean package
mvn spring-boot:run
mvn test
```

## 프로파일

- `test` - 테스트 환경
- `stage` - 스테이징 환경
- `real` - 운영 환경

## 코딩 컨벤션

### 기본 규칙
- Lombok 사용 (`@Getter`, `@Setter`, `@Builder` 등)
- DTO/Entity 분리
- Service 레이어에서 비즈니스 로직 처리
- **Service는 Read(조회)와 Write(쓰기)를 분리한다.**
  - 조회 전용 서비스: `XxxReadService` (`@Transactional(readOnly = true)`)
  - 쓰기 전용 서비스: `XxxService` (`@Transactional`)
- Repository는 JPA + QueryDSL 조합 사용
- REST API는 `/api/v1/...` 형식 권장

### 코드 스타일
1. 삼항 연산자 사용을 지양한다.
2. 한 줄에는 하나의 책임만 가진다.
3. 메서드는 가능한 짧게 유지한다.
4. 중첩 if 문을 줄이고 early return을 사용한다.
5. else 사용을 최소화한다.
6. 매직 넘버를 직접 쓰지 말고 상수로 정의한다.
7. boolean 변수는 긍정형 이름을 사용한다.
8. 의미 없는 축약어를 사용하지 않는다.
9. 변수명과 메서드명은 역할이 드러나도록 작성한다.
10. 주석보다 이름으로 설명한다.
11. null 반환을 지양하고 Optional 또는 객체를 사용한다.
12. 하나의 메서드는 하나의 일만 하도록 만든다.
13. 조건문이 길어지면 의미 있는 변수로 분리한다.
14. 반복되는 코드는 반드시 메서드로 추출한다.
15. 코드 깊이(indent)는 2단계를 넘지 않도록 한다.
16. 한 메서드에서 여러 수준의 추상화를 섞지 않는다.
17. 예외는 숨기지 말고 명확하게 처리한다.
18. 컬렉션은 null 대신 빈 컬렉션을 반환한다.
19. getter/setter 남용을 지양한다.
20. 테스트 가능한 구조로 작성한다.
21. 로그는 의도를 설명하도록 작성한다.
22. 상수는 의미 있는 이름으로 선언한다.
23. switch 대신 다형성을 우선 고려한다.
24. 불필요한 public 노출을 줄인다.
25. 코드 스타일보다 가독성을 우선한다.

### 추상화 원칙
1. 하나의 메서드에는 하나의 추상화 수준만 존재해야 한다.
2. 상위 추상화 코드에서 하위 구현 세부사항을 직접 다루지 않는다.
3. 구현보다 의도를 먼저 드러내는 이름을 사용한다.
4. 메서드 이름만 보고도 내부 구현을 추측할 수 있어야 한다.
5. 추상화 레벨이 다른 로직은 반드시 메서드로 분리한다.
6. 비즈니스 로직과 기술 구현 로직을 섞지 않는다.
7. 상위 로직은 "무엇을 하는가"를 표현하고, 하위 로직은 "어떻게 하는가"를 담당한다.
8. 구현 세부사항은 가능한 가장 낮은 레벨로 숨긴다.
9. 외부에 노출되는 인터페이스는 최소한의 개념만 포함한다.
10. 추상화는 재사용보다 이해를 쉽게 만드는 것을 우선한다.
11. 읽는 사람이 구현을 따라가지 않아도 흐름을 이해할 수 있어야 한다.
12. 한 메서드 안에서 서로 다른 관심사를 처리하지 않는다.
13. 메서드 이름이 길어지는 것은 추상화가 부족하다는 신호로 본다.
14. 조건 분기가 많아지면 추상화를 다시 설계한다.
15. 구현 설명이 필요한 코드는 추상화가 잘못된 것으로 본다.
16. 계층 간 의존성은 한 방향으로만 흐르게 한다.
17. 상위 계층은 하위 계층의 내부 구조를 몰라야 한다.
18. 추상화는 숨김이 아니라 의도 표현이다.
19. 공통 로직 추출보다 책임 분리가 우선이다.
20. 추상화는 코드 재사용보다 변경에 강한 구조를 목표로 한다.

## Git 커밋 규칙

- 커밋 메시지에 `Co-Authored-By` 등 AI 관련 기록을 남기지 않는다.

## 주의사항

- 각 서브 프로젝트는 독립적인 Git 저장소일 수 있음
- 환경별 설정 파일(`application-{profile}.properties`) 확인 필요
- Eureka 서버 연동 시 서비스 등록 확인
