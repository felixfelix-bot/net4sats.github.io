# net4sats Admin Panel Guide

The net4sats admin panel (configurationwizzard) is the web interface for
managing your router as a paid-WiFi access point. This guide walks you
through every screen and what you can configure.

The panel is built with Preact and runs entirely on the router. It
communicates with the tollgate backend via OpenWrt's rpcd/ubus API — no
external servers involved.

---

## Accessing the panel

### From a browser

Open:

```
http://<router-ip>/
```

If the router was set up with conwrt's default flow, the admin panel is
served from `/net4sats/` on port 80. The root `/` redirects there.

**Login:** Use the router's root credentials (set during flashing).

### Ports

| Port | Service | Purpose |
|------|---------|---------|
| 80 | uhttpd | Admin panel (configurationwizzard SPA) |
| 2050 | nodogsplash | Captive portal (guest-facing) |
| 2121 | tollgate-wrt | Payment backend API |
| 8080 | LuCI | OpenWrt's standard admin (if installed) |

### Demo mode (no router required)

You can explore the admin panel without a router. A live demo runs on
GitHub Pages:

```
https://net4sats.github.io/configurationwizzard/
```

This uses mock data — the dashboard, settings, wallet, and WiFi screens
all render with sample values. Useful for evaluating the UX before
deploying.

To run the demo locally:

```sh
git clone https://github.com/net4sats/configurationwizzard.git
cd configurationwizzard
npm install
npm run demo
```

Open `http://localhost:5173` in your browser.

---

## Dashboard

The dashboard is the landing page after login. It shows a real-time
overview of the router and tollgate status.

### What you see

| Section | Fields | Source |
|---------|--------|--------|
| **System** | Hostname, model, kernel, uptime, memory | `ubus call system board` + `system info` |
| **Tollgate Status** | Running state, version, active sessions | `ubus call tollgate status` |
| **Wallet** | Total balance (sats), per-mint breakdown | `ubus call tollgate wallet_info` |
| **Network** | LAN IP, WAN/upstream IP, default route | `ubus call network.interface dump` |

The dashboard auto-refreshes. If tollgate is unhealthy or the wallet
can't reach mints, warning indicators appear.

---

## Settings (Schema-Driven Configuration)

This is the core of the "schemas-based admin panel." Instead of
hard-coded forms, the settings page dynamically renders form fields from
the tollgate backend's configuration schema.

### How it works

1. The panel calls `ubus call tollgate config_schema` — the backend
   returns a JSON schema describing every configurable field (name,
   type, description, default, constraints, enum values).
2. The panel calls `ubus call tollgate config_get` — gets current
   values.
3. The SchemaForm component renders each field with the correct input
   type (text, number, boolean toggle, dropdown for enums, nested
   objects, arrays).
4. When you save, it calls `ubus call tollgate config_set` + `config_save`.

This means **any new config field the backend exposes automatically
appears in the admin panel** — no UI code changes needed.

### Field groups

Fields are organized into logical groups:

#### General

| Field | Type | Description |
|-------|------|-------------|
| `log_level` | enum | Logging verbosity: debug, info, warn, error |
| `metric` | enum | Metering metric: bytes or milliseconds |
| `step_size` | uint64 | Data step size for metering (bytes) |
| `margin` | float64 | Margin factor (0.0–1.0) applied to pricing |
| `show_setup` | bool | Show the setup wizard on first boot |
| `reseller_mode` | bool | Enable reseller functionality |
| `manual_pause_seconds` | int | How long to pause when manually pausing |

#### Accepted Mints

| Field | Type | Description |
|-------|------|-------------|
| `accepted_mints` | array | List of Cashu mints the router accepts. Each mint has: URL, min_balance, balance_tolerance_percent, payout_interval_seconds, min_payout_amount, price_per_step, price_unit, purchase_min_steps |

You can add or remove mints here. For testing, add the testnet mint:
`https://testnut.cashu.exchange`.

#### Profit Share

| Field | Type | Description |
|-------|------|-------------|
| `profit_share` | object | Profit-sharing configuration between the router operator and upstream provider |

#### Upstream Detector

| Field | Type | Description |
|-------|------|-------------|
| `probe_timeout` | int | Seconds to wait for upstream probe response |
| `probe_retry_count` | int | Number of probe retries |
| `probe_retry_delay` | int | Delay between retries (seconds) |
| `require_valid_signature` | bool | Require cryptographic signature on upstream probe |
| `ignore_interfaces` | array | Network interfaces to skip during upstream detection |

### Editing values

- **Editable** fields show input controls.
- **Read-only** fields (editable: false) display values but can't be changed.
- **Required** fields are marked with `*`.
- **Enum** fields show a dropdown.
- **Nested objects** render as expandable sub-forms.
- **Arrays** (like accepted_mints) show add/remove controls.

### Saving

Click **Save** to persist changes. The panel calls `config_save` which
writes to `/etc/tollgate/config.json` and restarts the tollgate service.
Changes take effect immediately.

For identity-related fields (Lightning address, merchant key), the panel
uses `config_save_identities` which triggers a full service restart and
key rotation.

---

## Wallet

The wallet page manages the router's Cashu ecash balance.

### What you see

- **Total balance** — sum across all accepted mints (in sats)
- **Per-mint breakdown** — balance for each mint individually

### Actions

#### Fund the router (add ecash)

1. Paste a Cashu token (ecash string) into the input field.
2. Click **Fund**.
3. The backend calls `wallet_fund` which redeems the token at the mint
   and adds the balance to the router's wallet.

This is how you top up the router's float — it needs ecash to issue
tokens to guests who pay via Lightning.

#### Drain (extract ecash)

1. Click **Drain**.
2. The backend calls `wallet_drain_cashu` which creates ecash tokens
   for the full balance at each mint.
3. Tokens are displayed — copy them to your wallet.

This is how you withdraw accumulated revenue from the router.

---

## WiFi

The WiFi page manages both the upstream connection (how the router gets
internet) and the portal AP (what guests connect to).

### Upstream (STA)

- **Current status** — connected/disconnected, SSID, radio, encryption
- **Scan** — scans for nearby WiFi networks; shows SSID, signal, BSSID,
  encryption, channel
- **Connect** — select a network, enter the password, and connect

When you change the upstream WiFi, the router:
1. Configures the STA interface on the selected radio.
2. Waits for DHCP.
3. Tests internet connectivity.
4. Restarts tollgate via the hotplug hook.

### Portal (AP)

- **SSID** — the WiFi name guests see (default: `net4sats-portal`)
- **Password** — WPA2 key for the portal network
- **Radio** — which radio the portal broadcasts on
- **Encryption** — WPA2-PSK (CCMP) by default

**Important:** The portal must be on a different radio than the upstream
STA. On dual-radio routers (MT6000, MT3000), this means:
- If upstream uses radio1 (5GHz), portal uses radio0 (2.4GHz).
- If upstream uses radio0 (2.4GHz), portal uses radio1 (5GHz).

On single-radio devices, STA + AP coexistence depends on the chipset.

---

## Devices

The devices page shows all currently connected DHCP clients.

### What you see

| Field | Description |
|------|-------------|
| **Hostname** | Device hostname (if broadcast via DHCP) |
| **IP Address** | Assigned IPv4 address |
| **MAC Address** | Device hardware address |
| **Lease Expiry** | Seconds remaining on the DHCP lease |

This includes both guests (connected via the portal WiFi) and any
management devices on the LAN.

On OpenWrt 25.x, where `dhcp.ipv4leases` may be unavailable via rpcd,
the page falls back to reading `/tmp/dhcp.leases` directly.

---

## Captive Portal (Guest View)

The captive portal is what guests see when they connect to the
`net4sats-portal` WiFi and open a browser. It is served by nodogsplash
on port 2050.

### Guest flow

1. **Connect** to `net4sats-portal` WiFi.
2. **Open a browser** — any HTTP request triggers a redirect to the
   captive portal.
3. **Choose a package** — pricing options (e.g. 1 hour, 1 day, 1 GB).
4. **Generate invoice** — a BOLT11 Lightning invoice with a QR code.
5. **Pay** — scan the QR with a Lightning wallet and pay.
6. **Online** — the backend detects payment, activates the session,
   and the guest gets internet.

For Cashu: guests can also paste an ecash token instead of paying via
Lightning. The backend verifies the token at the mint and grants access.

### Customization

The captive portal UI is a separate SPA (`captive-portal.tsx`) built
from the same repository. It can be rebranded by modifying the portal
build and redeploying via `deploy.sh`.

---

## Security model

### Authentication

- The admin panel uses OpenWrt's rpcd session management (same as LuCI).
- Login requires the router root password.
- Session tokens expire; the panel handles re-authentication automatically.

### ACLs

The rpcd ACL (`tollgate_acl.json`) defines two access levels:

| Role | Read access | Write access |
|------|------------|--------------|
| **tollgate** (authenticated) | config, wallet, status, WiFi, devices, system | config changes, wallet ops, WiFi changes, password set |
| **unauthenticated** | pricing, status, sessions | activate (pay) |

Guests on the captive portal use the **unauthenticated** role — they
can see pricing and pay, but cannot read or modify the router config.

### Data sensitivity

- Lightning address and mint URLs are stored in `/etc/tollgate/config.json`
  on the router. They are visible to anyone with admin access.
- The router's private key (for Nostr identity and Cashu operations)
  is derived from the merchant key seed. It is not exposed via the API.
- Wallet balances are read-only via the API. Draining requires
  authenticated access.

---

## Troubleshooting

### Can't access the admin panel

- Check uhttpd: `/etc/init.d/uhttpd status`
- Check you're on the right IP: `ip addr` on the router
- Try port 8080 (LuCI may have taken port 80): `http://router-ip:8080/`
- Check rpcd: `/etc/init.d/rpcd status`

### Settings won't save

- Check the tollgate service: `/etc/init.d/tollgate-wrt status`
- Check config file is valid JSON: `jq -e . /etc/tollgate/config.json`
- Look for error in the panel (toast notification)
- Check rpcd ACL includes `config_set` and `config_save`

### Wallet shows 0 balance

- Verify mints are reachable: `curl -s https://testnut.cashu.exchange/info`
- Check tollgate logs: `logread | grep tollgate`
- The backend may not have synced yet — wait 30 seconds and refresh
- Ensure the router has internet: `ping -c 2 1.1.1.1`

### WiFi tab empty or errors

- On OpenWrt 25.x, `network.wireless` may not be available via rpcd.
  The panel falls back to reading `/etc/config/wireless` via UCI.
- Ensure the wireless drivers are loaded: `iw dev`
