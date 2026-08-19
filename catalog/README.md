# ARScav remote hunt catalog

Hosted for the iOS app to fetch via GitHub raw.

**URL:** `https://raw.githubusercontent.com/tavpalumbostudio/arscav/main/catalog/manifest-remote.json`

## Publish new hunts

1. Add rounds to `REMOTE_ROUNDS` in [`scripts/generate_markers.py`](../scripts/generate_markers.py)
2. Run `python scripts/generate_markers.py --remote-only`
3. Commit and push `catalog/manifest-remote.json`
4. Bump `manifestVersion` in [`Resources/remote-config.json`](../Resources/remote-config.json) and ship an app update (one-time pointer change), or use dev menu **Reload remote catalog**

The app **appends** remote rounds whose `id` is not already in the bundled manifest.
