# gleus-releases

Public distribution channel for the **Gleus** Android app's self-update (native lane).

This repo holds **only release artefacts** — no source. Source lives in the private `gleus-tuner-engine`, `gleus-mobile`, and `gleus-docs` repos. This one is public so the app can fetch updates from a **tokenless HTTPS URL** while the source stays private.

> Decision: [gleus-docs ADR 013](https://github.com/CPaxman/gleus-docs/blob/main/architecture/013-update-distribution-strategy.md) + its 2026-06-12 amendment. Implementation spec: [android-self-update-github-releases](https://github.com/CPaxman/gleus-docs/blob/main/planning/2026-06-12-android-self-update-github-releases.md).

## How it works

Two update lanes (only the native one lives here):

- **JS changes** → EAS Update (silent OTA). Not in this repo.
- **Native changes** (new native module, SDK bump, permission change) → a signed APK published here as a **GitHub Release asset**, which the installed app detects and self-installs.

The app checks a manifest on launch, compares `versionCode`, and when this repo has something newer it downloads and installs the APK. No cable.

### Stable URLs the app uses (public, no auth)

- Manifest: `https://github.com/CPaxman/gleus-releases/releases/latest/download/latest.json`
- APK: `https://github.com/CPaxman/gleus-releases/releases/latest/download/gleus-release.apk`

`releases/latest/download/<asset>` always redirects to the newest release's asset of that name. The APK asset name is held **constant** across releases (`gleus-release.apk`); the version lives in `latest.json` and the git tag.

## Why APKs are NOT committed

`.gitignore` blocks `*.apk`. Binaries are uploaded as **release assets**, which are stored separately from the git pack — so the repo never accumulates a 145 MB-per-release history. Committing them would bloat the clone forever. The 2 GB-per-asset limit is far above an APK.

## `latest.json` — the update contract

```json
{
  "versionName": "0.2.1",
  "versionCode": 3,
  "apkUrl": "https://github.com/CPaxman/gleus-releases/releases/latest/download/gleus-release.apk",
  "notes": "FFT-autocorrelation MPM + 8192 drone window",
  "publishedAt": "2026-06-12",
  "mandatory": false,
  "minSupportedVersionCode": 1
}
```

- `versionCode` — integer the app compares against its installed build. The "is there something newer" key. Must increment every release.
- `mandatory` — `true` blocks the app until updated (reserved).
- `minSupportedVersionCode` — a future floor below which the app refuses to run (reserved).

## Publishing a release

1. Build the **signed** release APK in `gleus-mobile` (stable release keystore — see gleus-mobile MEMORY.md / issue #28; a debug-key build cannot self-update).
2. Drop it in `staging/` (gitignored).
3. Run `scripts/publish-release.sh` — it reads the version from `../gleus-mobile/app.json`, writes `latest.json`, and runs `gh release create … --latest`.

## Status — not live yet

This repo is **scaffolded locally** (2026-06-12). Before self-update works:

1. **Craig creates the public GitHub repo** `CPaxman/gleus-releases` and connects this folder (`git remote add origin …`).
2. **Stable release keystore** set up in `gleus-mobile` (#28) — until then, builds are debug-key signed and cannot self-update.
3. **In-app update-check** implemented in `gleus-mobile` per the spec.

The APK currently in `staging/` is the 2026-06-12 test build (FFT + 8192 drone window) — debug-key signed, for manual sideload UAT only, **not** a self-updatable release.
