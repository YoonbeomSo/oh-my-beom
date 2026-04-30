# [WEB-TEST-REQUIRED] 자동 실행 절차

QA 리뷰 결과에 `### [WEB-TEST-REQUIRED]` 라인이 포함되면 오케스트레이터가 **질문 없이 즉시** 수행하는 절차. dev-beom/fix-beom/persist-beom 공통.

## 트리거

QA 결과 본문에 다음 라인이 포함되어 있을 때:

```
### [WEB-TEST-REQUIRED]
```

또는 `web-test-detector` 훅이 `.dev/web-test-required` 마커를 생성한 경우. 둘 중 하나라도 발견하면 즉시 실행.

## 절대 금지

다음 질문은 **금지**:
- "서버를 실행할까요?"
- "웹 테스트 진행할까요?"
- "서버가 필요합니다"

## 실행 절차

### 1. 서버 기동

`playwright.config.ts`의 `webServer` 설정이 있으면 Playwright가 자동 기동하므로 이 단계 생략. 그 외:

- `package.json` `scripts`에서 dev/start 명령 감지(`dev`, `start`, `serve` 우선순위)
- `Bash(command="npm run dev &", run_in_background=true)` 또는 해당 런타임 명령
- 서버 ready 대기 (URL 접근 가능 확인, 최대 30초)

### 2. URL 자동 결정 (사용자 질문 금지)

다음 우선순위로 결정:

1. `playwright.config.ts`의 `use.baseURL` 값
2. `package.json`의 dev 스크립트에서 포트 추출 → `http://localhost:{port}`
3. 기본값: `http://localhost:3000`

### 3. 웹 테스트 실행

```
Skill("oh-my-beom:web-test", args="{결정된 URL} {변경 사항 기반 시나리오}")
```

### 4. 서버 정리

웹 테스트 완료 후 기동한 서버 프로세스를 종료한다. 백그라운드 PID는 `.dev/*.pid`에서 회수.

## 마커 처리

웹 테스트 통과 시 `.dev/web-test-passed` 생성 (`pre-tool-guard`가 커밋 차단 해제). 실패 시 마커 미생성 → 커밋 차단 유지.
