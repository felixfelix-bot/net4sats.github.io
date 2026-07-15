# net4sats Documentation

Guides for setting up and managing net4sats paid-WiFi routers.

## Guides

| Guide | What it covers |
|-------|----------------|
| [Setup with the wizard](./setup-with-wizard.md) | Use the net4sats wizard (desktop app) to discover, configure, and deploy net4sats onto an OpenWrt router. Covers prerequisites, the 9-step automated deploy, and troubleshooting. |
| [Admin Panel Guide](./admin-panel-guide.md) | Navigate the configurationwizzard admin UI: dashboard, schema-driven settings, wallet, WiFi, devices, and captive portal. |

## Quick start

1. Flash your router to OpenWrt (use a runbook for your device if needed).
2. Run the [setup wizard](./setup-with-wizard.md) to deploy net4sats.
3. Read the [Admin Panel Guide](./admin-panel-guide.md) to configure pricing, manage mints, and monitor your access point.

## Source repositories

| Repo | Role |
|------|------|
| [net4sats-wizard-go](https://github.com/net4sats/net4sats-wizard-go) | Desktop onboarding wizard (Go binary, serves web UI at :8099) |
| [configurationwizzard](https://github.com/net4sats/configurationwizzard) | Router-side admin dashboard + captive portal (Preact SPA) |
| [tollgate-module-basic-go](https://github.com/net4sats/tollgate-module-basic-go) | Payment backend (Cashu + Lightning, runs on router) |
