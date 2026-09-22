#!/usr/bin/env python3
"""Idempotent importer: maps this app's bundled exercises
(assets/data/exercises.json) to free-exercise-db
(https://github.com/yuhonas/free-exercise-db, Unlicense — the only
freely redistributable exercise-media source found after checking
wger.de, free-exercise-db, ExerciseDB, and API-Ninjas; see
docs/EXERCISE_IMAGES.md), downloads only the images those exercises
need, validates them, and reports the result.

The exercise/image pairing below (CURATED) was produced by an
automated name/equipment/muscle matcher and then HAND-VERIFIED against
the source dataset (the automated pass alone produced two confirmed
false positives — e.g. matching "Barbell Back Squat" to "Barbell Hack
Squat" purely on character similarity). Do not regenerate this table
by re-running the fuzzy matcher; edit it by hand and re-verify any
change the same way (exact-name lookup in the source dataset, or
explicit domain judgement for a same-family-but-not-identical name).

Usage:
    python3 tool/import_exercise_images.py --dry-run
    python3 tool/import_exercise_images.py --download
    python3 tool/import_exercise_images.py --validate
    python3 tool/import_exercise_images.py --download --exercise barbell-bench-press

Safe to re-run: skips any image file that already exists and is
non-empty. Never touches exercises not in CURATED (their gif/photo
stays absent, not guessed).
"""
import argparse
import json
import os
import struct
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MY_EXERCISES = os.path.join(ROOT, "assets/data/exercises.json")
MAPPING_OUT = os.path.join(ROOT, "assets/data/exercise_images_mapping.json")
IMAGES_DIR = os.path.join(ROOT, "assets/data/exercise_images")
REPORT_OUT = os.path.join(ROOT, "exercise-gif-import-report.json")
REGISTRY_OUT = os.path.join(ROOT, "lib/features/workouts/presentation/widgets/exercise_photo_registry.dart")
EXTERNAL_RAW_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises"
EXTERNAL_JSON_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"

# my_id -> (external exact name in free-exercise-db, status)
# status: "auto" (confident, same exercise) | "review" (same movement
# family, not an exact name/equipment match - still used, flagged).
CURATED = {
    "push-up": ("Pushups", "auto"),
    "incline-push-up": ("Incline Push-Up", "auto"),
    "pull-up": ("Pullups", "auto"),
    "assisted-pull-up": ("Band Assisted Pull-Up", "review"),
    "weighted-pull-up": ("Weighted Pull Ups", "auto"),
    "chin-up": ("Chin-Up", "auto"),
    "bodyweight-row": ("Inverted Row", "auto"),
    "squat": ("Bodyweight Squat", "auto"),
    "goblet-squat": ("Goblet Squat", "auto"),
    "barbell-back-squat": ("Barbell Squat", "auto"),
    "split-squat": ("Split Squats", "review"),
    "hip-thrust": ("Barbell Hip Thrust", "auto"),
    "plank": ("Plank", "auto"),
    "mountain-climber": ("Mountain Climbers", "auto"),
    "hanging-knee-raise": ("Hanging Leg Raise", "review"),
    "squat-jump": ("Freehand Jump Squat", "auto"),
    "walking": ("Walking, Treadmill", "review"),
    "jogging": ("Jogging, Treadmill", "review"),
    "cycling": ("Bicycling", "review"),
    "worlds-greatest-stretch": ("World's Greatest Stretch", "auto"),
    "barbell-bench-press": ("Barbell Bench Press - Medium Grip", "auto"),
    "incline-dumbbell-press": ("Incline Dumbbell Press", "auto"),
    "cable-chest-fly": ("Cable Crossover", "auto"),
    "incline-machine-press": ("Smith Machine Incline Bench Press", "review"),
    "cable-triceps-pushdown": ("Triceps Pushdown", "auto"),
    "overhead-cable-extension": ("Cable Rope Overhead Triceps Extension", "auto"),
    "close-grip-bench-press": ("Close-Grip Barbell Bench Press", "auto"),
    "rope-pushdown": ("Triceps Pushdown - Rope Attachment", "auto"),
    "lat-pulldown": ("Wide-Grip Lat Pulldown", "auto"),
    "barbell-row": ("Bent Over Barbell Row", "auto"),
    "seated-cable-row": ("Seated Cable Rows", "auto"),
    "straight-arm-pulldown": ("Straight-Arm Pulldown", "auto"),
    "tbar-row": ("Lying T-Bar Row", "auto"),
    "reverse-fly": ("Reverse Flyes", "auto"),
    "ez-bar-curl": ("EZ-Bar Curl", "auto"),
    "incline-dumbbell-curl": ("Incline Dumbbell Curl", "auto"),
    "hammer-curl": ("Hammer Curls", "auto"),
    "seated-dumbbell-shoulder-press": ("Seated Dumbbell Press", "auto"),
    "lateral-raise": ("Side Lateral Raise", "auto"),
    "rear-delt-fly": ("Cable Rear Delt Fly", "review"),
    "face-pull": ("Face Pull", "auto"),
    "hack-squat": ("Hack Squat", "auto"),
    "romanian-deadlift": ("Romanian Deadlift", "auto"),
    "leg-press": ("Leg Press", "auto"),
    "leg-curl": ("Lying Leg Curls", "auto"),
    "leg-extension": ("Leg Extensions", "auto"),
    "walking-lunge": ("Barbell Walking Lunge", "review"),
    "cable-crunch": ("Cable Crunch", "auto"),
}

NOT_MAPPED = {
    "diamond-push-up": "no confident close-grip/diamond variant found",
    "lunge": "no plain bodyweight lunge entry (only weighted/walking variants)",
    "bulgarian-split-squat": "no rear-foot-elevated variant; reusing plain Split Squats would misrepresent it",
    "glute-bridge": "no plain two-leg bodyweight version; only single-leg or barbell-loaded variants exist",
    "calf-raise": "no plain standing bodyweight version; only seated/machine variants exist",
    "side-plank": "no exact match; candidates are a different exercise or a transition drill",
    "burpee": "not present in this dataset at all",
    "jumping-jacks": "not present under this name; nearest (Star Jump) is plausibly a different movement",
    "high-knees": "not present in this dataset",
    "kettlebell-swing": "only a one-arm variant exists; would misrepresent the two-hand swing this app shows",
    "chest-supported-row": "no matching equipment setup found",
    "single-arm-cable-row": "only a cable crossover (a fly, not a row) came back as the closest name",
    "cat-cow": "only a generic 'Cat Stretch' exists; no matching cow-pose half of the movement",
}


def jpeg_dimensions(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[0:2] != b"\xff\xd8":
        return None
    i = 2
    while i < len(data) - 9:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3):
            h = struct.unpack(">H", data[i + 5:i + 7])[0]
            w = struct.unpack(">H", data[i + 7:i + 9])[0]
            return w, h
        if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        seg_len = struct.unpack(">H", data[i + 2:i + 4])[0]
        i += 2 + seg_len
    return None


def fetch_external_db():
    dest = "/tmp/free-exercise-db-exercises.json"
    if not os.path.exists(dest):
        urllib.request.urlretrieve(EXTERNAL_JSON_URL, dest)
    return json.load(open(dest))


def build_mapping():
    mine = {m["id"]: m for m in json.load(open(MY_EXERCISES))}
    ext_by_name = {e["name"]: e for e in fetch_external_db()}

    mapping = {}
    for my_id, (ext_name, status) in CURATED.items():
        ext = ext_by_name.get(ext_name)
        if ext is None:
            print(f"FATAL: curated external name not found in dataset: {ext_name!r} (for {my_id})", file=sys.stderr)
            sys.exit(1)
        mapping[my_id] = {
            "status": status,
            "external_id": ext["id"],
            "external_name": ext["name"],
            "my_name": mine[my_id]["name"],
            "images": ext["images"][:2],
            "source": "free-exercise-db",
            "source_url": "https://github.com/yuhonas/free-exercise-db",
            "license": "Unlicense",
        }
    for my_id, reason in NOT_MAPPED.items():
        mapping[my_id] = {"status": "no_match", "reason": reason}

    missing = set(mine) - set(CURATED) - set(NOT_MAPPED)
    if missing:
        print(f"FATAL: exercises not accounted for: {sorted(missing)}", file=sys.stderr)
        sys.exit(1)

    return mapping


def download(mapping, only_exercise=None):
    os.makedirs(IMAGES_DIR, exist_ok=True)
    downloaded, skipped, failed = 0, 0, []
    for my_id, entry in mapping.items():
        if entry["status"] not in ("auto", "review"):
            continue
        if only_exercise and my_id != only_exercise:
            continue
        for i, img_path in enumerate(entry.get("images", [])[:2]):
            dest = os.path.join(IMAGES_DIR, f"{my_id}-{i}.jpg")
            if os.path.exists(dest) and os.path.getsize(dest) > 0:
                skipped += 1
                continue
            url = f"{EXTERNAL_RAW_BASE}/{img_path}"
            try:
                urllib.request.urlretrieve(url, dest)
                if os.path.getsize(dest) == 0:
                    os.remove(dest)
                    failed.append((my_id, url, "zero bytes"))
                else:
                    downloaded += 1
            except Exception as e:  # noqa: BLE001 - report and continue importing the rest
                failed.append((my_id, url, str(e)))
    return downloaded, skipped, failed


def validate(mapping, only_exercise=None):
    report = {
        "total_exercises": len(mapping),
        "matched": 0,
        "downloaded": 0,
        "already_existing": 0,
        "missing": 0,
        "failed": [],
        "manual_review": [],
        "no_match": 0,
    }
    for my_id, entry in mapping.items():
        if only_exercise and my_id != only_exercise:
            continue
        if entry["status"] == "no_match":
            report["no_match"] += 1
            continue
        report["matched"] += 1
        if entry["status"] == "review":
            report["manual_review"].append(my_id)

        frames = [f for f in sorted(os.listdir(IMAGES_DIR)) if f.startswith(f"{my_id}-")] if os.path.isdir(IMAGES_DIR) else []
        if not frames:
            report["missing"] += 1
            continue

        ok = True
        for f in frames:
            path = os.path.join(IMAGES_DIR, f)
            size = os.path.getsize(path)
            if size == 0:
                report["failed"].append(f"{f}: zero bytes")
                ok = False
                continue
            dims = jpeg_dimensions(path)
            if dims is None:
                report["failed"].append(f"{f}: not a valid JPEG")
                ok = False
            elif dims[0] < 50 or dims[1] < 50:
                report["failed"].append(f"{f}: suspiciously small {dims}")
                ok = False
        if ok:
            report["downloaded"] += 1
    return report


def write_registry(mapping):
    matched = sorted(k for k, v in mapping.items() if v["status"] in ("auto", "review"))
    lines = [
        "/// Real exercise-position photos from free-exercise-db",
        "/// (https://github.com/yuhonas/free-exercise-db, Unlicense/public domain),",
        "/// hand-matched to this app's exercise IDs -- see",
        "/// assets/data/exercise_images_mapping.json for the full mapping,",
        "/// confidence tier, and source attribution per exercise.",
        "///",
        "/// Every exercise here has exactly 2 frames (start/end position),",
        "/// bundled as assets/data/exercise_images/`<id>-0.jpg` and `-1.jpg`.",
        "/// An exercise ID NOT in this set has no photo -- its detail card",
        "/// falls back to the vector animation instead.",
        "///",
        "/// Regenerated by tool/import_exercise_images.py -- do not hand-edit.",
        "const Set<String> kExercisesWithPhotos = {",
    ]
    lines += [f"  '{exercise_id}'," for exercise_id in matched]
    lines.append("};")
    with open(REGISTRY_OUT, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Build and print the mapping only, download nothing")
    parser.add_argument("--download", action="store_true", help="Download missing images (skips existing)")
    parser.add_argument("--validate", action="store_true", help="Validate downloaded images, write the report")
    parser.add_argument("--exercise", help="Limit to a single exercise id")
    args = parser.parse_args()

    if not (args.dry_run or args.download or args.validate):
        parser.error("pass at least one of --dry-run / --download / --validate")

    mapping = build_mapping()
    json.dump(mapping, open(MAPPING_OUT, "w"), indent=2)
    auto = sum(1 for v in mapping.values() if v["status"] == "auto")
    review = sum(1 for v in mapping.values() if v["status"] == "review")
    none_ = sum(1 for v in mapping.values() if v["status"] == "no_match")
    print(f"mapping: total={len(mapping)} auto={auto} review={review} no_match={none_}")

    if args.dry_run:
        for my_id, entry in mapping.items():
            if args.exercise and my_id != args.exercise:
                continue
            if entry["status"] == "no_match":
                print(f"  {my_id:32s} NO MATCH  ({entry['reason']})")
            else:
                print(f"  {my_id:32s} {entry['status']:6s}  -> {entry['external_name']}")
        return

    if args.download:
        downloaded, skipped, failed = download(mapping, only_exercise=args.exercise)
        print(f"download: downloaded={downloaded} skipped_existing={skipped} failed={len(failed)}")
        for f in failed:
            print(f"  FAILED: {f}")
        write_registry(mapping)
        print(f"wrote {REGISTRY_OUT}")

    if args.validate:
        report = validate(mapping, only_exercise=args.exercise)
        json.dump(report, open(REPORT_OUT, "w"), indent=2)
        print(json.dumps(report, indent=2))
        print(f"wrote {REPORT_OUT}")


if __name__ == "__main__":
    main()
