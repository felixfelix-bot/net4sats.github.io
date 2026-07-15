# Setting up a net4sats router with the wizard

This guide walks you through turning an OpenWrt router into a net4sats
paid-WiFi access point using the **net4sats wizard** — a desktop app that
auto-discovers your router on the network and deploys everything over SSH.

The wizard is a single Go binary that runs on your laptop. It serves a
web UI at `http://localhost:8099` where you:

1. Let it scan your network for routers
2. Pick your router, enter the password
3. Enter your Lightning address (where payouts go)
4. Click Deploy — the wizard does the rest over SSH

**Time required:** 2-5 minutes (router must already run OpenWrt)

---

## Prerequisites

### Router requirements

- **OpenWrt already installed** (24.10.x or 25.x). The wizard does NOT
  flash firmware — it configures an existing OpenWrt router. If your
  router still runs stock firmware, flash OpenWrt first using the
  [runbook for your device](https://github.com/net4sats/net4sats.github.io/tree/docs/operator-guides/docs).

- SSH must be reachable (port 22 open on the router).

### Laptop requirements

- Any OS: Windows, macOS (Intel or Apple Silicon), or Linux (x86_64)
- On the same network as the router (WiFi or ethernet)
- A Lightning address or LNURL (where Bitcoin payments route)

---

## Step 1: Get the wizard binary

### Option A: Download from releases

Download the binary for your laptop OS from the
[releases page](https://github.com/net4sats/net4sats-wizard-go/releases).

| Your laptop | File |
|---|---|
| Windows | `net4sats-wizard-windows-amd64.exe` |
| Linux (x86_64) | `net4sats-wizard-linux-amd64` |
| macOS (Intel) | `net4sats-wizard-darwin-amd64` |
| macOS (Apple Silicon M1/M2/M3) | `net4sats-wizard-darwin-arm64` |

### Option B: Build from source

Requires Go 1.21+:

```sh
git clone https://github.com/net4sats/net4sats-wizard-go.git
cd net4sats-wizard-go
go build -o net4sats-wizard .
```

### Verify the binary (recommended)

```sh
sha256sum net4sats-wizard-*
# Compare against SHA256SUMS in the release
```

---

## Step 2: Run the wizard

### macOS / Linux

```sh
chmod +x net4sats-wizard-linux-amd64   # or your platform
./net4sats-wizard-linux-amd64
```

### Windows

Double-click `net4sats-wizard-windows-amd64.exe`.
(SmartScreen may warn — choose "Run anyway"; the binary is unsigned.)

You should see:

```
net4sats wizard running on http://localhost:8099
Open this URL in your browser to set up a router.
```

**Open `http://localhost:8099` in your browser.**

---

## Step 3: Wizard flow — scan and configure

### 3a. Network scan

The wizard scans your local subnet for routers with SSH (port 22) or HTTP
open. It checks ARP table entries and common router IPs
(192.168.1.1, 192.168.8.1, etc.).

A spinner appears: "Scanning for routers on your network..."

**If no router is found:** Make sure the router is powered on, running
OpenWrt, and reachable from your laptop on the same subnet. Try connecting
an ethernet cable directly.

### 3b. Select your router

After the scan, you'll see a dropdown listing detected routers. Each
entry shows the IP, vendor (e.g. "OpenWrt"), model, and firmware version.

Select your router from the list.

### 3c. Enter configuration

| Field | What to enter |
|-------|---------------|
| **Router password** | The root password for the router's SSH |
| **Upstream connection** | WAN (Ethernet) or WiFi Repeater (STA mode) |
| **Lightning address** | Your payout address (e.g. `you@wallet.app`) or raw LNURL. Required. |

If you select **WiFi Repeater**, additional fields appear:
- Upstream WiFi SSID
- Upstream WiFi password

#### Advanced settings (optional, collapsed by default)

| Setting | Default | What it does |
|---------|---------|-------------|
| **Dev split** | 10% | Share of payments routed to the net4sats developer fund (0-50%) |
| **Margin** | 0% | Operator markup added on top of data costs (0-100%) |
| **Cashu mint** | 8333.space | Which Cashu mint the router prefers for ecash payments |

### 3d. Click "Deploy net4sats"

---

## Step 4: Deployment (automated)

The wizard runs 9 steps over SSH. You see live progress with checkmarks:

| Step | What happens |
|------|-------------|
| 1. Verify SSH | Connects to router, reads firmware version |
| 2. Check firmware | Confirms OpenWrt is running |
| 3. Set root password | Updates the router's root password |
| 4. Configure upstream | Sets up WAN or WiFi STA (repeater) mode |
| 5. Install net4sats | Runs `apk add net4sats` (or `opkg install`) on the router |
| 6. Brand captive portal | Sets nodogsplash gateway name to "net4sats" |
| 7. Configure Lightning | Writes Lightning address + dev split + margin + mint to config.json |
| 8. Restart services | Restarts tollgate-wrt and nodogsplash |
| 9. Health check | Verifies the TollGate API is responding on port 2121 |

A live log appears below the steps showing real-time SSH output.

When all steps complete, you see: **"net4sats is live!"**

---

## Step 5: Access the admin panel

After deployment, open a browser to the router's IP:

```
http://<router-ip>/
```

The admin panel (configurationwizzard) should load. Login with the root
password you configured.

See the [Admin Panel Guide](./admin-panel-guide.md) for a full walkthrough
of the dashboard, schema-driven settings, wallet, WiFi, and devices screens.

---

## Step 6: Test the captive portal

1. Connect your phone to the router's WiFi (SSID: `net4sats-portal` or
   the network the router is broadcasting).
2. Open any website in a browser.
3. The captive portal should appear — you'll see pricing packages.
4. Choose a package and generate a Lightning invoice.
5. Pay with a Lightning wallet (or use a testnet Cashu mint for free testing).
6. After payment, your device gets internet access.

---

## Troubleshooting

### Router not found in scan

- Ensure the router is powered on and running OpenWrt.
- Check SSH is open: `nmap -p 22 <router-ip>` from your laptop.
- The wizard checks common gateway IPs + ARP table. If the router is on
  a non-standard subnet, the scan may miss it.
- Try connecting via ethernet cable for a more reliable scan.

### Deploy fails at "Verifying SSH access"

- Wrong password — re-run and enter the correct root password.
- SSH may be disabled on the router. Enable it in OpenWrt:
  `uci set dropbear.@dropbear[0].Port=22 && uci commit dropbear`
- On GL.iNet stock firmware, SSH may be disabled — switch to OpenWrt first.

### Deploy fails at "Installing net4sats"

- The router needs internet to install packages. If using WAN mode,
  make sure the ethernet cable is plugged into the WAN port.
- If using WiFi Repeater mode, the upstream WiFi credentials must be correct.
- On OpenWrt 24.10.x (opkg): the net4sats feed must be configured.
- On OpenWrt 25.x (apk): `apk update` must succeed first.

### "Router is not running OpenWrt"

The wizard detected the router but it's running stock firmware. You need
to flash OpenWrt first. Use the manual runbook for your device:

- [GL-MT6000 (Flint 2)](https://github.com/net4sats/net4sats.github.io/blob/docs/operator-guides/docs/setup-with-conwrt.md#step-3-flash-openwrt-onto-the-router)
- [GL-MT3000 (Beryl AX)](https://github.com/net4sats/net4sats.github.io/blob/docs/operator-guides/docs/runbook-mt3000.md)

### Health check fails

- Check if tollgate is running: SSH in and run `/etc/init.d/tollgate-wrt status`
- Check the API directly: `curl http://127.0.0.1:2121/`
- Look at logs: `logread | grep tollgate`

---

## Architecture

```
Your laptop (wizard at :8099)
  │  SSH deploy
  ▼
┌─────────────────────────────────────┐
│ Router (OpenWrt)                     │
│                                       │
│  ├── tollgate-wrt (:2121)            │  Payment backend (Cashu + Lightning)
│  ├── nodogsplash (:2050)             │  Captive portal redirect
│  ├── configurationwizzard (:80)      │  Admin dashboard SPA
│  └── net4sats WiFi AP                │  Guest-facing WiFi network
│                                       │
│  Upstream: WAN (ethernet) or WiFi STA │  Connection to internet
└─────────────────────────────────────┘
```

The wizard is a thin deployer — it SSHes in, installs packages, configures
UCI settings, writes the Lightning address to config.json, and restarts
services. All payment/identity logic runs on the router in tollgate-wrt.

**Source:** [github.com/net4sats/net4sats-wizard-go](https://github.com/net4sats/net4sats-wizard-go)
