# desk

빠른 원격 데스크톱. 윈도우 PC는 화면을 보고 조작하고, 리눅스 서버는 터미널로 접속합니다.
모든 연결은 종단 간 암호화되며, 공유기 설정이나 포트 개방이 필요 없습니다.

## 윈도우

[최신 버전](https://github.com/kimjs3374/desk-releases/releases/latest)에서 `desk.exe`를 받아 실행합니다. 설치가 필요 없습니다.

- 다른 사람이 내 PC에 접속: 화면 왼쪽의 ID와 비밀번호를 알려 줍니다.
- 내가 다른 PC에 접속: 상대의 ID와 비밀번호를 넣고 **연결**을 누릅니다.
- 회사 계정: **내 기기**에서 이메일과 비밀번호로 로그인하면 접속할 수 있는 PC 목록이 나오고, 목록에서 바로 연결합니다. 이 PC도 목록에 넣으려면 **이 PC 등록**을 누릅니다. 등록한 PC는 아무도 로그인하지 않아도 계정으로 접속을 받습니다.
- 예전 방식(기기 그룹): **새 그룹 만들기** 후 다른 PC에서 **그룹 참여**에 키를 넣으면, 비밀번호 없이 목록에서 바로 접속합니다. 계정으로 옮기는 동안에도 계속 동작합니다.

필요한 것: 64비트 Windows 10/11, WebView2(Windows 11에는 기본 포함), 화면을 보내는 PC에는 NVIDIA, AMD 또는 Intel 그래픽.

ID로 서로를 찾으려면 접속 서버가 필요합니다. 프로그램에는 서버 주소가 들어 있지 않으며, **설정**에서 직접 넣거나 그룹에 참여할 때 키와 함께 자동으로 설정됩니다. 계정 서버 주소는 접속 서버에 물어 자동으로 정하며, 설정의 **계정 서버**에서 바꿀 수 있습니다. 서버는 `desk server`로 직접 운영합니다.

### 여러 PC에 한꺼번에 등록 (관리자)

관리자가 만든 등록 코드로 로그인 없이 등록합니다. PC를 쓸 Windows 사용자 계정으로 실행해야 합니다(로그온 스크립트 등). 등록 키가 그 사용자에게만 풀리게 암호화되기 때문입니다.

```
desk.exe enrol XXXX-XXXX-XXXX-XXXX-XXXX@서버주소
```

또는 프로그램 파일 이름을 `desk-enrol-XXXX-XXXX-XXXX-XXXX-XXXX.exe`로 바꿔 나눠 주면, 처음 실행할 때 그 코드로 등록한 뒤 평소처럼 실행됩니다. 등록 코드는 여러 대에 쓸 수 있게 만들 수 있고(사용 횟수), 만든 그룹에 바로 들어가게 할 수 있습니다.

명령줄에서 로그인할 때는 `desk.exe login 이메일`, 로그아웃은 `desk.exe logout`, 확인은 `desk.exe whoami`입니다.

## 리눅스 서버

서버에서 아래 한 줄을 실행합니다. 등록 코드는 관리자가 만들어 줍니다.

```sh
curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- --enrol XXXX-XXXX-XXXX-XXXX-XXXX@서버주소 서버이름
```

끝나면 서버가 조직의 기기 목록에 나타납니다. 권한이 있는 사람이 로그인 이름을 넣고 **터미널**을 누르면 SSH 창이 열립니다.

- 서버의 SSH 포트를 인터넷에 열 필요가 없습니다.
- 접속은 PC의 `ssh`가 그대로 하므로 기존 SSH 키, 비밀번호, `scp`가 평소처럼 동작합니다.
- 서버의 SSH 로그인은 그대로 한 번 더 거칩니다.
- 등록에는 `curl`이 필요합니다. 등록 코드는 등록하는 동안만 root만 읽는 파일에 두었다가 지웁니다.

예전 방식(그룹 키)도 그대로 됩니다. 그룹 키는 desk 앱의 **내 기기 > 기기 추가**에 나옵니다.

```sh
curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- 그룹키 서버이름
```

필요한 것: systemd를 쓰는 리눅스, x86_64 또는 ARM64, SSH 서버.

같은 명령을 다시 실행하면 최신 버전으로 바뀝니다(코드나 키는 생략 가능). 제거:

```sh
curl -fsSL https://raw.githubusercontent.com/kimjs3374/desk-releases/main/install.sh | sudo sh -s -- --uninstall
```

`scp` 등 다른 프로그램에서 쓰려면 PC에서 통로만 열 수 있습니다.

```
desk.exe terminal 서버ID --account --listen
```

출력된 포트로 `ssh -p 포트 사용자@127.0.0.1`, `scp -P 포트 ...`처럼 씁니다. 예전 방식이면 `--account` 대신 `--group`을 씁니다.
