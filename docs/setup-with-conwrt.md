# Setting up a net4sats router with conwrt

This guide walks you through turning a supported router into a net4sats
paid-WiFi access point using **conwrt** — the automated flashing and
configuration tool from the Amperstrand toolkit.

conwrt automates the entire process: flashing OpenWrt, joining upstream
WiFi, installing the tollgate payment backend, deploying the admin
panel, and branding the captive portal as net4sats.

**Time required:** 15-30 minutes (mostly waiting for firmware flashes)

---

## Prerequisites

### Hardware

- A supported router. Currently tested:
  - **GL.iNet GL-MT6000** (Flint 2) — aarch64, mediatek/filogic
  - **GL.iNet GL-MT3000** (Beryl AX) — aarch64, mediatek/filogic
  - **D-Link COVR-X1860 A1** — mipsel, ramips/mt7621
- An ethernet cable (for the initial flash)
- A laptop with an ethernet port (or USB adapter)
- An upstream WiFi network (the router will join this for internet)

### Software (on your laptop)

- Python 3.10+
- `git`
- `ssh` / `scp`
- On macOS: `tcpdump` (pre-installed) and `say` (for voice guidance)
- On Linux: `tcpdump` and `sudo`

### Information you'll need

- **Upstream WiFi SSID** — the network the router will join for internet
- **Upstream WiFi password**
- **Lightning address** — where payouts route (e.g. `you@wallet.app`)

---

## Step 1: Install conwrt

Clone and install conwrt on your laptop:

```sh
git clone https://github.com/Amperstrand/conwrt.git
cd conwrt
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e '.[dev]'
```

Verify:

```sh
python3 scripts/conwrt.py --version
```

You should see `conwrt <version>`.

---

## Step 2: Configure conwrt

conwrt reads settings from `config.toml` in the repo root. Copy the
example and edit:

```sh
cp config.example.toml config.toml
```

Key settings to review:

```toml
[ssh]
# SSH public key to install on the router
keys = ["~/.ssh/id_ed25519.pub"]

[password]
# "random" = generate a random password (printed once)
# "key-only" = no password, SSH key auth only
# "your-password" = use this exact password
mode = "random"
```

The SSH key is important — conwrt installs it on the router during
flashing so you can access the device without a password.

---

## Step 3: Flash OpenWrt onto the router

> If your router is already running OpenWrt 24.10.x, skip to Step 4.

### Connect the hardware

1. Plug the ethernet cable into your laptop and the router's LAN port.
2. Power on the router.

### Run the flash

```sh
python3 scripts/conwrt.py flash \
  --model-id glinet-mt6000 \
  --yes
```

**What happens:**

1. conwrt detects the router's boot state (off / U-Boot / OpenWrt).
2. If the router is in stock firmware, conwrt enters U-Boot recovery mode
   (by holding the reset button or via serial, depending on the model).
3. It downloads the correct OpenWrt image for your model and target.
4. It uploads the firmware via HTTP recovery (U-Boot) or sysupgrade
   (if OpenWrt is already running).
5. The router flashes and reboots.

**After reboot:**

The router comes up on its default IP (usually `192.168.1.1`) with
OpenWrt running. conwrt installs your SSH key and sets the root password
according to your `config.toml`.

Verify SSH access:

```sh
ssh root@192.168.1.1
# Run 'uname -m' — should show aarch64 for MT6000/MT3000
```

---

## Step 4: Run the net4sats flow

The net4sats flow is the automated deployment sequence that turns a
fresh OpenWrt router into a paid-WiFi gateway.

### What the flow does (7 steps)

| Step | Action | Detail |
|------|--------|--------|
| 1. Flash | Stock OpenWrt | Ensures the router is running OpenWrt (done in Step 3 above) |
| 2. WiFi STA | Join upstream WiFi | Configures the router as a WiFi client on your upstream network so it has internet |
| 3. Install backend | tollgate-wrt | Installs the payment backend (Lightning + Cashu). Resolves from Nostr (Blossom/NIP-94) or GitHub CI. |
| 4. Install deps | nodogsplash, jq, curl, ca-bundle | Captive portal engine and utilities |
| 5. Install portal | configurationwizzard | The net4sats admin web UI (served at `/net4sats/` on the router) |
| 6. Brand | net4sats captive portal | Configures nodogsplash gateway name, client ID, hotplug hooks |
| 7. Finalize | Move LAN IP | Moves the LAN off 192.168.1.1 to avoid collisions with neighbour devices |

### Running it

The net4sats flow is invoked through conwrt's use-case and flow system.
After flashing, conwrt applies the flow steps. In practice:

```sh
# After flash + reboot, conwrt continues automatically.
# If you need to re-apply the flow (e.g. after a factory reset):
python3 scripts/conwrt.py flash \
  --model-id glinet-mt6000 \
  --yes
```

conwrt will:

1. Detect the router is already on OpenWrt.
2. Ask for your upstream WiFi credentials.
3. Configure the STA interface, wait for internet.
4. Download and install tollgate-wrt (from the alpha3 release or Nostr).
5. Download and install configurationwizzard (the admin panel).
6. Configure the captive portal branding.
7. Move the LAN IP.

**Expected output at each step:**

```
== Step 1/7: Flash stock OpenWrt ==
  Router already running OpenWrt — skipping flash.

== Step 2/7: Connect the router to upstream WiFi ==
  Configuring radio1 as WiFi client (STA)...
  Waiting for wwan DHCP... OK
  Internet test: ping 1.1.1.1 — OK

== Step 3/7: Install the tollgate payment backend ==
  Resolving tollgate ipk (source=nostr, arch=aarch64_cortex-a53)...
    version:  v0.5.0-alpha3
    pubkey:   abc123...def456
    sha256:   1fcc1635a7d9...
  Downloaded. Transferring to router...
  Installing... OK
  tollgate-wrt enabled.

== Step 4/7: Install dependencies ==
  opkg install nodogsplash jq curl ca-bundle... OK

== Step 5/7: Install the net4sats portal (configurationwizzard) ==
  Downloading configurationwizzard.ipk...
  opkg install configurationwizzard.ipk... OK

== Step 6/7: Brand the captive portal as net4sats ==
  nodogsplash gatewayname = net4sats
  clientid = mac
  hotplug: wwan ifup → tollgate restart... installed

== Step 7/7: Move the LAN off 192.168.1.1 ==
  New LAN IP: 192.168.X.Y (derived from MAC hash)
  Reconnect on the new subnet.
```

---

## Step 5: Verify the installation

After the flow completes:

### Check services on the router

SSH into the router (use the new LAN IP printed at the end):

```sh
ssh root@192.168.X.Y

# Check tollgate
/etc/init.d/tollgate-wrt status

# Check captive portal
/etc/init.d/nodogsplash status

# Check admin web server
/etc/init.d/uhttpd status

# Check internet
ping -c 2 1.1.1.1
```

### Access the admin panel

Open a browser:

```
http://192.168.X.Y/
```

Login with the root credentials set during flashing.

You should see the net4sats admin dashboard. See the
[Admin Panel Guide](./admin-panel-guide.md) for a walkthrough.

### Test the captive portal

1. Connect your phone to the `net4sats-portal` WiFi network.
2. A captive portal should pop up automatically.
3. Select a package, generate a Lightning invoice.
4. Pay the invoice (use testnet mint for free testing).
5. Confirm internet access on the phone.

---

## Troubleshooting

### Router not detected

- Check the ethernet cable and link lights.
- Ensure the router is powered on and booted (wait 60 seconds).
- Try: `cat /sys/class/net/enp0s31f6/carrier` — should be `1`.
- If the router is in U-Boot recovery, conwrt detects it via ARP.

### WiFi STA won't connect

- Verify the upstream SSID and password.
- Check the radio: if upstream is 5GHz, use `radio1`; for 2.4GHz, use `radio0`.
- On MediaTek dual-radio chips, you cannot run a 5GHz AP and 5GHz STA on the same radio simultaneously. Disable the AP on that radio first.
- Scan for the AP from the router: `iwinfo phy1-sta0 scan` — confirm it's visible.

### tollgate install fails

- The Nostr source requires relay connectivity. Try GitHub instead:
  set `source = "github"` in the use-case params.
- Check architecture: `uname -m` must match the ipk target arch.
- If using apk (OpenWrt 25.x), ensure the `.apk` artifact is selected, not `.ipk`.

### Captive portal doesn't appear

- Check nodogsplash: `/etc/init.d/nodogsplash status`
- Check the portal WiFi SSID: `uci show wireless.net4sats_portal`
- Ensure the portal is on a different radio than the upstream STA.
- Try: `curl http://127.0.0.1:2050/` from the router.

### LAN IP collision

If two routers default to `192.168.1.1`, the flow moves the LAN IP to
avoid collision. If you can't find the router after this:

1. Scan for the MAC OUI: `nmap -sn 192.168.1.0/24`
2. Check your ARP table: `arp -a | grep 94:83:c4`
3. Or scan broader: `nmap -sn 192.168.0.0/16` (slow)

---

## Manual fallback: SSH runbook

If conwrt doesn't support your device or you prefer manual control,
copy-paste runbooks are available for:

- [GL-MT6000 (Flint 2)](https://github.com/net4sats/net4sats.github.io/blob/main/docs/runbook-mt6000.md)
- [GL-MT3000 (Beryl AX)](https://github.com/net4sats/net4sats.github.io/blob/main/docs/runbook-mt3000.md)

These are 7-phase SSH scripts that do the same work as the conwrt flow,
but manually — download, verify, sysupgrade, configure WiFi, install
packages, brand, and verify.

---

## Architecture overview

```
Internet ← upstream WiFi ← [net4sats router] → net4sats-portal WiFi → guests
                              │
                              ├── tollgate-wrt (port 2121): payment backend
                              │     └── Cashu mint + Lightning payouts
                              ├── nodogsplash (port 2050): captive portal
                              │     └── Redirects unpaid clients
                              ├── configurationwizzard (/net4sats/): admin UI
                              │     └── Dashboard, settings, wallet, WiFi, devices
                              └── uhttpd (port 80): web server
```

Payments route to the Lightning address configured during setup.
The Cashu mint handles ecash token creation and verification.
Guests never need an app — just a browser and a Lightning wallet.
