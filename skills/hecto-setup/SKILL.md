---
name: hecto-setup
description: "HectoProject용 CLAUDE.md를 현재 프로젝트에 설정합니다. /hecto-setup으로 실행합니다."
allowed-tools:
  - Bash(mkdir:*)
  - Bash(cp:*)
  - Bash(ls:*)
  - Read
  - Write
---

# HectoProject 설정

현재 프로젝트에 HectoProject용 CLAUDE.md 가이드라인을 설정한다.

## 실행 조건

| 트리거 | 설명 |
|--------|------|
| `/hecto-setup` | HectoProject CLAUDE.md를 현재 프로젝트에 복사 |

## 워크플로우

1. 현재 프로젝트의 `.claude/` 디렉토리 존재 여부 확인
2. 없으면 `.claude/` 디렉토리 생성
3. 이 스킬의 `references/HH_CLAUDE.md`를 읽음
4. `.claude/CLAUDE.md`에 내용을 작성
5. 이미 `.claude/CLAUDE.md`가 존재하면 사용자에게 덮어쓰기 확인

## 참고

- HH_CLAUDE.md는 Hecto Lab 모노레포(Spring Boot 3.2.x, JPA, QueryDSL) 전용 가이드라인
- 다른 프로젝트에는 적합하지 않을 수 있음
- 프로젝트 구조, 기술 스택, 코딩 컨벤션 25조항, 추상화 원칙 20조항 포함
