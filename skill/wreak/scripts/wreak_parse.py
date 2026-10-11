#!/usr/bin/env python3
"""Parse a .wreak file into structured blocks.

Usage:
    wreak_parse.py FILE [--format json|outline]

JSON output:
    {"file": ..., "blocks": [{"kind", "line", "end_line", "language",
      "file", "flags", "body", "implicit"}...], "warnings": [...]}

Standard library only (Python 3.8+), so agents can run it anywhere.
"""
import argparse
import json
import re
import sys
from pathlib import Path

KINDS = {"code": "code", "pseudo-code": "pseudo-code", "pseudocode": "pseudo-code", "text": "text"}
HEADER_RE = re.compile(r"^(code|pseudo-?code|text):(?=\s|$)(.*)$")
SHORT_FLAGS = {"-l": "language", "-f": "file"}
KNOWN_FLAGS = {"language", "file"}


def _load_aliases():
    path = Path(__file__).with_name("languages.json")
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


ALIASES = _load_aliases()


def normalize_language(name):
    if name is None:
        return None
    key = name.lower()
    return ALIASES.get(key, key)


def parse_flags(arg_text, lineno, warnings):
    """Parse `--key value`, `--key=value`, `--key` and `-l/-f value`."""
    flags = {}
    tokens = arg_text.split()
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith("--"):
            key, eq, val = tok[2:].partition("=")
            if not eq:
                nxt = tokens[i + 1] if i + 1 < len(tokens) else None
                if nxt is not None and not nxt.startswith("-"):
                    val, i = nxt, i + 1
                else:
                    val = True
        elif tok in SHORT_FLAGS:
            key = SHORT_FLAGS[tok]
            if i + 1 < len(tokens):
                val, i = tokens[i + 1], i + 1
            else:
                warnings.append(f"line {lineno}: {tok} expects a value")
                val = True
        else:
            warnings.append(f"line {lineno}: unexpected header argument {tok!r} (flags start with --)")
            i += 1
            continue
        if not key:
            warnings.append(f"line {lineno}: empty flag name")
        else:
            flags[key] = val
        i += 1
    return flags


def dedent_body(lines):
    while lines and not lines[-1].strip():
        lines.pop()
    while lines and not lines[0].strip():
        lines.pop(0)
    nonblank = [l for l in lines if l.strip()]
    if nonblank and all(l.startswith("\t") for l in nonblank):
        return [l[1:] if l.startswith("\t") else "" for l in lines]
    # Lenient fallback: remove the common leading whitespace (space-indented bodies).
    indent = min((len(l) - len(l.lstrip()) for l in nonblank), default=0)
    return [l[indent:] if l.strip() else "" for l in lines]


def parse(text):
    blocks, warnings = [], []
    current = None

    def close(end_line):
        nonlocal current
        if current is None:
            return
        raw = current.pop("_raw")
        while raw and not raw[-1].strip():
            raw.pop()
            end_line -= 1
        current["body"] = "\n".join(dedent_body(raw))
        current["end_line"] = end_line
        if not current["body"].strip() and not current["implicit"]:
            warnings.append(f"line {current['line']}: empty {current['kind']} block")
        blocks.append(current)
        current = None

    lines = text.splitlines()
    for lineno, line in enumerate(lines, 1):
        if line and not line[0].isspace():
            close(lineno - 1)
            if line.startswith("#"):
                continue
            m = HEADER_RE.match(line)
            if m:
                flags = parse_flags(m.group(2), lineno, warnings)
                lang = flags.get("language")
                path = flags.get("file")
                current = {
                    "kind": KINDS[m.group(1)],
                    "line": lineno,
                    "language": normalize_language(lang) if isinstance(lang, str) else None,
                    "file": path if isinstance(path, str) else None,
                    "flags": {k: v for k, v in flags.items() if k not in KNOWN_FLAGS},
                    "implicit": False,
                    "_raw": [],
                }
            else:
                warnings.append(f"line {lineno}: top-level text outside a block; treating it as text")
                blocks.append({
                    "kind": "text", "line": lineno, "end_line": lineno, "language": None,
                    "file": None, "flags": {}, "implicit": True, "body": line.strip(),
                })
            continue
        if current is None:
            if line.strip():
                warnings.append(f"line {lineno}: indented line outside a block; treating it as text")
                blocks.append({
                    "kind": "text", "line": lineno, "end_line": lineno, "language": None,
                    "file": None, "flags": {}, "implicit": True, "body": line.strip(),
                })
            continue
        current["_raw"].append(line)
    close(len(lines))
    # Merge consecutive implicit text lines into one block.
    merged = []
    for b in blocks:
        prev = merged[-1] if merged else None
        if b["implicit"] and prev and prev["implicit"] and b["line"] == prev["end_line"] + 1:
            prev["body"] += "\n" + b["body"]
            prev["end_line"] = b["end_line"]
        else:
            merged.append(b)
    return {"blocks": merged, "warnings": warnings}


def outline(result):
    out = []
    for i, b in enumerate(result["blocks"], 1):
        meta = []
        if b["language"]:
            meta.append(f"lang={b['language']}")
        if b["file"]:
            meta.append(f"file={b['file']}")
        meta += [f"{k}={v}" for k, v in b["flags"].items()]
        tag = " (implicit)" if b["implicit"] else ""
        out.append(f"[{i}] {b['kind']}{tag} L{b['line']}-{b['end_line']} {' '.join(meta)}".rstrip())
        for l in b["body"].splitlines():
            out.append(f"    | {l}")
    for w in result["warnings"]:
        out.append(f"warning: {w}")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("file", help="path to a .wreak file, or - for stdin")
    ap.add_argument("--format", choices=["json", "outline"], default="json")
    args = ap.parse_args(argv)
    text = sys.stdin.read() if args.file == "-" else Path(args.file).read_text()
    result = parse(text)
    if args.format == "json":
        print(json.dumps({"file": args.file, **result}, indent=2))
    else:
        print(outline(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
