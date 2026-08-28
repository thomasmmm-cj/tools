#!/usr/bin/env python3
"""Query ACT's public test-center REST endpoint."""

import argparse
import csv
import json
import random
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


API_URL = "https://www.act.org/services/TestSchedulingSites.json"
DATES_URL = "https://www.act.org/services/TestSchedulingDates.json"


def read_zips(args):
    values = list(args.zip_code)
    if args.zip_file:
        values += [
            line.strip()
            for line in Path(args.zip_file).read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
    result = []
    for value in values:
        if value.isdigit() and len(value) == 5 and value not in result:
            result.append(value)
    if not result:
        raise SystemExit("Provide --zip-code or --zip-file.")
    return result


def resource_list(payload):
    try:
        return payload["response"]["data"]["resource_list"]
    except (KeyError, TypeError):
        raise ValueError("Unexpected ACT response: response.data.resource_list was not found")


def get_json(url, params, max_retries=3):
    request_url = f"{url}?{urlencode(params)}"
    request = Request(
        request_url,
        headers={
            "Accept": "application/json",
            "User-Agent": "ACT-center-checker/1.0",
        },
    )
    for attempt in range(max_retries + 1):
        try:
            with urlopen(request, timeout=30) as response:
                return json.load(response)
        except HTTPError as error:
            if not 500 <= error.code <= 599 or attempt >= max_retries:
                raise
            retry_delay = min(30, 2 ** attempt) + random.uniform(0, 1)
            print(
                f"HTTP {error.code}; retry {attempt + 1}/{max_retries} "
                f"after {retry_delay:.2f}s..."
            )
            time.sleep(retry_delay)


def wait_between_requests(args):
    delay = random.uniform(args.min_delay, args.max_delay)
    print(f"Waiting {delay:.2f}s before the next request...")
    time.sleep(delay)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True, help="Two-letter state, e.g. WA")
    parser.add_argument("--zip-code", action="append", default=[])
    parser.add_argument("--zip-file")
    parser.add_argument("--output", default="data/centers-simple.json")
    parser.add_argument("--min-delay", type=float, default=1.0)
    parser.add_argument("--max-delay", type=float, default=6.0)
    args = parser.parse_args()
    if args.min_delay < 0 or args.max_delay < args.min_delay:
        raise SystemExit("Require 0 <= --min-delay <= --max-delay.")

    all_records = {}
    invalid_zips = []
    raw_dir = Path(args.output).parent / "act-raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    for zip_code in read_zips(args):
        try:
            payload = get_json(
                API_URL,
                {
                    "product": "ACT",
                    "country": "US",
                    "state": args.state.upper(),
                    "zip": zip_code,
                },
            )
        except HTTPError as error:
            if error.code != 400:
                raise
            invalid_zips.append(zip_code)
            print(f"{zip_code}: skipped (ACT returned HTTP 400)")
            wait_between_requests(args)
            continue

        raw_path = raw_dir / f"sites-{zip_code}.json"
        raw_path.write_text(json.dumps(payload, indent=2) + "\n")

        if not payload.get("success"):
            raise ValueError(f"ACT reported an unsuccessful response for ZIP {zip_code}")

        for record in resource_list(payload):
            tc_id = record.get("tc_id")
            if tc_id is not None:
                all_records[str(tc_id)] = {
                    "tc_id": tc_id,
                    "institution": record.get("institution", ""),
                    "tc_type": record.get("tc_type", ""),
                    "street_address": record.get("street_address", ""),
                    "city": record.get("city", ""),
                    "state": record.get("state_id", args.state.upper()),
                    "country": record.get("country_id", "US"),
                    "zipcode": record.get("zipcode", ""),
                    "latitude": record.get("latitude", ""),
                    "longitude": record.get("longitude", ""),
                    "center_status": record.get("status", ""),
                    "education_code": record.get("education_code"),
                    "distance": record.get("distance"),
                    "source_zip": zip_code,
                    "center_code": "",
                    "center_codes": [],
                    "schedules": [],
                }

        print(f"{zip_code}: saved {raw_path}")
        wait_between_requests(args)

    for tc_id, record in all_records.items():
        dates_payload = get_json(
            DATES_URL,
            {"tc_id": tc_id, "product": "ACT"},
        )
        (raw_dir / f"dates-{tc_id}.json").write_text(
            json.dumps(dates_payload, indent=2) + "\n"
        )
        schedules = dates_payload.get("response", {}).get("data", {}).get(
            "resource_list", []
        )
        record["schedules"] = schedules
        record["center_codes"] = sorted({
            str(schedule.get("tc_code"))
            for schedule in schedules
            if schedule.get("tc_code")
        })
        if record["center_codes"]:
            record["center_code"] = record["center_codes"][0]
        print(f"tc_id {tc_id}: saved {len(schedules)} dates")
        wait_between_requests(args)

    invalid_path = Path(args.output).parent / (
        f"invalid-zips-{Path(args.output).stem}.txt"
    )
    invalid_path.write_text("\n".join(invalid_zips) + ("\n" if invalid_zips else ""))
    records = sorted(all_records.values(), key=lambda row: (row["city"], row["institution"]))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(records, indent=2) + "\n")

    csv_path = output.with_suffix(".csv")
    with csv_path.open("w", newline="") as handle:
        fieldnames = [
            "tc_id", "center_code", "institution", "tc_type", "street_address",
            "city", "state", "country", "zipcode", "latitude", "longitude",
            "center_status", "source_zip", "tc_date_id", "test_date",
            "start_time", "schedule_status", "program_id", "cycle_id",
            "published_tc"
        ]
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for record in records:
            schedules = record["schedules"] or [{}]
            for schedule in schedules:
                writer.writerow({
                    "tc_id": record["tc_id"],
                    "center_code": schedule.get("tc_code") or record["center_code"],
                    "institution": record["institution"],
                    "tc_type": record["tc_type"],
                    "street_address": record["street_address"],
                    "city": record["city"],
                    "state": record["state"],
                    "country": record["country"],
                    "zipcode": record["zipcode"],
                    "latitude": record["latitude"],
                    "longitude": record["longitude"],
                    "center_status": record["center_status"],
                    "source_zip": record["source_zip"],
                    "tc_date_id": schedule.get("tc_date_id", ""),
                    "test_date": schedule.get("test_date", ""),
                    "start_time": schedule.get("start_time", ""),
                    "schedule_status": schedule.get("status", ""),
                    "program_id": schedule.get("program_id", ""),
                    "cycle_id": schedule.get("cycle_id", ""),
                    "published_tc": schedule.get("published_tc", ""),
                })

    print(f"Saved {len(records)} unique centers and date responses to {output} and {csv_path}")
    print(f"Skipped {len(invalid_zips)} invalid ZIPs; saved list to {invalid_path}")


if __name__ == "__main__":
    main()
