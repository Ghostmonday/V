#!/usr/bin/env python3
"""extract_strings.py

A small, opinionated utility that scans the TypeScript source tree for
user‑facing strings (error messages, button labels, help text, etc.).
It produces a markdown report (`USER_FACING_STRINGS_AUTO.md`) that lists
each string together with its source file, line number and a short context
snippet.

The script is deliberately lightweight – it works with regular
expressions only and does not require a full TypeScript parser.  It is
still accurate enough for most copy‑editing workflows and can be run
repeatedly during development.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, TypedDict

# ---------------------------------------------------------------------------
# Configuration – tweak these patterns to broaden or narrow the search.
# ---------------------------------------------------------------------------
# Patterns that indicate a line is *likely* user‑facing.  They match common
# Express response helpers, thrown errors and JSX/HTML literals.
USER_FACING_PATTERNS: List[re.Pattern] = [
    re.compile(r"res\.status\(\d+\)\.json", re.IGNORECASE),
    re.compile(r"res\.json\(", re.IGNORECASE),
    re.compile(r"throw new.*Error", re.IGNORECASE),
    re.compile(r"\b(message|error|label|title|placeholder|text|description|toast|alert|notification|success|warning)\s*[:=]", re.IGNORECASE),
    re.compile(r"<[^>]+>.*</[^>]+>", re.IGNORECASE),  # JSX / HTML tags
]

# Patterns that look like *code* rather than UI text – we filter these out.
CODE_LIKE_PATTERNS: List[re.Pattern] = [
    re.compile(r"^[a-z_]+$"),               # snake_case identifiers
    re.compile(r"^[A-Z_]+$"),               # CONSTANTS
    re.compile(r"^\\."),                  # file extensions like .ts
    re.compile(r"^/[^/]+"),                # absolute paths
    re.compile(r"^\\w+\\.\\w+$"),      # module.method
    re.compile(r"SELECT|INSERT|UPDATE|DELETE", re.IGNORECASE),
    re.compile(r"^\\d+$"),                # pure numbers
]

# ---------------------------------------------------------------------------
# Helper data structures
# ---------------------------------------------------------------------------
class StringEntry(TypedDict):
    line: int
    string: str
    context: str

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------
def is_user_facing(line: str) -> bool:
    """Return ``True`` if *line* appears to contain user‑facing content.

    The check is deliberately fuzzy – a false positive is harmless because
    the string will later be filtered by :func:`is_code_like`.
    """
    return any(p.search(line) for p in USER_FACING_PATTERNS)


def is_code_like(text: str) -> bool:
    """Return ``True`` if *text* looks like a code identifier.

    This helps us ignore things like ``"GET"`` or ``"POST"`` that are not
    meant for the end‑user.
    """
    return any(p.search(text) for p in CODE_LIKE_PATTERNS)


def extract_quoted_strings(line: str) -> List[str]:
    """Extract single‑, double‑ and back‑tick quoted strings from *line*.

    Only strings longer than three characters are considered – short
    literals such as ``"id"`` are usually not user‑visible.
    """
    patterns = [
        r"'([^'\\\\]*(?:\\\\.[^'\\\\]*)*)'",
        r'"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"',
        r'`([^`\\\\]*(?:\\\\.[^`\\\\]*)*)`',
    ]
    strings: List[str] = []
    for pat in patterns:
        strings.extend(re.findall(pat, line))
    # Filter out code‑like fragments and very short literals
    return [s for s in strings if len(s) > 3 and not is_code_like(s)]


def scan_file(filepath: Path) -> List[StringEntry]:
    """Return a list of user‑facing strings found in *filepath*.

    Each entry contains the line number, the raw string and a trimmed
    snippet of the surrounding source line (max 100 characters).
    """
    entries: List[StringEntry] = []
    try:
        with filepath.open("r", encoding="utf-8") as f:
            for lineno, raw in enumerate(f, start=1):
                if is_user_facing(raw):
                    for s in extract_quoted_strings(raw):
                        entries.append(
                            {
                                "line": lineno,
                                "string": s,
                                "context": raw.strip()[:100],
                            }
                        )
    except Exception as exc:  # pragma: no cover – defensive
        print(f"[extract_strings] Could not read {filepath}: {exc}", file=sys.stderr)
    return entries


def categorize(filepath: Path) -> str:
    """Return a high‑level category for *filepath* based on its path.

    The mapping is simple and can be extended by editing the ``CATEGORIES``
    dictionary below.
    """
    CATEGORIES: Dict[str, List[str]] = {
        "Authentication": ["auth", "login", "signin", "signup"],
        "Moderation": ["moderation", "flagging"],
        "Messaging": ["message", "chat"],
        "User Management": ["user", "profile"],
        "Rooms": ["room"],
        "Subscriptions": ["subscription", "iap", "entitlement"],
        "File Management": ["file", "upload", "storage"],
        "Notifications": ["notify", "notification", "alert"],
        "Search": ["search"],
        "Telemetry": ["telemetry", "analytics"],
        "Video/Voice": ["video", "voice", "agora", "livekit"],
        "Admin": ["admin"],
        "Gamification": ["gamification", "achievement"],
        "Scheduling": ["scheduling", "calendar"],
        "Privacy": ["privacy", "gdpr"],
        "Security": ["security", "encryption", "brute"],
        "Rate Limiting": ["rate-limit"],
        "Error Handling": ["error-middleware"],
        "Validation": ["validation"],
    }
    path_str = str(filepath).lower()
    for cat, keywords in CATEGORIES.items():
        if any(kw in path_str for kw in keywords):
            return cat
    return "Other"


def generate_markdown(results: Dict[str, Dict[str, List[StringEntry]]]) -> str:
    """Create the final markdown report from *results*.

    ``results`` is a nested mapping ``category → file → entries``.
    """
    lines: List[str] = ["# User‑Facing Strings – Automated Extraction\n\n"]
    total_categories = len(results)
    total_files = sum(len(files) for files in results.values())
    lines.append(f"**Categories:** {total_categories}  ")
    lines.append(f"**Files scanned:** {total_files}\n\n")

    for category in sorted(results):
        lines.append(f"## {category}\n")
        for file_path in sorted(results[category]):
            entries = results[category][file_path]
            lines.append(f"\n### `{file_path}`\n")
            lines.append(f"**Found {len(entries)} strings**\n\n")
            lines.append("| Line | String | Context |\n")
            lines.append("|------|--------|----------|\n")
            for e in entries:
                # Escape markdown pipe characters
                s = e["string"].replace("|", "\\|")
                c = e["context"].replace("|", "\\|")
                lines.append(f"| {e['line']} | {s} | {c} |\n")
        lines.append("\n")
    return "".join(lines)


def main() -> None:
    """Entry‑point for the script.

    It walks ``src/`` recursively, extracts strings, groups them by
    category and writes ``USER_FACING_STRINGS_AUTO.md`` in the project
    root.
    """
    src_root = Path("src")
    if not src_root.is_dir():
        print("[extract_strings] No 'src' directory found – aborting.", file=sys.stderr)
        sys.exit(1)

    # Nested dict: category → file → list of entries
    results: Dict[str, Dict[str, List[StringEntry]]] = defaultdict(lambda: defaultdict(list))

    for ts_file in src_root.rglob("*.ts*"):
        # Skip test files, type definitions and node_modules
        if any(skip in str(ts_file) for skip in ["__tests__", ".test.", ".spec.", ".d.ts", "node_modules"]):
            continue
        entries = scan_file(ts_file)
        if entries:
            cat = categorize(ts_file)
            results[cat][str(ts_file)].extend(entries)

    markdown = generate_markdown(results)
    out_path = Path("USER_FACING_STRINGS_AUTO.md")
    out_path.write_text(markdown, encoding="utf-8")
    print(f"✅ Extraction complete – written {out_path}")
    print(f"📊 {sum(len(v) for cat in results.values() for v in cat.values())} strings found across {len(results)} categories")


if __name__ == "__main__":
    main()
