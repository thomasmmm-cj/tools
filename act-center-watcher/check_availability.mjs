import fs from "node:fs/promises";
import path from "node:path";
import readline from "node:readline";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { chromium } from "playwright";

const execFileAsync = promisify(execFile);
const root = path.dirname(new URL(import.meta.url).pathname);
const profileDir = path.join(root, "browser-profile");
const dataDir = path.join(root, "data");
const defaultCsv = path.join(dataDir, "centers-wa-simple.csv");
const defaultOutput = path.join(dataDir, "availability.json");
const configFile = path.join(root, "config.json");

const defaultConfig = {
  product: "ACT",
  seatAvailability: "ALL",
  availabilityModes: [
    {
      key: "byod_regular",
      roomType: "BYOD REGULAR",
      standby: "false"
    },
    {
      key: "regular_standby",
      roomType: "REGULAR",
      standby: "true"
    }
  ],
  availabilityDelay: 2
};

async function readConfig() {
  try {
    return { ...defaultConfig, ...JSON.parse(await fs.readFile(configFile, "utf8")) };
  } catch {
    return defaultConfig;
  }
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    const next = text[i + 1];
    if (char === '"' && quoted && next === '"') {
      cell += '"';
      i += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      row.push(cell);
      cell = "";
    } else if ((char === "\n" || char === "\r") && !quoted) {
      if (char === "\r" && next === "\n") i += 1;
      row.push(cell);
      if (row.some(value => value !== "")) rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += char;
    }
  }

  if (cell || row.length) {
    row.push(cell);
    rows.push(row);
  }

  const headers = rows.shift() ?? [];
  return rows.map(values => Object.fromEntries(
    headers.map((header, index) => [header, values[index] ?? ""])
  ));
}

function parseStateCsvSpec(spec) {
  const separator = spec.indexOf("=");
  if (separator <= 0 || separator === spec.length - 1) {
    throw new Error(`Use --state-csv STATE=PATH, got: ${spec}`);
  }

  const label = spec.slice(0, separator).trim().toLowerCase();
  const csvPath = spec.slice(separator + 1).trim();
  if (!/^[a-z]{2,20}$/.test(label)) {
    throw new Error(`State label must contain only letters, got: ${label}`);
  }

  return { label, csvPath };
}

function stableJson(value) {
  return JSON.stringify(value, Object.keys(value ?? {}).sort(), 2);
}

async function notify(title, message) {
  try {
    await execFileAsync("osascript", [
      "-e",
      `display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}`
    ]);
  } catch {
    console.log(`${title}: ${message}`);
  }
}

function toNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function summarizeAvailability(payload, standby = "false") {
  const resources = Array.isArray(payload)
    ? payload
    : payload?.response?.data?.resource_list ?? [];
  const schedules = resources.flatMap(resource => {
    if (Array.isArray(resource.locations)) return [resource];
    if (Array.isArray(resource.test_dates)) return resource.test_dates;
    return [];
  });

  return schedules.map(schedule => ({
    test_date: schedule.test_date ?? "",
    start_time: schedule.start_time ?? "",
    status: schedule.status ?? schedule.date_status ?? "",
    locations: (schedule.locations ?? []).map(location => {
      const assigned = toNumber(location.assign_count);
      const capacity = toNumber(location.capacity);
      const seatsRemaining = assigned !== null && capacity !== null
        ? Math.max(capacity - assigned, 0)
        : null;
      return {
        location_type: location.location_type ?? "",
        assign_count: assigned,
        capacity,
        seats_remaining: location.location_type === "STANDBY" ? 0 : seatsRemaining,
        available: standby !== "true" &&
          location.location_type !== "STANDBY" &&
          seatsRemaining !== null &&
          seatsRemaining > 0
      };
    })
  }));
}

async function ensureLoggedIn(page) {
  await page.goto("https://my.act.org/", { waitUntil: "domcontentloaded" });
  await page.waitForTimeout(1000);

  if (!/signin|login/i.test(page.url())) return;

  console.log("ACT login is required in the opened browser.");
  console.log("Log in there, then return to this terminal and press Enter.");
  const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
  await new Promise(resolve => prompt.question("Press Enter after login: ", resolve));
  prompt.close();

  await page.goto("https://my.act.org/", { waitUntil: "domcontentloaded" });
  await page.waitForTimeout(1000);
  if (/signin|login/i.test(page.url())) {
    throw new Error("ACT login was not detected. Keep the opened ACT window logged in and retry.");
  }
}

async function fetchJsonFromPage(page, url) {
  return page.evaluate(async requestUrl => {
    const response = await fetch(requestUrl, {
      credentials: "include",
      headers: {
        Accept: "application/json, text/plain, */*",
        "Cache-Control": "no-cache"
      }
    });
    return {
      status: response.status,
      body: await response.text()
    };
  }, url);
}

async function fetchJsonWithRetry(page, url, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt += 1) {
    const response = await fetchJsonFromPage(page, url);
    if (response.status < 500 || response.status >= 600 || attempt === maxRetries) {
      return response;
    }
    const delay = Math.min(30000, 2 ** attempt * 1000) + Math.floor(Math.random() * 1000);
    console.log(`HTTP ${response.status}; retry ${attempt + 1}/${maxRetries} after ${delay}ms...`);
    await new Promise(resolve => setTimeout(resolve, delay));
  }
}

function availableSlots(availability) {
  return Object.entries(availability).flatMap(([centerCode, value]) =>
    Object.entries(value.checks).flatMap(([modeKey, check]) =>
      check.summary.flatMap(schedule =>
        schedule.locations
          .filter(location => location.available)
          .map(location => ({
            center_code: centerCode,
            center_name: value.center?.institution ?? "",
            city: value.center?.city ?? "",
            mode: modeKey,
            room_type: check.room_type,
            standby: check.standby,
            test_date: schedule.test_date,
            start_time: schedule.start_time,
            location_type: location.location_type,
            seats_remaining: location.seats_remaining
          }))
      )
    )
  ).sort((left, right) =>
    left.test_date.localeCompare(right.test_date) ||
    left.start_time.localeCompare(right.start_time) ||
    left.center_name.localeCompare(right.center_name)
  );
}

async function collectAvailability(page, rows, config, modes, label = "combined") {
  const siteCodes = [...new Set(
    rows.map(row => row.center_code?.trim()).filter(Boolean)
  )];
  const availability = {};
  const totalRequests = siteCodes.length * modes.length;
  let completedRequests = 0;

  for (const [centerIndex, siteListingCode] of siteCodes.entries()) {
    const center = rows.find(row => row.center_code?.trim() === siteListingCode) ?? null;
    availability[siteListingCode] = { center, checks: {} };

    for (const [modeIndex, mode] of modes.entries()) {
      const params = new URLSearchParams({
        product: config.product,
        roomType: mode.roomType,
        seatAvailability: config.seatAvailability,
        siteListingCode,
        standby: mode.standby
      });
      const requestNumber = centerIndex * modes.length + modeIndex + 1;
      console.log(
        `[${label}] Checking ${requestNumber}/${totalRequests}: ` +
        `center ${siteListingCode} (${center?.institution ?? "unknown"}) ` +
        `${mode.key}...`
      );
      let response = await fetchJsonWithRetry(
        page,
        `https://my.act.org/api/test-scheduling/ACTNational/test-centers?${params}`
      );

      if (response.status === 401 || response.status === 403) {
        await notify("ACT availability checker", "The ACT session needs login in the opened browser.");
        await ensureLoggedIn(page);
        response = await fetchJsonWithRetry(
          page,
          `https://my.act.org/api/test-scheduling/ACTNational/test-centers?${params}`
        );
      }
      if (response.status < 200 || response.status >= 300) {
        throw new Error(
          `ACT returned ${response.status} for center ${siteListingCode} mode ${mode.key}`
        );
      }

      const responsePayload = JSON.parse(response.body);
      availability[siteListingCode].checks[mode.key] = {
        room_type: mode.roomType,
        standby: mode.standby,
        response: responsePayload,
        summary: summarizeAvailability(responsePayload, mode.standby)
      };
      completedRequests += 1;
      const availableCount = availability[siteListingCode].checks[mode.key].summary
        .flatMap(schedule => schedule.locations)
        .filter(location => location.available)
        .length;
      console.log(
        `[${label}] Completed ${completedRequests}/${totalRequests}: ` +
        `center ${siteListingCode}, ${mode.key}, HTTP ${response.status}, ` +
        `${availableCount} available slot(s)`
      );
      await new Promise(resolve => setTimeout(resolve, Number(config.availabilityDelay) * 1000));
    }
  }

  return { availability, siteCodes };
}

async function main() {
  const args = process.argv.slice(2);
  const stateCsvArgs = [];
  const csvPaths = [];
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === "--state-csv" && args[index + 1]) {
      stateCsvArgs.push(args[index + 1]);
      index += 1;
    } else if (args[index] === "--csv" && args[index + 1]) {
      csvPaths.push(args[index + 1]);
      index += 1;
    }
  }
  const outputIndex = args.indexOf("--output");
  const outputDirIndex = args.indexOf("--output-dir");
  const config = await readConfig();
  const modes = [...new Map(
    config.availabilityModes.map(mode => [
      `${mode.key}|${mode.roomType}|${mode.standby}`,
      mode
    ])
  ).values()];

  if (!modes.length) throw new Error("No availability modes configured");

  const jobs = stateCsvArgs.length
    ? stateCsvArgs.map(spec => {
        const { label, csvPath } = parseStateCsvSpec(spec);
        return {
          label,
          csvPaths: [csvPath],
          outputPath: path.join(
            outputDirIndex >= 0 ? args[outputDirIndex + 1] : dataDir,
            `availability-${label}.json`
          )
        };
      })
    : [{
        label: null,
        csvPaths: csvPaths.length ? csvPaths : [defaultCsv],
        outputPath: outputIndex >= 0 ? args[outputIndex + 1] : defaultOutput
      }];

  const outputPaths = new Set();
  for (const job of jobs) {
    if (outputPaths.has(job.outputPath)) {
      throw new Error(`Duplicate state output path: ${job.outputPath}`);
    }
    outputPaths.add(job.outputPath);
  }

  await fs.mkdir(dataDir, { recursive: true });
  const context = await chromium.launchPersistentContext(profileDir, {
    channel: "chrome",
    headless: false
  });
  const page = await context.newPage();
  await ensureLoggedIn(page);

  for (const job of jobs) {
    const rows = (
      await Promise.all(job.csvPaths.map(async csvPath => parseCsv(await fs.readFile(csvPath, "utf8"))))
    ).flat();
    const { availability, siteCodes } = await collectAvailability(
      page,
      rows,
      config,
      modes,
      job.label ?? "combined"
    );
    const next = {
      checkedAt: new Date().toISOString(),
      sourceCsv: job.csvPaths,
      config,
      availableSlots: availableSlots(availability),
      availability
    };

    let previous = null;
    try {
      previous = JSON.parse(await fs.readFile(job.outputPath, "utf8"));
    } catch {}

    await fs.mkdir(path.dirname(job.outputPath), { recursive: true });
    await fs.writeFile(job.outputPath, JSON.stringify(next, null, 2) + "\n");
    const changed = stableJson(previous?.availability) !== stableJson(next.availability);
    console.log(`${job.label ?? "combined"}: ${changed ? "Availability changed." : "No availability changes."}`);
    console.log(`Checked ${siteCodes.length} centers with ${modes.length} modes.`);
    console.log(`Available slots: ${next.availableSlots.length}`);
    for (const slot of next.availableSlots) console.log(JSON.stringify(slot));
    console.log(`Saved ${job.outputPath}`);
    if (changed) await notify("ACT availability changed", `Review ${job.outputPath}.`);
  }

  await context.close();
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
