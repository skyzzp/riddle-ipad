# Riddle's Diary for iPad

A native iPadOS toy: a magical diary that writes back. You write to it with the
Apple Pencil, the page **drinks your ink** (it dissolves away), and then an
invisible quill answers in Tom's own hand — and he **remembers you** across days.

The ink/quill pipeline is a conceptual re-implementation of the reMarkable
[`riddle`](https://github.com/MaximeRivest/riddle) project, reimagined for iPad
with an added memory subsystem so Tom recalls past conversations.

> **Unofficial fan project.** The names, characters, and settings of the Harry
> Potter universe are trademarks and copyright of Warner Bros. Entertainment and
> J.K. Rowling. This is a non-commercial, fan-made project **not affiliated with,
> authorized, or endorsed by** them, and it bundles none of their copyrighted
> assets. If you're a rights holder with a concern, please open an issue.

## Demo

![Writing to the diary and Tom answering in his own hand](demo.gif)

*Write a note with the Pencil, the page drinks the ink, and Tom replies.*

## The experience

1. **Listen.** A blank aged page. You write a note with the Pencil.
2. **Drink.** When you pause, the diary absorbs your ink — a per-pixel Metal
   dissolve — until the page is clean again.
3. **Reply.** A vision model reads what you actually wrote (your real
   handwriting, not transcribed text), and Tom answers. An invisible quill
   traces his reply letter by letter in a calligraphic hand.
4. **Remember.** A background side-call quietly notes what matters, so the next
   time you write, Tom remembers your name and what you've talked about.

## How it works

- **`RiddleKit`** — a pure, unit-tested Swift core with no UIKit dependency:
  - the quill pipeline: rasterize glyphs → Zhang–Suen thinning → centerline
    trace → line wrapping → reply layout;
  - the Oracle client: OpenAI-compatible streaming, memory-aware prompt
    assembly, and a fire-and-forget side-call that transcribes + extracts notes;
  - a two-tier memory store (a verbatim ring buffer + a distilled notes list).
- **`RiddleApp`** — the SwiftUI + UIKit shell: PencilKit input and idle
  detection, the aged-paper page rendering, the Metal dissolve, the quill
  reveal animation, a persistent memory repository, and a hidden Settings sheet
  (long-press a corner) for the API key and model names (stored in the Keychain).

Both the reply and the note-extraction run through [OpenRouter](https://openrouter.ai)
(any OpenAI-compatible endpoint works). Defaults: `google/gemini-3.1-flash-lite`
for replies, `google/gemini-2.5-flash-lite` for the memory side-call.

## Requirements

- macOS with **Xcode 16+**
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An **iPad running iPadOS 17+** with an **Apple Pencil** (the simulator has no
  Pencil, so the core loop can only be experienced on a real device)
- An **OpenRouter API key** (or any OpenAI-compatible key) — https://openrouter.ai/keys

## Build & run

```sh
git clone <your-fork-url> && cd riddle-ipad

# 1. Point signing at YOUR Apple Developer team + a bundle id you own.
#    Edit project.yml:
#      DEVELOPMENT_TEAM          -> your 10-char Team ID
#      PRODUCT_BUNDLE_IDENTIFIER -> e.g. com.yourname.tomriddlediary
#      bundleIdPrefix            -> com.yourname

# 2. Generate the Xcode project (it is gitignored — always regenerate).
xcodegen generate

# 3. Open and run to your connected iPad.
open Riddle.xcodeproj
```

On **first launch** the app opens Settings automatically — paste your OpenRouter
key there and you're done (it's stored in the Keychain). Prefer to pre-seed it?
Copy `RiddleApp/riddle-config.plist.example` to `RiddleApp/riddle-config.plist`
and fill in your key — that file is gitignored and must never be committed.

### Run the tests

```sh
cd RiddleKit && swift test
```

## Project layout

```
RiddleKit/      pure, tested core (quill pipeline, Oracle, memory)
RiddleApp/      SwiftUI + UIKit app (rendering, Metal, gestures, Settings)
tools/          app-icon renderer
project.yml     XcodeGen spec (source of truth for the .xcodeproj)
```

## Credits & license

Source code is **MIT** licensed (see [`LICENSE`](LICENSE)). Bundled fonts and
textures are the work of others under their own licenses — see
[`CREDITS.md`](CREDITS.md). Tom's hand is *Aquiline Two* by Manfred Klein; the
page relief uses a CC-BY texture; the quill pipeline is inspired by Maxime
Rivest's `riddle`.
