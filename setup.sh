#!/bin/bash
# =============================================================================
# Intel iMac 환경 초기 세팅 스크립트 (sudo 권한 불필요)
# 매주 월요일 클렌징 후 실행
#
# 사용법:
#   bash setup.sh                  전체 단계 실행
#   bash setup.sh --dry-run        실제로 아무것도 안 하고 실행될 단계만 출력
#   bash setup.sh --only apps,git  콤마로 구분한 특정 단계만 실행
#   bash setup.sh --list           실행 가능한 단계 이름 목록 출력
#   bash setup.sh -h               도움말
#
# 참고: macOS 기본 /bin/bash는 3.2라 associative array(-A)를 못 쓴다.
#       그래서 아래 단계 목록은 일부러 병렬 인덱스 배열로 짰다.
# =============================================================================

set -euo pipefail

# =============================================================================
# 설정값 — 바뀔 만한 값은 여기 모아둠
# =============================================================================

GIT_USER_NAME="b0e2"
GIT_USER_EMAIL="beenjeong02@gmail.com"

APP_DIR="$HOME/Applications"

ITERM2_VERSION="3_5_13"
ITERM2_URL="https://iterm2.com/downloads/stable/iTerm2-${ITERM2_VERSION}.zip"

GHOSTTY_VERSION="1.3.1"
GHOSTTY_URL="https://release.files.ghostty.org/${GHOSTTY_VERSION}/Ghostty.dmg"

HERDR_INSTALL_URL="https://herdr.dev/install.sh"

# =============================================================================
# 로깅
# =============================================================================

LOG_FILE="${LOG_FILE:-$HOME/Library/Logs/mac-setup.log}"
mkdir -p "$(dirname "$LOG_FILE")"

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_NC='\033[0m'

_log() {
    local level="$1" color="$2" msg="$3"
    printf "%b[%s]%b %s\n" "$color" "$level" "$C_NC" "$msg"
    printf "[%s] [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" >> "$LOG_FILE"
}
info() { _log "INFO" "$C_CYAN"   "$1"; }
ok()   { _log "OK"   "$C_GREEN"  "$1"; }
warn() { _log "WARN" "$C_YELLOW" "$1"; }
fail() { _log "FAIL" "$C_RED"    "$1"; }

# =============================================================================
# 앱 설치 (~/Applications)
# =============================================================================

_APPS_TMPDIR=""
_apps_tmpdir() {
    if [ -z "$_APPS_TMPDIR" ]; then
        _APPS_TMPDIR=$(mktemp -d)
        trap 'rm -rf "$_APPS_TMPDIR"' EXIT
    fi
    echo "$_APPS_TMPDIR"
}

install_dmg_app() {
    local name="$1" url="$2" app_name="$3"
    if [ -d "$APP_DIR/$app_name" ] || [ -d "/Applications/$app_name" ]; then
        ok "$name 이미 설치됨"
        return 0
    fi

    info "$name 다운로드 중..."
    local tmpdir dmg_path mount_point
    tmpdir=$(_apps_tmpdir)
    dmg_path="$tmpdir/$name.dmg"

    curl -fsSL -o "$dmg_path" "$url" || { warn "$name 다운로드 실패"; return 1; }

    mount_point=$(hdiutil attach "$dmg_path" -nobrowse -quiet 2>/dev/null | tail -1 | awk '{print $NF}')
    if [ -z "$mount_point" ]; then
        mount_point=$(hdiutil attach "$dmg_path" -nobrowse -quiet 2>/dev/null | tail -1 | cut -f3-)
    fi

    if [ -d "$mount_point/$app_name" ]; then
        cp -R "$mount_point/$app_name" "$APP_DIR/" && ok "$name 설치 완료 ($APP_DIR)" || warn "$name 복사 실패"
    else
        warn "$name: 마운트된 볼륨에서 $app_name을 찾을 수 없습니다"
    fi

    hdiutil detach "$mount_point" -quiet 2>/dev/null || true
    rm -f "$dmg_path"
}

install_zip_app() {
    local name="$1" url="$2" app_name="$3"
    if [ -d "$APP_DIR/$app_name" ] || [ -d "/Applications/$app_name" ]; then
        ok "$name 이미 설치됨"
        return 0
    fi

    info "$name 다운로드 중..."
    local tmpdir zip_path
    tmpdir=$(_apps_tmpdir)
    zip_path="$tmpdir/$name.zip"

    curl -fsSL -o "$zip_path" "$url" || { warn "$name 다운로드 실패"; return 1; }
    unzip -q "$zip_path" -d "$APP_DIR" && ok "$name 설치 완료 ($APP_DIR)" || warn "$name 압축 해제 실패"
    rm -f "$zip_path"
}

install_herdr() {
    if command -v herdr >/dev/null 2>&1; then
        ok "Herdr 이미 설치됨"
        return 0
    fi
    info "Herdr 설치 중..."
    curl -fsSL "$HERDR_INSTALL_URL" | sh && ok "Herdr 설치 완료" || warn "Herdr 설치 실패"
}

step_install_apps() {
    mkdir -p "$APP_DIR"
    install_zip_app "iTerm2"  "$ITERM2_URL"  "iTerm.app"
    install_dmg_app "Ghostty" "$GHOSTTY_URL" "Ghostty.app"
    install_herdr
}

# =============================================================================
# zsh 환경 설정
# =============================================================================

step_install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        ok "Oh My Zsh 이미 설치됨"
        return 0
    fi
    info "Oh My Zsh 설치 중..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
        && ok "Oh My Zsh 설치 완료" || warn "Oh My Zsh 설치 실패"
}

_install_zsh_plugin() {
    local name="$1" repo="$2"
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local dest="$zsh_custom/plugins/$name"

    if [ -d "$dest" ]; then
        ok "zsh 플러그인 '$name' 이미 설치됨"
        return 0
    fi
    info "zsh 플러그인 '$name' 설치 중..."
    git clone --depth=1 "$repo" "$dest" && ok "'$name' 설치 완료" || warn "'$name' 설치 실패"
}

step_install_zsh_plugins() {
    _install_zsh_plugin "zsh-autosuggestions"     "https://github.com/zsh-users/zsh-autosuggestions.git"
    _install_zsh_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
}

step_configure_zshrc() {
    local zshrc="$HOME/.zshrc"
    if [ ! -f "$zshrc" ]; then
        warn ".zshrc 파일을 찾을 수 없습니다"
        return 0
    fi

    # Oh My Zsh 설치 과정에서 .zshrc를 자체 템플릿으로 덮어쓰기 때문에,
    # 이 스크립트에서 .zshrc를 손대는 건 반드시 oh-my-zsh 단계 이후여야 함.
    cp "$zshrc" "$zshrc.bak.$(date +%Y%m%d%H%M%S)"

    info ".zshrc 플러그인 설정 중..."
    if grep -q "^plugins=" "$zshrc"; then
        sed -i '' 's/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$zshrc" \
            && ok ".zshrc 플러그인 설정 업데이트 완료" \
            || warn ".zshrc 플러그인 업데이트 실패"
    fi

    info "~/.local/bin PATH 설정 중... (herdr 등 로컬 바이너리용)"
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    if grep -qF "$path_line" "$zshrc"; then
        ok "~/.local/bin PATH 이미 설정되어 있음"
    else
        {
            echo ""
            echo "# ~/.local/bin 바이너리(herdr 등)를 위한 PATH 추가 (imac-init)"
            echo "$path_line"
        } >> "$zshrc"
        ok "~/.local/bin PATH 추가 완료 (새 터미널부터 적용됨, 지금 창은 'source ~/.zshrc' 필요)"
    fi
}

# =============================================================================
# macOS Gureum 한글 입력기 (2벌식) 활성화
# =============================================================================

step_setup_korean_input() {
    info "한글 입력기 설정 중..."

    # macOS 기본 bash(3.2)는 $() 명령 치환 안의 heredoc을 파싱하지 못하므로
    # Swift 코드를 임시 파일로 내보낸 뒤 실행한다.
    local swift_dir swift_file result
    swift_dir=$(mktemp -d)
    swift_file="$swift_dir/korean_input.swift"

    cat > "$swift_file" <<'SWIFT'
import Carbon
import Foundation
let parentID = "org.youknowone.inputmethod.Korean"
let modeID = "org.youknowone.inputmethod.Gureum.han2"
let gureumPrefix = "org.youknowone.inputmethod.Gureum."

func sources(_ id: String?, includeAll: Bool) -> [TISInputSource] {
    let filter = id.map { [kTISPropertyInputSourceID: $0] as CFDictionary }
    return (TISCreateInputSourceList(filter, includeAll)?
        .takeRetainedValue() as? [TISInputSource]) ?? []
}
func sourceID(_ s: TISInputSource) -> String {
    guard let p = TISGetInputSourceProperty(s, kTISPropertyInputSourceID) else { return "" }
    return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
}

// 1) han2가 없으면 부모 한글 입력기를 켠다.
if sources(modeID, includeAll: false).isEmpty,
   let parent = sources(parentID, includeAll: true).first {
    TISEnableInputSource(parent)
    RunLoop.current.run(until: Date().addingTimeInterval(5))
}

// 2) 로마자보다 han2를 먼저 선택한다.
//    현재 선택된 입력 소스는 TISDisableInputSource로 끌 수 없기 때문.
var selected = "not-enabled"
if let han2 = sources(modeID, includeAll: false).first {
    selected = TISSelectInputSource(han2) == noErr ? "ok" : "select-failed"
    RunLoop.current.run(until: Date().addingTimeInterval(1))
}

// 3) han2를 제외한 Gureum 하위 모드(로마자/쿼티 등)를 ID로 찾아 전부 비활성화한다.
//    includeAll:false = 현재 켜져 있는 소스만 대상.
var disabled: [String] = []
for s in sources(nil, includeAll: false) {
    let id = sourceID(s)
    if id.hasPrefix(gureumPrefix) && id != modeID {
        if TISDisableInputSource(s) == noErr { disabled.append(id) }
    }
}
print(selected + " disabled:" + (disabled.isEmpty ? "none" : disabled.joined(separator: ",")))
SWIFT

    result=$(swift "$swift_file" 2>/dev/null) || result="swift-failed"
    rm -rf "$swift_dir"

    case "$result" in
        ok*)          ok "한글 입력기(2벌식) 설정 완료 (${result#ok })" ;;
        not-enabled*) warn "한글 입력기를 활성화하지 못했습니다 (Gureum 설치 여부 확인)" ;;
        *)            warn "한글 입력기 설정 실패: $result" ;;
    esac
}

# =============================================================================
# Spotlight 단축키 초기화
# =============================================================================

step_setup_spotlight() {
    info "Spotlight 단축키 초기화 중..."

    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '
<dict>
    <key>enabled</key><true/>
    <key>value</key><dict>
        <key>parameters</key><array>
            <integer>65535</integer><integer>49</integer><integer>1048576</integer>
        </array>
        <key>type</key><string>standard</string>
    </dict>
</dict>' && ok "Spotlight 단축키 기본값 복원 완료" || { warn "Spotlight 단축키 설정 실패"; return 1; }

    # 재로그인 없이 즉시 반영 (symbolichotkeys 설정 다시 로드)
    local activate_settings="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
    if [ -x "$activate_settings" ]; then
        "$activate_settings" -u 2>/dev/null \
            && ok "Spotlight 단축키 즉시 반영 완료" \
            || warn "Spotlight 단축키 즉시 반영 실패 (재로그인 시 적용됨)"
    else
        warn "activateSettings를 찾을 수 없어 즉시 반영 생략 (재로그인 시 적용됨)"
    fi
}

# =============================================================================
# CapsLock → Fn 매핑 (한영 전환)
# =============================================================================

step_setup_capslock() {
    info "키보드 한영 전환 설정 중..."

    # CapsLock → Fn(Globe) 매핑 정의 (즉시 적용 + LaunchAgent 양쪽에서 재사용)
    # 0xFF00000003 = Apple 벤더 정의 Fn/Globe 키. AppleFnUsageType=1과 함께
    # 동작해야 CapsLock 한 번에 입력 소스(한/영)가 전환됨.
    local capslock_to_fn='{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0xFF00000003}]}'
    hidutil property --set "$capslock_to_fn" >/dev/null \
        && ok "CapsLock → Fn 매핑 적용 완료" || { warn "CapsLock 매핑 실패"; return 1; }

    # Fn 키 동작을 "입력 소스 변경"으로 설정
    defaults write com.apple.HIToolbox AppleFnUsageType -int 1

    # CapsLock 딜레이 제거
    hidutil property --set '{"CapsLockDelayOverride":0}' >/dev/null 2>&1 \
        && ok "CapsLock 딜레이 제거 완료" \
        || warn "CapsLock 딜레이 설정 실패"

    # LaunchAgent로 재부팅 후에도 유지
    local launch_agent_dir="$HOME/Library/LaunchAgents"
    local launch_agent_plist="$launch_agent_dir/com.example.KeyRemapping.plist"
    mkdir -p "$launch_agent_dir"

    cat > "$launch_agent_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.KeyRemapping</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>${capslock_to_fn}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

    ok "LaunchAgent 설정 완료: $launch_agent_plist"
}

# =============================================================================
# Finder 설정
# =============================================================================

step_setup_finder() {
    info "Finder 설정 중..."
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    killall Finder 2>/dev/null || true
    ok "Finder 설정 완료 (숨김 파일/확장자 표시, 경로·상태 막대, 목록 보기)"
}

# =============================================================================
# Dock 설정
# =============================================================================

step_setup_dock() {
    info "Dock 설정 중..."
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock persistent-apps -array
    killall Dock 2>/dev/null || true
    ok "Dock 설정 완료 (최근 앱 숨김, 기본 앱 제거)"
}

# =============================================================================
# Git 기본 설정
# =============================================================================

step_configure_git() {
    info "Git 설정 중..."
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global init.defaultBranch main
    ok "Git 설정 완료 ($GIT_USER_NAME <$GIT_USER_EMAIL>)"
}

# =============================================================================
# 실행기
# =============================================================================

if [[ "$(uname)" != "Darwin" ]]; then
    fail "이 스크립트는 macOS 전용입니다."
    exit 1
fi

# 인덱스가 서로 짝을 이루는 두 배열 (bash 3.2 호환, associative array 안 씀)
STEP_NAMES=(apps oh-my-zsh zsh-plugins zshrc korean-input spotlight capslock finder dock git)
STEP_FUNCS=(step_install_apps step_install_oh_my_zsh step_install_zsh_plugins step_configure_zshrc \
            step_setup_korean_input step_setup_spotlight step_setup_capslock step_setup_finder \
            step_setup_dock step_configure_git)

DRY_RUN=0
ONLY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --only) ONLY="${2:-}"; shift 2 ;;
        --list)
            printf '%s\n' "${STEP_NAMES[@]}"
            exit 0
            ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            fail "알 수 없는 옵션: $1  (도움말: bash setup.sh -h)"
            exit 1
            ;;
    esac
done

RESULTS=()

run_step() {
    local name="$1" func="$2"
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] $name → $func"
        return 0
    fi
    if "$func"; then
        RESULTS+=("OK   $name")
    else
        RESULTS+=("FAIL $name")
        warn "'$name' 단계에서 문제가 발생했지만 다음 단계로 계속 진행합니다."
    fi
}

i=0
while [ "$i" -lt "${#STEP_NAMES[@]}" ]; do
    name="${STEP_NAMES[$i]}"
    func="${STEP_FUNCS[$i]}"
    i=$((i + 1))

    if [[ -n "$ONLY" && ",$ONLY," != *",$name,"* ]]; then
        continue
    fi
    run_step "$name" "$func"
done

if [[ $DRY_RUN -eq 0 ]]; then
    echo
    info "===== 실행 결과 요약 ====="
    printf '%s\n' "${RESULTS[@]}"
fi