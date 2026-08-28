#!/usr/bin/env python3
"""Crawl official ACT center codes for a controlled list of ZIP codes."""

import argparse
import asyncio
import csv
import json
from pathlib import Path

from playwright.async_api import async_playwright


LOCATOR_URL = (
    "https://www.act.org/content/act/en/products-and-services/"
    "the-act/registration/test-center-locator.html"
)


def read_zip_codes(args):
    values = list(args.zip_code)
    if args.zip_file:
        values.extend(
            line.strip()
            for line in Path(args.zip_file).read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        )

    result = []
    for value in values:
        if value.isdigit() and len(value) == 5 and value not in result:
            result.append(value)
    if not result:
        raise SystemExit("Provide at least one five-digit ZIP with --zip-code or --zip-file.")
    return result


async def choose_state(page, state):
    select = page.locator("#tc_state")
    await select.select_option(label=state)


async def search_zip(page, zip_code, state):
    await choose_state(page, state)
    await page.locator("#zip").fill(zip_code)
    await page.get_by_role("button", name="Search").click()
    await page.locator(".test-centre-search-results").wait_for(state="visible")
    await page.wait_for_timeout(700)


async def collect_results(page, zip_code, state):
    await search_zip(page, zip_code, state)
    tiles = page.locator(".result-tile")
    load_more = page.locator(".test-centre-loader a")
    previous_count = -1
    while await tiles.count() != previous_count:
        previous_count = await tiles.count()
        if not await load_more.is_visible():
            break
        await load_more.click()
        await page.wait_for_timeout(700)

    records = []

    for index in range(await tiles.count()):
        tile = tiles.nth(index)
        city = (await tile.locator(".center-city").inner_text()).strip()
        name = (await tile.locator(".center-name").inner_text()).strip()
        internal_id = await tile.locator("[data-tcid]").get_attribute("data-tcid")

        # The official code and dates are loaded when a result tile is opened.
        await tile.locator(".result-head").click()
        detail = tile.locator(".result-detail")
        await detail.wait_for(state="visible")

        detail_text = (await detail.inner_text()).strip()
        lines = [line.strip() for line in detail_text.splitlines() if line.strip()]
        center_code = ""
        dates = []
        for position, line in enumerate(lines):
            if line.lower() == "center code" and position + 1 < len(lines):
                center_code = lines[position + 1]
            if line.lower() in {"test dates", "test date"}:
                dates = lines[position + 1 :]
                break

        records.append(
            {
                "state": state,
                "zip_code": zip_code,
                "city": city,
                "center_name": name,
                "center_code": center_code,
                "scheduled_dates": dates,
                "internal_locator_id": internal_id or "",
            }
        )

    return records


async def run(args):
    zip_codes = read_zip_codes(args)
    all_records = {}

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(headless=not args.visible)
        page = await browser.new_page()
        await page.goto(LOCATOR_URL, wait_until="domcontentloaded")

        for zip_code in zip_codes:
            try:
                records = await collect_results(page, zip_code, args.state)
                for record in records:
                    key = record["center_code"] or record["internal_locator_id"]
                    all_records[key] = record
                print(f"{zip_code}: {len(records)} centers")
            except Exception as error:
                print(f"{zip_code}: ERROR: {error}")
            await asyncio.sleep(args.delay)

        await browser.close()

    records = sorted(all_records.values(), key=lambda item: (
        item["state"], item["city"], item["center_name"]
    ))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(records, indent=2) + "\n")

    csv_path = output.with_suffix(".csv")
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "state",
                "zip_code",
                "city",
                "center_name",
                "center_code",
                "scheduled_dates",
                "internal_locator_id",
            ],
        )
        writer.writeheader()
        for record in records:
            row = dict(record)
            row["scheduled_dates"] = "; ".join(row["scheduled_dates"])
            writer.writerow(row)

    print(f"Saved {len(records)} unique centers to {output} and {csv_path}")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True, help="ACT state label, e.g. Washington")
    parser.add_argument("--zip-code", action="append", default=[])
    parser.add_argument("--zip-file", help="Text file containing one ZIP code per line")
    parser.add_argument("--output", default="data/centers.json")
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--visible", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    asyncio.run(run(parse_args()))
