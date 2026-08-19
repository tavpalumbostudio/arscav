# ARScav

iOS prototype of an AR scavenger hunt. Print 12 markers, point the camera, tap face-down cards to flip them, and collect the named item each prompt asks for.

## What you need

- Mac with Xcode 15+ (Xcode 26 is fine)
- A physical iPhone or iPad (the Simulator has no AR camera tracking)
- A signing team in Xcode (Personal Team works)
- Network on **first launch** (photo API when configured, otherwise Wikimedia). Later hunts reuse the on-disk image cache.
- The PDF in `printables/` printed at **100% / actual size**

## Open and run

```bash
brew install xcodegen   # if you do not have it
xcodegen generate
open ARScav.xcodeproj
```

Select your team under **Signing & Capabilities**, plug in a device, Run.

The first launch downloads hunt photos. Later hunts reuse the on-disk image cache.

### Better photos (free API keys)

Add **one** key (Pixabay is easiest). ARScav tries providers in order, then falls back to Wikimedia:

| Service | Free tier | Sign up |
|---|---|---|
| **Pixabay** (recommended) | Unlimited requests, ~100/min | [pixabay.com/api/docs](https://pixabay.com/api/docs/) |
| **Pexels** | 20,000/month, 200/hour | [pexels.com/api](https://www.pexels.com/api/) |
| Google Custom Search | 100/day | Optional; needs Cloud + Search Engine setup |

Setup:

1. Create a free account and copy your API key (Pixabay: Account → API; Pexels: Your API key on the API page)
2. Copy secrets and paste your key:

```bash
cp Resources/Secrets.example.plist Resources/Secrets.plist
# Edit Resources/Secrets.plist — set PixabayAPIKey (and/or PexelsAPIKey)
xcodegen generate
```

Without `Secrets.plist`, the app uses Wikimedia Commons only (no key, but less consistent for obscure items).

Cached images are reused after the first download, so API limits rarely matter in normal play.

Spoken lines use a silly per-round voice. On first launch the app downloads **SmolLM2-135M** (~100MB) to flavor prompts; if it is slow or unavailable, canned lines play instead.

## How a hunt works

- 24 categories in two groups: **Classic Hunts** (16) and **Predator Hunts** (8). Each round uses 12 markers with 4 finds and 8 decoys
- **Predator hunts**: you play as the predator tracking prey — different spoken prompts ("Track the zebra!", decoys say "not your prey")
- Cards spawn **face-down**. Tap to flip; the photo and **CAPS name** appear
- Tapping the current target collects it (sound + haptic)
- Repeat prompt and Found items are the only chrome
- Speech uses a silly per-round voice; SmolLM2 rewrites lines when the on-device model is ready

## Swap content without a new build

### Bundled manifest

Edit `Resources/manifest.json` (names, which 4 ids are `targets`, `searchQuery`). Regenerate from `scripts/generate_markers.py` after editing categories in `ROUNDS`.

### Remote catalog (append new hunts)

Ship new hunt categories without an App Store update:

1. Add hunts to `REMOTE_ROUNDS` in [`scripts/generate_markers.py`](scripts/generate_markers.py) (same shape as `ROUNDS` entries).
2. Export a remote-only JSON file:

```bash
python scripts/generate_markers.py --remote-only
# writes catalog/manifest-remote.json  (patch: { "rounds": [...] })
```

3. Host `manifest-remote.json` on a static URL (GitHub raw, S3, etc.).
4. Point the app at it in [`Resources/remote-config.json`](Resources/remote-config.json):

```json
{
  "manifestURL": "https://raw.githubusercontent.com/tavpalumbostudio/arscav/main/catalog/manifest-remote.json",
  "manifestVersion": 1,
  "enabled": true
}
```

Hosted file: [`catalog/manifest-remote.json`](catalog/manifest-remote.json) in this repo.

5. Bump `manifestVersion` when you publish new remote hunts (cache bust).
6. Rebuild once to ship the updated URL/version — after that, new rounds append automatically.

The app loads bundled hunts first, then **appends** remote rounds whose `id` is not already bundled. Offline play uses bundled hunts; cached remote hunts are used when fetch fails.

Use **Dev menu → Reload remote catalog** while iterating on hosted content.

## Dev menu (hidden)

Tap the **round status pill** at the top of the screen **5 times** quickly to open the dev menu. Pick any category to start a fresh hunt with that theme.

## Layout

See `project.yml` for the XcodeGen project. Marker PNGs live in `Resources/Markers/`.
