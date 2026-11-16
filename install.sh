#!/bin/sh
# desk 에이전트 설치 스크립트 (리눅스 서버용)
#
# 계정(조직)에 등록 (권장): 관리자가 만든 등록 코드를 넣습니다.
#   curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- --enrol 등록코드@서버주소 [서버이름]
#
# 예전 방식 (그룹 키):
#   curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- 그룹키 [서버이름]
#
# 등록 코드는 관리자 화면의 "등록 코드"에서 만듭니다. 설치가 끝나면 이 서버가
# 조직의 기기 목록에 나타나고, 권한이 있는 사람은 터미널로 SSH 접속을 할 수
# 있습니다. 이미 설치된 서버에서 다시 실행하면 최신 버전으로 바뀝니다 (코드나
# 키는 생략 가능).
#
#   ... | sudo sh -s -- --uninstall     # 제거
#
# 등록 코드는 설치하는 동안만 root 만 읽는 환경 파일에 두고, 에이전트가 등록을
# 마치면 지웁니다. 계정 서버 주소가 접속 서버와 다르면 --api https://주소 로
# 알려 줍니다.
set -e

REPO=kimjs3374/desk-releases
BIN=/usr/local/bin/desk
ENV_FILE=/etc/desk-agent.env
UNIT=/etc/systemd/system/desk-agent.service
STATE=/var/lib/private/desk-agent

say() { printf '%s\n' "$*"; }
die() { say "오류: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "root 권한이 필요합니다. sudo 를 붙여 다시 실행하십시오."
command -v systemctl >/dev/null 2>&1 || die "systemd 를 쓰는 리눅스만 지원합니다."

if [ "$1" = "--uninstall" ]; then
    systemctl disable --now desk-agent >/dev/null 2>&1 || true
    rm -f "$UNIT" "$ENV_FILE" "$BIN"
    rm -rf "$STATE" /var/lib/desk-agent
    systemctl daemon-reload
    say "desk 에이전트를 제거했습니다."
    exit 0
fi

KEY=
ENROL=
API=
NAME=
while [ $# -gt 0 ]; do
    case "$1" in
        --enrol | --enroll) [ $# -ge 2 ] || die "--enrol 뒤에 등록 코드를 넣으십시오."; ENROL=$2; shift 2 ;;
        --enrol=* | --enroll=*) ENROL=${1#*=}; shift ;;
        --api) [ $# -ge 2 ] || die "--api 뒤에 https:// 주소를 넣으십시오."; API=$2; shift 2 ;;
        --api=*) API=${1#*=}; shift ;;
        --name) [ $# -ge 2 ] || die "--name 뒤에 서버 이름을 넣으십시오."; NAME=$2; shift 2 ;;
        -*) die "알 수 없는 옵션입니다: $1" ;;
        *)
            if [ -z "$KEY" ] && [ -z "$ENROL" ]; then KEY=$1
            elif [ -z "$NAME" ]; then NAME=$1
            else die "인자가 너무 많습니다: $1"
            fi
            shift ;;
    esac
done
NAME=${NAME:-$(hostname)}

case "$(uname -m)" in
    x86_64 | amd64) ARCH=x86_64 ;;
    aarch64 | arm64) ARCH=aarch64 ;;
    *) die "지원하지 않는 CPU 입니다: $(uname -m)" ;;
esac

# 처음 설치인데 코드도 키도 없으면 물어본다. 이미 등록했거나 그룹에 들어가
# 있으면 그대로 둔다.
set_up=no
if [ -s "$ENV_FILE" ] || grep -qs -e '^group_key=' -e '^enrolled=' "$STATE/desk/config.txt"; then
    set_up=yes
fi
if [ -z "$KEY" ] && [ -z "$ENROL" ] && [ "$set_up" = no ]; then
    if [ -r /dev/tty ]; then
        printf '등록 코드(XXXX-XXXX-XXXX-XXXX-XXXX@서버) 또는 그룹 키를 입력하십시오: ' > /dev/tty
        read -r answer < /dev/tty
        case "$answer" in
            *-*-*-*-*-*) KEY=$answer ;;  # 그룹 키는 하이픈이 다섯 개, 등록 코드는 네 개
            *) ENROL=$answer ;;
        esac
    fi
    [ -n "$KEY" ] || [ -n "$ENROL" ] || die "등록 코드가 필요합니다. 관리자에게 받은 코드를 --enrol 뒤에 붙이십시오."
fi
if [ -n "$ENROL" ]; then
    # 에이전트는 TLS 라이브러리 없이 curl 로 한 번 등록 요청을 보낸다.
    command -v curl >/dev/null 2>&1 || die "등록에는 curl 이 필요합니다. curl 을 설치한 뒤 다시 실행하십시오."
fi

say "desk ($ARCH) 내려받는 중..."
URL="https://github.com/$REPO/releases/latest/download/desk-linux-$ARCH"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" -o "$TMP" || die "내려받지 못했습니다: $URL"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP" "$URL" || die "내려받지 못했습니다: $URL"
else
    die "curl 또는 wget 이 필요합니다."
fi
[ -s "$TMP" ] || die "내려받은 파일이 비어 있습니다."
install -m 755 "$TMP" "$BIN"

# 키와 코드는 root 만 읽는 파일에 둔다. 명령줄이나 서비스 파일에는 남기지 않는다.
clean_name=$(printf '%s' "$NAME" | tr -d '"\\\n\r' | cut -c1-40)
old_join=$(sed -n 's/^DESK_JOIN="\(.*\)"$/\1/p' "$ENV_FILE" 2>/dev/null || true)
old_api=$(sed -n 's/^DESK_API="\(.*\)"$/\1/p' "$ENV_FILE" 2>/dev/null || true)
clean_key=$(printf '%s' "${KEY:-$old_join}" | tr -cd 'A-Za-z0-9 @.:-')
clean_enrol=$(printf '%s' "$ENROL" | tr -cd 'A-Za-z0-9@.:-')
clean_api=$(printf '%s' "${API:-$old_api}" | tr -cd 'A-Za-z0-9/.:-')
if [ -n "$KEY" ] || [ -n "$ENROL" ] || [ -n "$API" ]; then
    (
        umask 077
        {
            [ -n "$clean_key" ] && printf 'DESK_JOIN="%s"\n' "$clean_key"
            [ -n "$clean_enrol" ] && printf 'DESK_ENROL="%s"\n' "$clean_enrol"
            [ -n "$clean_api" ] && printf 'DESK_API="%s"\n' "$clean_api"
            printf 'DESK_NAME="%s"\n' "$clean_name"
        } > "$ENV_FILE"
    )
fi

cat > "$UNIT" <<'EOF'
[Unit]
Description=desk agent (terminal access for the organisation's people)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/desk agent
EnvironmentFile=-/etc/desk-agent.env
Environment=DESK_CONFIG_DIR=/var/lib/desk-agent
# Runs as a throwaway user that can only write its own state directory.
DynamicUser=yes
StateDirectory=desk-agent
StateDirectoryMode=0700
Restart=on-failure
RestartSec=5
# Never compete with whatever else this machine is for.
MemoryMax=128M
CPUWeight=20
Nice=5
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable desk-agent >/dev/null 2>&1
systemctl restart desk-agent

log() { journalctl -u desk-agent -n 40 --no-pager -o cat 2>/dev/null || true; }

# 등록 코드: 에이전트가 처음 시작할 때 등록한다. 결과를 기다렸다가, 성공이든
# 실패든 코드는 환경 파일에서 지운다 (다시 쓸 일이 없고, 남겨 둘 이유도 없다).
if [ -n "$clean_enrol" ]; then
    outcome=
    i=0
    while [ $i -lt 30 ]; do
        sleep 1
        outcome=$(log | grep -E '^account: (enrolled|enrolment failed|already enrolled)' | tail -1)
        [ -n "$outcome" ] && break
        i=$((i + 1))
    done
    sed -i '/^DESK_ENROL=/d' "$ENV_FILE"
    case "$outcome" in
        "account: enrolled"*) say "계정에 등록했습니다." ;;
        "account: already enrolled"*) say "이 서버는 이미 계정에 등록되어 있습니다. 다른 조직으로 옮기려면 --uninstall 로 지운 뒤 다시 설치하십시오." ;;
        "account: enrolment failed: "*) die "계정에 등록하지 못했습니다: ${outcome#account: enrolment failed: }" ;;
        *) log | tail -8 >&2; die "등록 결과를 확인하지 못했습니다. 서버의 인터넷 연결과 등록 코드의 서버 주소를 확인하십시오." ;;
    esac
fi

# 서버에 등록될 때까지 잠깐 기다린다.
i=0
while [ $i -lt 10 ]; do
    if log | grep -q 'rendezvous server: online'; then
        break
    fi
    sleep 1
    i=$((i + 1))
done

if ! systemctl is-active --quiet desk-agent; then
    log | tail -8 >&2
    die "에이전트가 시작되지 않았습니다. 등록 코드나 그룹 키가 맞는지 확인하십시오."
fi
log | grep -E '^desk agent|warning|rendezvous|^account' | tail -4 || true
say "설치가 끝났습니다. 조직의 기기 목록(또는 desk 앱의 \"내 기기\")에 이 서버가 나타납니다."
