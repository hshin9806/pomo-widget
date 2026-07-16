# POMO

A Pomodoro timer that lives in your macOS menu bar. The ring empties as the session runs down, so you can see the time left without clicking anything.

- Click the ring and type the length you want, or tap a 25 / 45 / 50 preset — no settings screen to dig through
- Don't want breaks? Switch them off and focus sessions run back to back
- Notification banner and a sound when a session ends
- Optional launch at login
- English and Korean, following your system language
- No Dock icon, no window in your way

Requires macOS 13 or later.

## Install

Download `POMO.zip` from the [latest release](../../releases/latest), unzip it, and drag POMO into Applications.

This build isn't notarized (that requires a paid Apple Developer account), so macOS will refuse to open it with a "damaged" or "unidentified developer" warning on first launch. To open it anyway: right-click POMO in Applications → **Open** → **Open** again in the dialog. You only need to do this once.

## Build from source

```bash
./build.sh && open POMO.app
```

Needs only the Xcode Command Line Tools (`xcode-select --install`) — no Xcode.

The app is a hand-assembled bundle: `Sources/*.swift` compiled with `swiftc`, `Info.plist` and `Resources/` copied in. `build.sh` signs it ad-hoc, which is fine on your own machine but will not open on anyone else's.

To change the icon, edit `Tools/make_icon.swift` and run `./Tools/make_icon.sh`.

## Releasing (maintainer)

`release.sh` produces a signed, notarized DMG that opens cleanly on any Mac. It needs an Apple Developer Program membership ($99/yr).

One-time setup:

1. In the Apple Developer portal, create a **Developer ID Application** certificate and install it in your keychain.
2. Create an [app-specific password](https://support.apple.com/en-us/102654) for your Apple ID.
3. Store the notarization credentials:

   ```bash
   xcrun notarytool store-credentials POMO \
     --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
   ```

Then, for each release:

```bash
export POMO_SIGN_ID="Developer ID Application: Your Name (TEAMID)"
./release.sh
```

Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` first, and upload the resulting `POMO.dmg` to a GitHub release.

---

## 한국어

맥북 상태바에 사는 뽀모도로 타이머입니다. 남은 시간만큼 링이 줄어들어서, 클릭하지 않아도 얼마나 남았는지 보입니다.

상태바를 클릭하면 뜨는 패널에서 원하는 시간을 바로 입력하거나 25 / 45 / 50 프리셋을 누르면 됩니다. 휴식이 필요 없으면 스위치를 꺼서 집중만 이어서 돌릴 수도 있어요. 세션이 끝나면 알림과 소리로 알려주고, 로그인 시 자동 실행은 톱니바퀴 메뉴에 있습니다. 시스템 언어에 따라 한국어와 영어로 표시됩니다.

macOS 13 이상이 필요합니다. [최신 릴리스](../../releases/latest)에서 `POMO.zip`을 받아 압축을 풀고 응용 프로그램 폴더에 넣으면 됩니다.

공증(notarization)을 받지 않은 빌드라 (유료 Apple Developer 계정이 필요해요), 처음 실행할 때 macOS가 "손상되었다" 또는 "확인되지 않은 개발자" 경고를 띄웁니다. 그래도 열려면: 응용 프로그램 폴더에서 POMO를 우클릭 → **열기** → 다이얼로그에서 다시 **열기**. 한 번만 하면 됩니다.
