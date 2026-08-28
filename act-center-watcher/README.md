# ACT Test-Center Watcher

This performs a small, read-only daily check using a dedicated Chrome profile.
It does not copy or print ACT cookies.

## First-time setup

From this directory:

```bash
npm install
npm run login
```

The browser opens with a dedicated profile. Log in to ACT, complete the
registration search setup if needed, then press Enter in the terminal.

## Run a check

```bash
npm run check
```

Results are saved to `data/latest.json`. A macOS notification appears when the
directory response changes. Availability checking is a separate command.

## Check availability from the center CSV

After generating `data/centers-wa-simple.csv`, run:

```bash
npm run login
npm run availability
```

The availability command reads the unique `center_code` column from
`data/centers-wa-simple.csv` and sends one authenticated request per code:

```text
/api/test-scheduling/ACTNational/test-centers
  ?product=ACT
  &roomType=REGULAR
  &seatAvailability=ALL
  &siteListingCode=186321
  &standby=true
```

It writes `data/availability.json` and waits two seconds between requests by
default. Use another CSV with:

```bash
npm run availability -- \
  --csv data/centers-other.csv \
  --output data/availability-other.json
```

Multiple state CSVs can be checked in one command. The script opens one
dedicated browser session, deduplicates center codes within each state, and
writes separate reports:

```bash
npm run availability -- \
  --state-csv WA=data/centers-wa-simple.csv \
  --state-csv OR=data/centers-or-simple.csv
```

This produces:

```text
data/availability-wa.json
data/availability-or.json
```

Each unique center code is checked once per availability mode in its state's
CSV. The same center code appearing in both state files is checked once for
each state report, so the reports remain independent.

## Daily schedule

Create `~/Library/LaunchAgents/com.local.act-center-watcher.plist`, replacing
`/ABSOLUTE/PATH` with this directory:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.act-center-watcher</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>npm</string>
    <string>run</string>
    <string>check</string>
  </array>
  <key>WorkingDirectory</key>
  <string>/ABSOLUTE/PATH</string>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/act-center-watcher.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/act-center-watcher.err</string>
</dict>
</plist>
```

Load it with:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.act-center-watcher.plist
```

If ACT asks you to log in again, run `npm run login` manually and retry the
check. Do not automate CAPTCHA or other anti-bot challenges.

## Crawl center codes

The public ACT locator requires a state and ZIP code. It does not expose one
static nationwide list, so provide a controlled ZIP list rather than probing
every possible ZIP.

Install the Python dependency:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
python -m playwright install chromium
```

Run the crawler:

```bash
python crawl_centers.py \
  --state Washington \
  --zip-file zips-wa.txt \
  --output data/centers-wa.json
```

It writes both JSON and CSV files. Results are deduplicated by official center
code and include the scheduled dates shown by the public locator. Use a
state-specific ZIP file and keep the delay conservative.

## Simpler REST crawler

The locator also exposes a public JSON endpoint, so browser automation is not
needed for center discovery:

```bash
python crawl_centers_simple.py \
  --state WA \
  --zip-file zips-wa.txt \
  --output data/centers-wa-simple.json
```

This version waits two seconds between ZIP requests by default, saves one raw
JSON response per ZIP, and writes a deduplicated CSV keyed by ACT's `tc_id`.
The endpoint's `tc_id` is the locator's internal test-center ID, not the
official registration center code displayed after expanding a locator result.
For each deduplicated `tc_id`, it then calls
`TestSchedulingDates.json?tc_id=...&product=ACT` once and attaches that raw
response to the JSON output. The second response supplies the official
`tc_code`; the CSV contains one row per center/date with `test_date`,
`start_time`, and `schedule_status`. Increase the delay with `--delay 5` if
desired.

To crawl Washington broadly, generate a postal ZIP list first:

```bash
python3 generate_wa_zips.py
python3 crawl_centers_simple.py \
  --state WA \
  --zip-file zips-wa.txt \
  --min-delay 1 \
  --max-delay 6 \
  --output data/centers-wa-simple.json
```

The ZIP generator downloads the public GeoNames US postal-code file and keeps
Washington ZIPs only. The ACT crawler deduplicates centers returned by nearby
ZIPs, so the same center is not repeated in the output.
