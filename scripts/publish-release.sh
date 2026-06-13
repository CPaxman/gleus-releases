#!/usr/bin/env bash
#
# Publish a Gleus Android native release as a GitHub Release asset.
#
# Reads the version from gleus-mobile/app.json, writes latest.json, and
# uploads both latest.json and the APK as assets on a new release tagged
# v<versionName>, marked --latest so the stable
# releases/latest/download/<asset> URLs resolve to it.
#
# Prerequisites:
#   - The public repo CPaxman/gleus-releases exists and this folder has it
#     as `origin` (git remote add origin git@github.com:CPaxman/gleus-releases.git).
#   - `gh` is installed and authenticated (gh auth status).
#   - A SIGNED release APK at staging/gleus-release.apk. A debug-key build
#     cannot self-update (Android rejects a different signing key) — see #28.
#
# Usage:
#   scripts/publish-release.sh ["release notes"]
#
set -euo pipefail

REPO="CPaxman/gleus-releases"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_JSON="$HERE/../gleus-mobile/app.json"
APK="$HERE/staging/gleus-release.apk"
MANIFEST="$HERE/latest.json"
NOTES="${1:-}"

fail() { echo "error: $*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || fail "gh CLI not found. Install GitHub CLI and run 'gh auth login'."
command -v node >/dev/null 2>&1 || fail "node not found (needed to read app.json)."
[ -f "$APP_JSON" ] || fail "app.json not found at $APP_JSON"
[ -f "$APK" ] || fail "APK not found at $APK — build the signed release APK and drop it in staging/ first."

VERSION_NAME="$(node -e "process.stdout.write(String(require('$APP_JSON').expo.version))")"
VERSION_CODE="$(node -e "process.stdout.write(String(require('$APP_JSON').expo.android.versionCode))")"
[ -n "$VERSION_NAME" ] || fail "could not read expo.version from app.json"
# String(undefined) is the literal "undefined", which is truthy — reject it
# explicitly so a missing versionCode fails loudly instead of writing invalid
# JSON ("versionCode": undefined) into the manifest.
case "$VERSION_CODE" in
  ''|undefined|null) fail "expo.android.versionCode is missing/invalid in app.json (got '$VERSION_CODE'). Set an integer versionCode and bump it every native release." ;;
esac

# SHA-256 for post-download integrity verification by the app.
SHA256="$(shasum -a 256 "$APK" | awk '{print $1}')"
# Tag by versionCode, not just versionName: beta versionNames repeat across
# builds (versionCode is the real uniqueness key the app compares), so tagging
# on versionName alone collides. e.g. v0.2.0-beta.1-vc3.
TAG="v${VERSION_NAME}-vc${VERSION_CODE}"
TODAY="$(date +%F)"

# Refuse to publish a debug-key-signed APK — it can't self-update. Use
# apksigner, not `keytool -jarfile`: modern release APKs are signed with the
# v2/v3 APK Signature Scheme, which keytool (v1/JAR only) cannot see, so it
# would report nothing and silently pass a debug-signed APK through.
APKSIGNER="$(ls -t "$HOME"/Library/Android/sdk/build-tools/*/apksigner 2>/dev/null | head -1 || true)"
if [ -n "$APKSIGNER" ]; then
  CERTS="$("$APKSIGNER" verify --print-certs "$APK" 2>/dev/null || true)"
  if echo "$CERTS" | grep -qi 'androiddebugkey'; then
    fail "APK is debug-key signed. Self-update needs the stable release key (#28). Aborting."
  fi
  [ -n "$CERTS" ] || echo "warning: apksigner returned no certs — could not confirm signing; proceeding." >&2
else
  echo "warning: apksigner not found — skipping debug-key check. Confirm the APK is release-signed before relying on self-update." >&2
fi

# Write the manifest the app consumes.
cat > "$MANIFEST" <<JSON
{
  "versionName": "$VERSION_NAME",
  "versionCode": $VERSION_CODE,
  "apkUrl": "https://github.com/$REPO/releases/latest/download/gleus-release.apk",
  "sha256": "$SHA256",
  "notes": "${NOTES//\"/\\\"}",
  "publishedAt": "$TODAY",
  "mandatory": false,
  "minSupportedVersionCode": 1
}
JSON

echo "Publishing $TAG (versionCode $VERSION_CODE) to $REPO ..."
echo "  apk:    $APK"
echo "  sha256: $SHA256"

gh release create "$TAG" \
  "$APK#gleus-release.apk" \
  "$MANIFEST#latest.json" \
  --repo "$REPO" \
  --title "Gleus $VERSION_NAME (build $VERSION_CODE)" \
  --notes "${NOTES:-Release $VERSION_NAME (build $VERSION_CODE).}" \
  --latest

echo "Done. Live at https://github.com/$REPO/releases/latest"
