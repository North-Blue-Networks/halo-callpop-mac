# Halo Call Pop (macOS)

Production macOS menu bar agent for North Blue Networks. Receives call-pop notifications from the VoIPNow-Halo middleware and opens the HaloPSA ticket screen pop in the agent's default browser.

This repo contains **only** the desktop call-pop client — no Halo or VoIPNow integration.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ (to build and sign the `.app` bundle)
- Access to your deployed middleware (`MIDDLEWARE_URL`) and `CALLPOP_API_SECRET`

## Quick start

### 1. Build the app

```bash
git clone https://github.com/North-Blue-Networks/halo-callpop-mac.git
cd halo-callpop-mac
open HaloCallPop.xcodeproj
```

In Xcode: select the **HaloCallPop** scheme → **Product → Build** (⌘B).

Or from the command line (requires full Xcode):

```bash
./scripts/build.sh Release
# Output: build/DerivedData/Build/Products/Release/halo-callpop-mac.app
```

### 2. Configure middleware credentials

Create the config file (admin task — do not commit secrets):

```bash
mkdir -p ~/Library/Application\ Support/NorthBlue/HaloCallPop
cp config.example.json ~/Library/Application\ Support/NorthBlue/HaloCallPop/config.json
```

Edit `config.json`:

```json
{
  "middlewareUrl": "https://your-app.up.railway.app",
  "callpopApiSecret": "your-callpop-api-secret",
  "allowedPopUrlHosts": ["halopsa.com"]
}
```

| Key | Description |
|-----|-------------|
| `middlewareUrl` | Base URL of the VoIPNow-Halo middleware on Railway |
| `callpopApiSecret` | Shared secret sent as `X-Callpop-Secret` header |
| `allowedPopUrlHosts` | Optional. Host suffixes allowed for `popUrl` (default: `halopsa.com`) |

No `haloAgentId` or `voipnowExtension` in local config — those are mapped in HaloPSA and synced by the middleware.

### 3. Install and launch

Copy the built app to `/Applications`:

```bash
cp -R build/DerivedData/Build/Products/Release/halo-callpop-mac.app /Applications/
open /Applications/halo-callpop-mac.app
```

The app registers as a **login item** on first launch (via `SMAppService`) and appears in the menu bar as a phone icon with a connection-status dot:

| Color | Status |
|-------|--------|
| Green | Connected to middleware WebSocket |
| Amber | Connecting / reconnecting |
| Red | Disconnected or config error |

### 4. Copy Device ID to HaloPSA

1. Click the menu bar icon.
2. Click **Copy Device ID** (or select the UUID text).
3. In HaloPSA, open the agent record → custom field **Call Pop Device ID** → paste the UUID.
4. Ensure the agent's VoIPNow extension is also set in their Halo custom fields (synced by middleware cron).

The Device ID is a stable UUID stored at:

```
~/Library/Application Support/NorthBlue/HaloCallPop/device-id.txt
```

## How it works

```
Middleware (Railway)                    macOS menu bar agent
        │                                        │
        │  POST /agents/devices/register         │
        │◄───────────────────────────────────────│  (on launch)
        │  { deviceToken, wsUrl }                │
        │───────────────────────────────────────►│  (token → Keychain)
        │                                        │
        │  WSS /agents/ws/callpop?deviceToken=…  │
        │◄──────────────────────────────────────►│  (persistent)
        │                                        │
        │  { type: "callpop", popUrl, … }        │
        │───────────────────────────────────────►│
        │                                        ├─► Validate popUrl host
        │                                        ├─► Open in default browser
        │  { type: "ack", callApiId }            │
        │◄───────────────────────────────────────│
```

On each inbound call pop:

1. Log the event (no secrets)
2. Validate `popUrl` host against the allowlist
3. Open `popUrl` via `NSWorkspace.shared.open`
4. Send `{"type":"ack","callApiId":"..."}`
5. Deduplicate: ignore duplicate `callApiId` within 60 seconds

If the user is not logged into Halo in the browser, the URL still opens — they can sign in and land on the ticket.

## CLI debug mode

Run without extra UI interaction beyond the menu bar icon:

```bash
/Applications/halo-callpop-mac.app/Contents/MacOS/halo-callpop-mac --connect-only
```

This registers the device, connects the WebSocket, and logs to the log file. Useful for verifying middleware connectivity.

## Logs

Logs are written to:

```
~/Library/Application Support/NorthBlue/HaloCallPop/Logs/halo-callpop.log
```

Open from the menu: **Open Logs**.

Secrets (`callpopApiSecret`, `deviceToken`) are never written to logs.

## Permissions

| Permission | Why |
|------------|-----|
| Network | Register device and maintain WebSocket to middleware |
| Keychain | Store `deviceToken` securely |
| Login Item | Auto-start after reboot (user can disable in System Settings → General → Login Items) |

No screen recording, microphone, or accessibility permissions are required.

## Code signing & distribution (Developer ID)

For production deployment outside your dev machine:

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create a **Developer ID Application** certificate in Xcode → Settings → Accounts.
3. Set your **Team** in the HaloCallPop target → Signing & Capabilities.
4. Archive: **Product → Archive** → **Distribute App** → **Developer ID**.
5. Notarize with `notarytool`:

```bash
xcrun notarytool submit halo-callpop-mac.zip \
  --apple-id "you@company.com" \
  --team-id "TEAMID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

xcrun stapler staple halo-callpop-mac.app
```

6. Distribute the stapled `.app` or `.dmg` to agents.

Hardened Runtime is enabled in the Xcode project (`ENABLE_HARDENED_RUNTIME = YES`).

## Development

### Project layout

```
HaloCallPop/              App source (SwiftUI menu bar + services)
HaloCallPopTests/         XCTest suite (requires Xcode)
Sources/HaloCallPopSelfTest/  CLI-friendly test runner
HaloCallPop.xcodeproj/    Xcode project (builds halo-callpop-mac.app)
Package.swift             SwiftPM library + self-test runner
config.example.json       Example config (copy to Application Support)
scripts/build.sh          Build Release/Debug .app
scripts/test.sh           Run unit tests
```

### Run tests

```bash
# Works with Swift command-line tools (no full Xcode required)
swift run HaloCallPopSelfTest

# Or use the test script
./scripts/test.sh

# With full Xcode installed
swift test
```

Tests cover JSON message parsing, 60-second callpop deduplication, pop URL host validation, and WebSocket URL construction.

### Simulate a call pop (manual)

With the app connected, send a test message from your middleware admin tools, or use a WebSocket client pointed at `wss://{host}/agents/ws/callpop?deviceToken={token}` with:

```json
{
  "type": "callpop",
  "callApiId": "test-001",
  "ticketId": 12345,
  "popUrl": "https://yourtenant.halopsa.com/agent/ticket?id=12345",
  "callerNum": "+15551234567",
  "callerName": "Test Caller",
  "haloAgentId": 42,
  "voipnowExtension": "0003*201",
  "timestamp": "2026-06-21T10:00:00Z"
}
```

Verify: browser opens the ticket URL, log shows the event, and an ack is sent.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Red status dot | Config file exists and JSON is valid; `middlewareUrl` reachable; `callpopApiSecret` correct |
| Amber dot stuck | Network/firewall blocking WSS; middleware logs for device registration |
| Device ID not copying | Click **Copy Device ID** in menu; UUID also selectable as text |
| Pop URL not opening | Check `allowedPopUrlHosts` includes your Halo tenant domain; must be `https://` |
| Pop URL blocked in logs | Host not in allowlist — add tenant domain to `allowedPopUrlHosts` |
| Duplicate pops ignored | Expected — same `callApiId` within 60s is deduplicated |
| After sleep/wake | App reconnects on `NSWorkspace.didWakeNotification` |
| Reset device | Quit app, delete Keychain entry + `device-id.txt`, relaunch to re-register |

### Reset registration

```bash
# Quit the app first
security delete-generic-password -s "com.northblue.halo-callpop" 2>/dev/null || true
rm -f ~/Library/Application\ Support/NorthBlue/HaloCallPop/device-id.txt
```

Relaunch to generate a new Device ID and re-register with middleware. Update the HaloPSA custom field with the new ID.

## Security

- `deviceToken` stored in macOS Keychain (`com.northblue.halo-callpop`)
- `callpopApiSecret` read from config file only — never logged
- `popUrl` validated against HTTPS + host allowlist before opening
- No Halo or VoIPNow credentials stored locally

## License

Proprietary — North Blue Networks. All rights reserved.
