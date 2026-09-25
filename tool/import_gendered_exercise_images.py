#!/usr/bin/env python3
"""Downloads one male-presenting and one female-presenting demonstration
photo for the 13 exercises that free-exercise-db has no safe match for
(see NOT_MAPPED in import_exercise_images.py) and that therefore still
fell back to the vector stick-figure animation.

Source: Pexels (https://www.pexels.com/license/ — free for commercial
use, no attribution required). Every URL below was picked by hand,
viewing the actual photo, not trusted from a filename/keyword match —
same discipline as the free-exercise-db curation.

Usage:
    python3 tool/import_gendered_exercise_images.py --download
    python3 tool/import_gendered_exercise_images.py --validate

Safe to re-run: skips any image file that already exists and is
non-empty.
"""
import argparse
import json
import os
import struct
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES_DIR = os.path.join(ROOT, "assets/data/exercise_images")
MAPPING_OUT = os.path.join(ROOT, "assets/data/gendered_exercise_images_mapping.json")
REGISTRY_OUT = os.path.join(
    ROOT, "lib/features/workouts/presentation/widgets/gendered_exercise_photo_registry.dart"
)

# my_id -> {"male": (pexels_photo_id, photographer), "female": (...)}
CURATED = {
    "diamond-push-up": {"male": (4920478, "Andrea Piacquadio"), "female": (14623615, "Cats Coming")},
    "lunge": {"male": (13993813, "Cats Coming"), "female": (8770407, "Miriam Alonso")},
    "bulgarian-split-squat": {"male": (38796260, "Pexels"), "female": (13106607, "Pavel Danilyuk")},
    "glute-bridge": {"male": (4334848, "Miriam Alonso"), "female": (6516221, "Miriam Alonso")},
    "calf-raise": {"male": (8846487, "Pexels"), "female": (13965339, "Pexels")},
    "side-plank": {"male": (2294363, "Julia Larson"), "female": (8436141, "Miriam Alonso")},
    "burpee": {"male": (13993508, "Cats Coming"), "female": (30246184, "Pexels")},
    "jumping-jacks": {"male": (8544641, "Pexels"), "female": (6339345, "Miriam Alonso")},
    "high-knees": {"male": (8084766, "Pexels"), "female": (6339342, "Miriam Alonso")},
    "kettlebell-swing": {"male": (13106615, "Pavel Danilyuk"), "female": (14252286, "Pexels")},
    "chest-supported-row": {"male": (3888104, "Andrea Piacquadio"), "female": (6539844, "Pexels")},
    "single-arm-cable-row": {"male": (17559311, "Pexels"), "female": (38641894, "Pexels")},
    "cat-cow": {"male": (36764428, "Vitaly Gariev"), "female": (7663035, "Pexels")},
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


def build_mapping():
    mapping = {}
    for my_id, genders in CURATED.items():
        entry = {}
        for gender, (photo_id, photographer) in genders.items():
            entry[gender] = {
                "photo_id": photo_id,
                "photographer": photographer,
                "source_url": f"https://www.pexels.com/photo/{photo_id}/",
                "license": "Pexels License (free for commercial use, no attribution required)",
            }
        mapping[my_id] = entry
    return mapping


def download(mapping, only_exercise=None):
    downloaded, skipped, failed = 0, 0, []
    for my_id, genders in mapping.items():
        if only_exercise and my_id != only_exercise:
            continue
        for gender, info in genders.items():
            dest = os.path.join(IMAGES_DIR, f"{my_id}-{gender}.jpg")
            if os.path.exists(dest) and os.path.getsize(dest) > 0:
                skipped += 1
                continue
            url = f"https://images.pexels.com/photos/{info['photo_id']}/pexels-photo-{info['photo_id']}.jpeg?auto=compress&cs=tinysrgb&w=800"
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req) as resp, open(dest, "wb") as out:
                    out.write(resp.read())
                downloaded += 1
            except Exception as e:
                failed.append(f"{my_id}-{gender}: {e}")
    return downloaded, skipped, failed


def validate(mapping, only_exercise=None):
    report = {"total": 0, "valid": 0, "missing": [], "invalid": []}
    for my_id, genders in mapping.items():
        if only_exercise and my_id != only_exercise:
            continue
        for gender in genders:
            report["total"] += 1
            path = os.path.join(IMAGES_DIR, f"{my_id}-{gender}.jpg")
            if not os.path.exists(path) or os.path.getsize(path) == 0:
                report["missing"].append(f"{my_id}-{gender}")
                continue
            dims = jpeg_dimensions(path)
            if dims is None or dims[0] < 100 or dims[1] < 100:
                report["invalid"].append(f"{my_id}-{gender}")
                continue
            report["valid"] += 1
    return report


def write_registry(mapping):
    lines = [
        "/// Exercise IDs with a real male/female demonstration photo pair",
        "/// sourced from Pexels (see gendered_exercise_images_mapping.json) —",
        "/// for exercises free-exercise-db had no safe match for. Bundled as",
        "/// `assets/data/exercise_images/<id>-male.jpg` and `-female.jpg`.",
        "///",
        "/// Regenerated by tool/import_gendered_exercise_images.py — do not hand-edit.",
        "const Set<String> kGenderedExercisePhotos = {",
    ]
    lines += [f"  '{exercise_id}'," for exercise_id in sorted(mapping)]
    lines.append("};")
    with open(REGISTRY_OUT, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--exercise", help="Limit to a single exercise id")
    args = parser.parse_args()

    if not (args.download or args.validate):
        parser.error("pass --download and/or --validate")

    mapping = build_mapping()
    json.dump(mapping, open(MAPPING_OUT, "w"), indent=2)

    if args.download:
        downloaded, skipped, failed = download(mapping, only_exercise=args.exercise)
        print(f"download: downloaded={downloaded} skipped_existing={skipped} failed={len(failed)}")
        for f in failed:
            print(f"  FAILED: {f}")
        if failed:
            sys.exit(1)
        write_registry(mapping)
        print(f"wrote {REGISTRY_OUT}")

    if args.validate:
        report = validate(mapping, only_exercise=args.exercise)
        print(json.dumps(report, indent=2))
        if report["missing"] or report["invalid"]:
            sys.exit(1)


if __name__ == "__main__":
    main()
