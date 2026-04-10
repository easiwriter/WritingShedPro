#!/usr/bin/env python3
"""Build the support agent system prompt from SUPPORT_KNOWLEDGE_BASE.md.

Reads docs/SUPPORT_KNOWLEDGE_BASE.md, strips markdown formatting into a
compact plain-text prompt, prepends the agent rules, and writes the result
to cloudflare-worker/src/system-prompt.txt.

Run manually or via `npm run build` in the cloudflare-worker directory.
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
KB_PATH = REPO_ROOT / "docs" / "SUPPORT_KNOWLEDGE_BASE.md"
OUT_PATH = Path(__file__).resolve().parent / "src" / "system-prompt.txt"

RULES_PREAMBLE = """\
You are a support assistant for Writing Shed Pro, a professional writing app for iOS and macOS.

RULES:
- Never mention that you are an AI, language model, or automated system.
- Respond as "Writing Shed Pro Support".
- Only describe features that exist in the app. Never invent features.
- If you cannot resolve the issue, recommend the user tap "Ask Developer" to email the developer directly.
- Keep responses concise, friendly, and actionable.
- When suggesting steps, use numbered lists.
- When a user mentions a tutorial, refer them to the in-app guide tutorials listed below.

"""


def strip_markdown(text: str) -> str:
    """Convert knowledge-base markdown to compact plain text for a system prompt."""
    lines = text.splitlines()
    out: list[str] = []

    # Skip file title and intro — start from the first ## heading
    started = False

    for line in lines:
        stripped = line.rstrip()

        # Skip everything before the first ## (level 2) heading
        if not started:
            if re.match(r"^##\s", stripped):
                started = True
            else:
                continue

        # Convert markdown headings to plain labels
        m = re.match(r"^(#{1,3})\s+(.*)", stripped)
        if m:
            level = len(m.group(1))
            title = m.group(2).strip()
            if level == 2:
                # Section heading — blank line before, uppercase
                out.append("")
                out.append(f"{title.upper()}:")
            elif level == 3:
                # Sub-section heading
                out.append(f"{title}:")
            continue

        # Strip horizontal rules
        if re.match(r"^-{3,}$", stripped):
            continue

        # Convert markdown table rows to "Key: Value" or keep as-is
        if stripped.startswith("|"):
            # Skip table separator rows
            if re.match(r"^\|[-| :]+\|$", stripped):
                continue
            # Strip leading/trailing pipes and reformat
            cells = [c.strip() for c in stripped.strip("|").split("|")]
            # Strip bold/italic/backtick markers from cells
            cells = [re.sub(r"\*\*(.+?)\*\*", r"\1", c) for c in cells]
            cells = [re.sub(r"\*(.+?)\*", r"\1", c) for c in cells]
            cells = [re.sub(r"`(.+?)`", r"\1", c) for c in cells]
            out.append(" | ".join(cells))
            continue

        # Strip bold/italic markers
        cleaned = stripped
        cleaned = re.sub(r"\*\*(.+?)\*\*", r"\1", cleaned)
        cleaned = re.sub(r"\*(.+?)\*", r"\1", cleaned)
        # Strip inline code backticks
        cleaned = re.sub(r"`(.+?)`", r"\1", cleaned)

        out.append(cleaned)

    # Collapse multiple blank lines
    result: list[str] = []
    prev_blank = False
    for line in out:
        if line.strip() == "":
            if not prev_blank:
                result.append("")
            prev_blank = True
        else:
            result.append(line)
            prev_blank = False

    return "\n".join(result).strip()


def main() -> int:
    if not KB_PATH.exists():
        print(f"ERROR: Knowledge base not found at {KB_PATH}", file=sys.stderr)
        return 1

    kb_text = KB_PATH.read_text(encoding="utf-8")
    prompt_body = strip_markdown(kb_text)
    full_prompt = RULES_PREAMBLE + prompt_body

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(full_prompt, encoding="utf-8")

    lines = full_prompt.count("\n") + 1
    print(f"✓ Built system prompt: {OUT_PATH.relative_to(REPO_ROOT)} ({lines} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
