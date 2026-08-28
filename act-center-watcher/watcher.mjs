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
const stateFile = path.join(dataDir, "latest.json");
const configFile = path.join(root, "config.json");

const defaultConfig = {
  zipCodes: ["98006", "98004", "98007", "98052", "98101"],
  product: "ACT",
  roomType: "BYOD REGULAR",
  seatAvailability: "ALL",
  standby: "false"
};

async function readConfig() {
  try {
    return { ...defaultConfig, ...JSON.parse(await fs.readFile(configFile, "utf8")) };
  } catch {
    await fs.writeFile(configFile, JSON.stringify(defaultConfig, null, 2) + "\n");
    return defaultConfig;
  }
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

async function main() {
  const loginOnly = process.argv.includes("--login");
  const config = await readConfig();
  await fs.mkdir(dataDir, { recursive: true });

  const context = await chromium.launchPersistentContext(profileDir, {
    channel: "chrome",
    headless: false
  });
  const page = await context.newPage();

  if (loginOnly) {
    await page.goto("https://my.act.org/", { waitUntil: "domcontentloaded" });
    console.log("Log in to ACT in the opened browser.");
    console.log("When the ACT dashboard is visible, return to this terminal and press Enter.");
    const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
    await new Promise(resolve => prompt.question("Press Enter to finish login setup: ", resolve));
    prompt.close();
    await context.close();
    console.log("Login profile saved. Now run: npm run availability");
    return;
  }

  const results = {};

  for (const zipCode of config.zipCodes) {
    const params = new URLSearchParams({
      product: config.product,
      roomType: config.roomType,
      seatAvailability: config.seatAvailability,
      standby: config.standby,
      zipCode
    });

    const response = await page.request.get(
      `https://my.act.org/api/test-scheduling/ACTNational/test-centers?${params}`
    );

    if (response.status() === 401 || response.status() === 403) {
      await notify("ACT center watcher", "The ACT session expired. Run npm run login.");
      throw new Error(`ACT returned ${response.status()} for ZIP ${zipCode}`);
    }

    if (!response.ok()) {
      throw new Error(`ACT returned ${response.status()} for ZIP ${zipCode}`);
    }

    results[zipCode] = await response.json();
    await new Promise(resolve => setTimeout(resolve, 1500));
  }

  const next = {
    checkedAt: new Date().toISOString(),
    config,
    results
  };

  let previous = null;
  try {
    previous = JSON.parse(await fs.readFile(stateFile, "utf8"));
  } catch {}

  await fs.writeFile(stateFile, JSON.stringify(next, null, 2) + "\n");

  const changed = stableJson(previous?.results) !== stableJson(next.results);
  console.log(changed ? "ACT results changed." : "No ACT result changes.");
  console.log(`Saved ${stateFile}`);

  if (changed) {
    await notify("ACT test-center results changed", "Review the latest ACT center snapshot.");
  }

  await context.close();
}

main().catch(async error => {
  console.error(error.message);
  process.exitCode = 1;
});
