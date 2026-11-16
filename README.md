# desk

빠른 원격 데스크톱. 윈도우 PC는 화면을 보고 조작하고, 리눅스 서버는 터미널로 접속합니다.
모든 연결은 종단 간 암호화되며, 공유기 설정이나 포트 개방이 필요 없습니다.

## 윈도우

[최신 버전](https://github.com/kimjs3374/desk-releases/releases/latest)에서 `desk.exe`를 받아 실행합니다. 설치가 필요 없습니다.

- 다른 사람이 내 PC에 접속: 화면 왼쪽의 ID와 비밀번호를 알려 줍니다.
- 내가 다른 PC에 접속: 상대의 ID와 비밀번호를 넣고 **연결**을 누릅니다.
- 내 PC 여러 대: **새 그룹 만들기** 후 다른 PC에서 **그룹 참여**에 키를 넣으면, 비밀번호 없이 목록에서 바로 접속합니다.

필요한 것: 64비트 Windows 10/11, WebView2(Windows 11에는 기본 포함), 화면을 보내는 PC에는 NVIDIA, AMD 또는 Intel 그래픽.

## 리눅스 서버

서버에서 아래 한 줄을 실행합니다. 그룹 키는 desk 앱의 **내 기기 > 기기 추가**에 나옵니다.

```sh
curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- 그룹키 서버이름
```

끝나면 서버가 앱의 **내 기기**에 나타납니다. 로그인 이름을 넣고 **터미널**을 누르면 SSH 창이 열립니다.

- 서버의 SSH 포트를 인터넷에 열 필요가 없습니다.
- 접속은 PC의 `ssh`가 그대로 하므로 기존 SSH 키, 비밀번호, `scp`가 평소처럼 동작합니다.
- 서버의 SSH 로그인은 그대로 한 번 더 거칩니다.

필요한 것: systemd를 쓰는 리눅스, x86_64 또는 ARM64, SSH 서버.

같은 명령을 다시 실행하면 최신 버전으로 바뀝니다(그룹 키는 생략 가능). 제거:

```sh
curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- --uninstall
```

`scp` 등 다른 프로그램에서 쓰려면 PC에서 통로만 열 수 있습니다.

```
desk.exe terminal 서버ID --group --listen
```

출력된 포트로 `ssh -p 포트 사용자@127.0.0.1`, `scp -P 포트 ...`처럼 씁니다.
