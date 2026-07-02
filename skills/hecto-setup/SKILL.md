---
name: hecto-setup
description: "현재 프로젝트에 CLAUDE.md 가이드라인을 설정합니다. 사용자 템플릿(~/.claude/hecto-setup.template.md)이 있으면 우선 사용하고, 없으면 저장소 기본 템플릿을 적용합니다. /hecto-setup으로 실행합니다."
allowed-tools:
  - Bash(mkdir:*)
  - Bash(cp:*)
  - Bash(ls:*)
  - Read
  - Write
---

# 프로젝트 CLAUDE.md 설정

현재 프로젝트에 CLAUDE.md 가이드라인을 설정한다.

## 실행 조건

| 트리거 | 설명 |
|--------|------|
| `/hecto-setup` | CLAUDE.md 템플릿을 현재 프로젝트에 적용 |

## 템플릿 우선순위

1. **사용자 템플릿 우선**: `~/.claude/hecto-setup.template.md`가 있으면 이 파일을 사용한다.
2. **저장소 기본 템플릿 fallback**: 사용자 템플릿이 없으면 이 스킬의 `references/PROJECT_CLAUDE_TEMPLATE.md`를 사용한다.

> **커스터마이징**: 프로젝트에 맞는 코딩 컨벤션·아키텍처 정보를 담은 `~/.claude/hecto-setup.template.md`를 만들어 두면, 저장소를 바꿔도 일관된 설정을 적용할 수 있다.

## 워크플로우

1. `~/.claude/hecto-setup.template.md` 존재 여부 확인
   - 있으면 → 해당 파일을 템플릿으로 사용
   - 없으면 → 이 스킬의 `references/PROJECT_CLAUDE_TEMPLATE.md`를 템플릿으로 사용
2. 현재 프로젝트의 `.claude/` 디렉토리 존재 여부 확인
3. 없으면 `.claude/` 디렉토리 생성
4. 선택된 템플릿을 읽어 `.claude/CLAUDE.md`에 작성
5. 이미 `.claude/CLAUDE.md`가 존재하면 사용자에게 덮어쓰기 확인

## 참고

- 저장소 기본 템플릿(`references/PROJECT_CLAUDE_TEMPLATE.md`)에는 Spring Boot 프로젝트 기반의 코딩 컨벤션 25조항, 추상화 원칙 20조항, Git 커밋 규칙이 포함되어 있다.
- 프로젝트 구조·패키지명·서비스명 등은 플레이스홀더(`MyProject`, `service-a`, `com.example.app`)로 기재되어 있으니, 실제 프로젝트에 맞게 수정한다.
- 사용자 템플릿에는 프로젝트 고유 정보(실제 서비스명, 패키지 구조 등)를 담을 수 있다. 이 파일은 `~/.claude/`(글로벌, 공개 저장소 밖)에만 보관한다.
