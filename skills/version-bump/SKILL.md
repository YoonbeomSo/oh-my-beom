---
name: version-bump
version: 1.0.0
description: 플러그인 버전을 semver(patch/minor/major) 또는 명시 버전으로 일괄 변경. package.json, .claude-plugin/marketplace.json, .claude-plugin/plugin.json 3개 파일을 동시에 동기화하여 버전 드리프트를 방지한다.
argument-hint: "[patch|minor|major|x.y.z]"
allowed-tools:
  - Read
  - Edit
  - Bash(python3:*)
  - Bash(git diff:*)
  - Bash(git status:*)
  - Bash(test:*)
  - AskUserQuestion
---

플러그인의 3개 메타 파일을 동일한 새 버전으로 일괄 업데이트한다. 항상 한국어로 응답한다.

## 대상 파일

| 파일 | 경로 | 키 |
|------|------|-----|
| package.json | `<root>/package.json` | `.version` |
| plugin.json | `<root>/.claude-plugin/plugin.json` | `.version` |
| marketplace.json | `<root>/.claude-plugin/marketplace.json` | `.plugins[source="./"].version` (없으면 첫 번째 항목) |

## Arguments

- `patch` — 0.0.X 증가 (기본값. 인자 없을 때)
- `minor` — 0.X.0 증가, patch는 0으로 리셋
- `major` — X.0.0 증가, minor/patch는 0으로 리셋
- `x.y.z` — 명시적 버전(semver 형식)

## 사전 확인

1. Git 저장소인지 확인: `git rev-parse --show-toplevel`
2. 3개 파일이 모두 존재하는지 확인. 누락 시: 사용자에게 어떤 파일이 없는지 보고 후 종료
3. 현재 버전 추출 (3개 파일):
   ```bash
   python3 -c "import json; print(json.load(open('package.json')).get('version'))"
   python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json')).get('version'))"
   python3 -c "
   import json
   d = json.load(open('.claude-plugin/marketplace.json'))
   plugins = d.get('plugins', [])
   target = next((p for p in plugins if p.get('source') == './'), plugins[0] if plugins else None)
   print(target.get('version') if target else 'MISSING')
   "
   ```
4. **3개가 일치하지 않으면**: 사용자에게 현재 상태를 보고하고 어떤 값을 기준으로 할지 AskUserQuestion으로 선택지 제시
   - 옵션: `package.json 값 사용` / `plugin.json 값 사용` / `marketplace.json 값 사용` / `직접 입력`

## 새 버전 계산

기준 버전(`MAJOR.MINOR.PATCH`)을 결정한 후 인자에 따라 증가:

```python
parts = current.split('.')
major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

if arg == 'patch':
    patch += 1
elif arg == 'minor':
    minor += 1; patch = 0
elif arg == 'major':
    major += 1; minor = 0; patch = 0
elif arg matches r'^\d+\.\d+\.\d+$':
    new_version = arg  # 명시 버전 그대로
else:
    error: "지원하지 않는 인자. patch/minor/major 또는 x.y.z 형식"

new_version = f"{major}.{minor}.{patch}"
```

명시 버전을 받은 경우, 현재 버전보다 **낮으면** 사용자에게 다운그레이드 확인 (`AskUserQuestion`).

## 일괄 적용

3개 파일을 모두 새 버전으로 업데이트한다. **반드시 동시에 진행** — 일부만 성공하면 hook(`version-sync-check`)이 다음 커밋을 차단한다.

```python
# 각 파일에 대해 Edit 도구로 정확히 한 줄만 교체
# 1. package.json
#    "version": "<old>",  →  "version": "<new>",
# 2. plugin.json (동일 패턴)
# 3. marketplace.json
#    "version": "<old>"   →  "version": "<new>"   (콤마 없음, plugins 배열 안)
```

각 파일의 변경은 Edit 도구로 수행. 변경 전후 검증:

```bash
git diff -- package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json | head -30
```

3개 파일 모두에서 정확히 한 줄(version 라인)만 변경됐는지 확인. 다른 변경이 끼어 있으면 사용자에게 보고하고 진행 여부 확인.

## 결과 보고

```
✅ 버전 갱신 완료: <old> → <new>
   - package.json
   - .claude-plugin/plugin.json
   - .claude-plugin/marketplace.json

다음 단계:
   - 변경사항 검토: git diff
   - 커밋: /commit  (또는 다른 변경사항과 함께 커밋)
```

## 자동 staging 금지

이 스킬은 파일만 수정하고 `git add`는 수행하지 않는다. 사용자가 다른 변경사항과 함께 커밋할 수 있도록 결정권을 남긴다.

## 금지사항

- 3개 파일 중 일부만 갱신 금지 (hook이 차단함)
- 다른 메타 파일(README의 "v2.x" 표기 등) 자동 변경 금지 — 너무 많은 파일을 건드리면 의도치 않은 수정 위험. 명시적 요청 시에만 수행
- 커밋/푸시 자동 실행 금지
