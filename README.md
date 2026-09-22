# imac-init

Intel iMac 개발 환경 초기 세팅 스크립트. sudo 권한 불필요, 매주 월요일 클렌징 후 실행하는 용도로 씀.

## 하는 일

- **앱 설치**: Herdr
- **zsh 환경**: Oh My Zsh, zsh-autosuggestions, zsh-syntax-highlighting, `.zshrc` 플러그인 설정, `~/.local/bin` PATH 등록
- **한글 입력기**: Gureum 2벌식 활성화, 나머지 하위 모드 비활성화
- **키보드**: CapsLock → 한영 전환(Fn) 매핑 (재부팅 후에도 유지되도록 LaunchAgent 등록)
- **Spotlight**: 단축키 기본값(⌘Space) 복원
- **Finder**: 숨김 파일·전체 확장자 표시, 경로·상태 막대 표시, 기본 보기를 목록으로 설정
- **Dock**: 최근 사용 앱 숨김, 기본 앱 아이콘 제거
- **Git**: `user.name` / `user.email` / `init.defaultBranch` 전역 설정

## 사용법

```bash
git clone https://github.com/b0e2/imac-init.git imac-init
cd imac-init
bash setup.sh
```

옵션:

```bash
bash setup.sh --dry-run        # 실제로 실행하지 않고 어떤 단계가 돌지만 확인
bash setup.sh --only apps,git  # 콤마로 구분한 특정 단계만 실행
bash setup.sh --list           # 실행 가능한 단계 이름 목록
bash setup.sh -h               # 도움말
```

실행이 끝나면 단계별 성공/실패 요약이 출력되고, `~/Library/Logs/mac-setup.log`에도 기록이 남음.

## 값 바꾸기

git 계정, 앱 버전/다운로드 URL은 `setup.sh` 상단 "설정값" 섹션에 모여 있음. 다른 값 쓸 땐 거기만 수정하면 됨.

```bash
GIT_USER_NAME="b0e2"
GIT_USER_EMAIL="beenjeong02@gmail.com"
ITERM2_VERSION="3_5_13"
GHOSTTY_VERSION="1.3.1"
```

## 요구 사항

- macOS (Intel/Apple Silicon 무관하게 동작하지만 CapsLock 매핑·한글 입력기 부분은 Intel iMac 기준으로 검증됨)
- Gureum 입력기가 미리 설치되어 있어야 한글 입력기 단계가 정상 동작함
- 시스템 기본 `/bin/bash`(3.2)로 실행됨 — associative array 등 최신 bash 문법 안 씀

## 알려진 이슈

- 재단 네트워크에서는 `iterm2.com`, `release.files.ghostty.org` 도메인이 막혀 있어 iTerm2·Ghostty는 다운로드가 안 됨. 스크립트 코드 자체엔 여전히 포함되어 있으니, 다른 네트워크(핫스팟 등)에서 `bash setup.sh --only apps` 로 나중에 따로 설치하면 됨.
- herdr 설치 직후 `command not found: herdr`가 뜨면 `~/.local/bin`이 아직 PATH에 안 잡힌 것 — `zshrc` 단계까지 실행됐다면 새 터미널을 열거나 `source ~/.zshrc` 하면 해결됨.

## 새 단계 추가하기

1. `step_xxx` 형태의 함수 작성 (`info` / `ok` / `warn` / `fail` 로깅 함수 사용 가능)
2. 스크립트 하단 `STEP_NAMES` / `STEP_FUNCS` 배열에 같은 순서로 이름·함수 추가