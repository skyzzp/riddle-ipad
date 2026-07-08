# Contributing

Thanks for looking! This is a small personal toy, maintained in spare time with
a deliberately narrow scope — so keep expectations right-sized. That said, fixes
and thoughtful improvements are welcome.

## Ground rules

- **Never commit secrets.** Your OpenRouter key lives in the Keychain (via the
  app's Settings) or in `RiddleApp/riddle-config.plist`, which is gitignored.
  There is a safe `riddle-config.plist.example` template. Double-check `git diff`
  before every commit.
- **`Riddle.xcodeproj` is generated** by [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  from `project.yml` and is gitignored. Never hand-edit it — change `project.yml`
  and run `xcodegen generate`.
- **Signing is personal.** `project.yml` hardcodes a `DEVELOPMENT_TEAM` and
  bundle id. Change them to your own to build to a device (see README).

## Where logic lives, and how to verify

- **`RiddleKit/`** — the pure, testable core (quill raster→thin→trace→wrap
  pipeline, Oracle streaming/parsing, memory, layout). This is **test-driven**:
  add/adjust tests and keep them green.
  ```
  cd RiddleKit && swift test
  ```
- **`RiddleApp/`** — the SwiftUI/UIKit app shell (rendering, gestures, Metal
  dissolve, Settings). Behavioral changes here are verified by building to a
  real iPad and driving the Pencil (the simulator has no Pencil). At minimum,
  confirm it still compiles:
  ```
  xcodegen generate
  xcodebuild -project Riddle.xcodeproj -scheme Riddle \
    -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' \
    -derivedDataPath /tmp/riddle-dd CODE_SIGNING_ALLOWED=NO build
  ```

## Pull requests

Keep them focused, describe what you changed and how you verified it, and note
any test additions. For anything touching the quill pipeline or the Oracle
prompt/parsing, please include the relevant `swift test` output.
