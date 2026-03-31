---
name: report
description: |
  /beom 세션 결과 보고서 생성. .dev/ 산출물을 종합하여 구조화된 보고서를 .dev/report.md에 작성한다.
  Stop 훅에 의해 자동 호출되거나 사용자가 직접 /report로 호출할 수 있다.
---

# 결과 보고서 생성

/beom 파이프라인의 산출물을 종합하여 구조화된 결과 보고서를 작성한다.

한국어로 응답한다. 이모지를 사용하지 않는다.

## 산출물 수집

다음 파일을 순서대로 Read한다. 없는 파일은 건너뛴다.

| 파일 | 용도 | 필수 |
|------|------|------|
| `.dev/state.md` | 세션 메타 (브랜치, 베이스, 프로젝트 타입) | 필수 |
| `.dev/prd.md` | 요구사항 + 수용 기준 | 선택 |
| `.dev/design.md` | 설계 요약 | 선택 |
| `.dev/codemap.md` | 변경 파일 맵 | 선택 |
| `.dev/self-check.md` | 자기점검 결과 | 선택 |
| `.dev/lens-report.md` | 정책 분석 결과 | 선택 |
| `.dev/research-report.md` | 조사 결과 | 선택 |

추가로 다음 정보를 수집한다:
1. `git log --oneline` — 현재 브랜치의 커밋 목록 (베이스 브랜치 대비)
2. `git diff --stat {base}...HEAD` — 변경 파일 통계
3. `docs/plan/` — 계획 파일이 있으면 TODO 검증 상태 요약

## 보고서 구조

다음 포맷으로 `.dev/report.md`에 Write한다:

```markdown
# 결과 보고서

> 생성일: {YYYY-MM-DD HH:mm}
> 브랜치: {branch} (base: {base})
> 프로젝트 타입: {project-type}

## 요약

{1~3문장으로 이번 작업의 목적과 결과를 요약}

## 요구사항 (PRD)

{prd.md가 있으면 핵심 요구사항과 수용 기준을 요약. 없으면 "PRD 없음" 표시}

## 설계

{design.md가 있으면 주요 설계 결정 요약. 없으면 "설계서 없음" 표시}

## 변경 사항

### 파일 통계
{git diff --stat 결과}

### 주요 변경
{codemap.md 기반으로 변경된 파일과 역할을 목록으로 정리}

## 커밋 이력

{git log --oneline 결과. 베이스 브랜치 대비 커밋 목록}

## 검증 결과

### 자기점검
{self-check.md 요약: Critical/Warning/Info 개수}

### TODO 검증
{계획 파일이 있으면 VERIFIED/FAILED/PENDING 요약. 없으면 생략}

## 미해결 사항

{자기점검 Warning/QUESTION, TODO FAILED/MANUAL 항목을 목록으로 정리. 없으면 "미해결 사항 없음"}
```

## 작성 규칙

- **사실만 기록한다.** 산출물에 없는 내용을 추측하여 작성하지 않는다.
- **간결하게 작성한다.** 각 섹션은 원본의 핵심만 요약한다. 원본 전체를 복사하지 않는다.
- **누락된 산출물은 명시한다.** "PRD 없음", "설계서 없음" 등으로 표시한다.
- 파일이 `.dev/state.md` 하나뿐이면 변경 사항 + 커밋 이력만으로 경량 보고서를 작성한다.

## 완료

보고서를 `.dev/report.md`에 Write한 후, 사용자에게 보고서 경로와 핵심 요약 1~2줄을 출력한다.
