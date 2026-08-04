# Gazzet — Gazzette Iulaan → Telegram Publisher

Monitors the Maldives Gazzette Iulaan feed for new listings from the **Male City Council** (`މާލޭ ސިޓީ ކައުންސިލްގެ އިދާރާ`) and publishes them to a Telegram channel.

## How it works

1. Queries today's listings from the Idhaan's Gazzette search wrapper API: `https://gazzette.idhaan.me/search`
2. Filters results client-side to the target office, matching either:
   - the Dhivehi vendor name `މާލޭ ސިޓީ ކައުންސިލްގެ އިދާރާ`, or
   - the English slug `secretariat-of-the-male-city-council` in `vendor_url`
3. Filters to listings published **today** only
4. Sends each new listing to the channel via the Telegram Bot API (HTML formatted)
5. Remembers published IDs in `~/.gazzet_sent` so listings aren't re-sent

## Requirements

- `bash`
- `jq`
- `curl`

## Setup

```bash
chmod +x gazzet.sh
```

### Cron

Run every 2 hours:

```cron
0 */2 * * * /home/user/Scripts/gazzet/gazzet.sh >> /home/user/Scripts/gazzet/cron.log 2>&1
```

## Configuration

> **You must bring your own bot token and channel ID.** Set them at the top of `gazzet.sh`:

| Variable | Description |
|----------|-------------|
| `BOT_TOKEN` | Telegram bot token from [@BotFather](https://t.me/BotFather) |
| `CHANNEL_ID` | Target channel/supergroup ID (e.g. `-1001234567890`) |
| `SENT_LOG` | Where published listing IDs are remembered (default `~/.gazzet_sent`) |

### Customizing the office

To track a different office, edit these two variables at the top of `gazzet.sh`:

| Variable | Description |
|----------|-------------|
| `VENDOR_DV` | The Dhivehi vendor name as shown on the site (e.g. `މާލޭ ސިޓީ ކައުންސިލްގެ އިދާރާ`) |
| `VENDOR_EN_SLUG` | The office slug used in the API's `vendor_url` (e.g. `secretariat-of-the-male-city-council`) |

A listing is matched if either value appears. To match **all** offices, set `VENDOR_DV` and `VENDOR_EN_SLUG` to empty strings (`""`).

The vendor name/slug for an office can be found in the `vendor` / `vendor_url` fields of the API response (see `api.md`).

## Usage

```bash
# Normal run — publish only new listings
./gazzet.sh

# Force re-publish — ignore the sent-log memory (resends all today's matches)
./gazzet.sh --ignore-memory
```

## Output & logging

- Console/log output goes to `cron.log` (when run via cron)
- Published listing IDs are appended to `~/.gazzet_sent`

## Reliability features

- **Client-side filtering** — does not rely on the API's (unreliable) `office=` filter
- **Date guard** — only today's listings are published, even if the API drops filters
- **JSON validation** — skips gracefully on malformed API responses
- **Pagination safety** — processes page 1 even when `total_pages` is `0`/`null`; caps at 20 pages
- **Telegram 429 handling** — waits out `retry_after` and retries up to 5× instead of dropping messages

## Files

| File | Purpose |
|------|---------|
| `gazzet.sh` | The main publisher script |
| `api.md` | Reference for the Gazzette search API |
| `cron.log` | Output log from scheduled runs |

## Shoutout

big thanks to [Idhaan](https://dev.idhaan.me) for his wrapper aroung gazzet api for making this 100x less painful and simpler
