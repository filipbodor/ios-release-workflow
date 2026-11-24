import os
import re
import sys


def fail(message):
    sys.exit(message)


mode = os.environ["RELEASE_MODE"]
if mode not in {"check", "upload", "release", "submit-existing"}:
    fail("Mode must be check, upload, release, or submit-existing.")

version = os.environ["APP_VERSION"]
build = os.environ["APP_BUILD"]
if (mode != "check" or version) and not re.fullmatch(r"(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*)){1,2}", version):
    fail("Provide a marketing version such as 1.2.0.")
if (mode != "check" or build) and not re.fullmatch(r"[1-9][0-9]*", build):
    fail("Provide a positive integer build number.")

if mode in {"release", "submit-existing"}:
    notes = os.environ["RELEASE_NOTES"]
    if not notes.strip() or len(notes) > 4000:
        fail("Submission requires 1–4,000 characters of release notes.")
    if not re.fullmatch(r"[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*", os.environ["RELEASE_LOCALE"]):
        fail("Provide the App Store locale for the release notes.")

if mode != "check":
    if not re.fullmatch(r"[A-Z0-9]{10}", os.environ["APPLE_TEAM_ID"]):
        fail("Provide a 10-character Apple developer Team ID.")
    for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
        if not os.environ.get(name, "").strip():
            fail(f"Configure the {name} GitHub secret before publishing.")
    if not os.environ["ASC_PRIVATE_KEY"].strip().startswith("-----BEGIN PRIVATE KEY-----"):
        fail("ASC_PRIVATE_KEY must contain the raw App Store Connect .p8 key.")
