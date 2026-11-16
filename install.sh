#!/bin/sh
# desk 에이전트 설치 스크립트 (리눅스 서버용)
#
#   curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- 그룹키 [서버이름]
#
# 그룹 키는 desk 앱의 "내 기기 > 기기 추가"에 나옵니다. 설치가 끝나면 이
# 서버가 앱의 "내 기기"에 나타나고, 터미널 버튼으로 SSH 접속을 할 수 있습니다.
# 이미 설치된 서버에서 다시 실행하면 최신 버전으로 바뀝니다 (키는 생략 가능).
#
#   ... | sudo sh -s -- --uninstall     # 제거
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

KEY=$1
NAME=${2:-$(hostname)}

case "$(uname -m)" in
    x86_64 | amd64) ARCH=x86_64 ;;
    aarch64 | arm64) ARCH=aarch64 ;;
    *) die "지원하지 않는 CPU 입니다: $(uname -m)" ;;
esac

# 처음 설치인데 키가 없으면 물어본다. 이미 그룹에 들어가 있으면 그대로 둔다.
joined=no
if [ -s "$ENV_FILE" ] || grep -qs '^group_key=' "$STATE/desk/config.txt"; then
    joined=yes
fi
if [ -z "$KEY" ] && [ "$joined" = no ]; then
    if [ -r /dev/tty ]; then
        printf '그룹 키를 입력하십시오: ' > /dev/tty
        read -r KEY < /dev/tty
    fi
    [ -n "$KEY" ] || die "그룹 키가 필요합니다. desk 앱의 \"기기 추가\"에서 복사해 명령 끝에 붙이십시오."
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

# 그룹 키는 root 만 읽는 파일에 둔다. 명령줄이나 서비스 파일에는 남기지 않는다.
if [ -n "$KEY" ]; then
    clean_name=$(printf '%s' "$NAME" | tr -d '"\\\n\r' | cut -c1-40)
    clean_key=$(printf '%s' "$KEY" | tr -cd 'A-Za-z0-9 -')
    (
        umask 077
        printf 'DESK_JOIN="%s"\nDESK_NAME="%s"\n' "$clean_key" "$clean_name" > "$ENV_FILE"
    )
fi

cat > "$UNIT" <<'EOF'
[Unit]
Description=desk agent (terminal access from the owner's devices)
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

# 서버에 등록될 때까지 잠깐 기다린다.
i=0
while [ $i -lt 10 ]; do
    sleep 1
    if journalctl -u desk-agent -n 20 --no-pager -o cat 2>/dev/null | grep -q 'rendezvous server: online'; then
        break
    fi
    i=$((i + 1))
done

if ! systemctl is-active --quiet desk-agent; then
    journalctl -u desk-agent -n 8 --no-pager -o cat >&2 || true
    die "에이전트가 시작되지 않았습니다. 그룹 키가 맞는지 확인하십시오."
fi
journalctl -u desk-agent -n 20 --no-pager -o cat 2>/dev/null | grep -E '^desk agent|warning|rendezvous' | tail -3 || true
say "설치가 끝났습니다. desk 앱의 \"내 기기\"에 이 서버가 나타납니다."
