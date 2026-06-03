#!/usr/bin/env python3
"""
Split the monolithic Writing Shed Pro Guide HTML into individual section files.

Creates:
  - guide_00-toc.html: Table of contents with links to section files
  - guide_{section-id}.html: Individual section files

Each file is self-contained with CSS. Section files include a "← Contents" link.
The app loads the tiny TOC for Help, and individual sections for Learn More or TOC clicks.

Usage:
    python3 split_guide.py

Output:
    Creates guide_*.html files in the Resources/User Guide directory.
"""

import re
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GUIDE_PATH = os.path.join(
    SCRIPT_DIR,
    "WrtingShedPro",
    "Writing Shed Pro",
    "Resources",
    "Writing Shed Pro Guide.html",
)
OUTPUT_DIR = os.path.join(os.path.dirname(GUIDE_PATH), "User Guide")


def extract_css(html: str) -> str:
    """Extract the CSS from the <style> block."""
    match = re.search(r"<style>(.*?)</style>", html, re.DOTALL)
    if match:
        css = match.group(1)
        css += """
/* In-app overrides */
body { margin-top: 0 !important; padding-top: 8px !important; }
body > *:first-child { margin-top: 0 !important; }
.back-nav { margin-bottom: 0.5em; }
.back-nav a { color: #0066cc; text-decoration: none; font-size: 0.95em; }
@media (prefers-color-scheme: dark) {
    .back-nav a { color: #4da3ff; }
}
"""
        return css
    return ""


def extract_toc(html: str) -> str:
    """Extract the table of contents section."""
    toc_start = html.find('<a id="00-toc"></a>')
    if toc_start == -1:
        return ""

    anchor_pattern = re.compile(r'<a id="(\d{2,3}-[a-z0-9-]+)"></a>')
    first_section_pos = None
    for match in anchor_pattern.finditer(html):
        if match.group(1) != "00-toc":
            first_section_pos = match.start()
            break

    if first_section_pos is None:
        return ""

    toc_html = html[toc_start:first_section_pos].strip()

    # Convert anchor links to guide: scheme for WKWebView interception
    toc_html = re.sub(
        r'href="#(\d{2,3}-[a-z0-9-]+)"',
        r'href="guide:\1"',
        toc_html,
    )

    return toc_html


def split_guide():
    """Split the guide HTML into individual section files."""
    # Remove old guide_*.html files first
    for f in os.listdir(OUTPUT_DIR):
        if f.startswith("guide_") and f.endswith(".html"):
            os.remove(os.path.join(OUTPUT_DIR, f))
            
    with open(GUIDE_PATH, "r", encoding="utf-8") as f:
        html = f.read()

    css = extract_css(html)

    # --- Create TOC file ---
    toc_content = extract_toc(html)
    toc_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Writing Shed Pro Guide</title>
    <style>{css}</style>
</head>
<body>
{toc_content}
</body>
</html>
"""
    toc_path = os.path.join(OUTPUT_DIR, "guide_00-toc.html")
    with open(toc_path, "w", encoding="utf-8") as f:
        f.write(toc_html)
    print(f"  ✅ guide_00-toc.html ({toc_content.count(chr(10)) + 1} lines)")

    # --- Create section files ---
    anchor_pattern = re.compile(r'<a id="(\d{2,3}-[a-z0-9-]+)"></a>')

    anchors = []
    for match in anchor_pattern.finditer(html):
        anchors.append((match.start(), match.group(1)))

    if not anchors:
        print("No section anchors found!")
        return

    print(f"Found {len(anchors)} sections")

    created = 0
    for i, (pos, section_id) in enumerate(anchors):
        if section_id == "00-toc":
            continue

        if i + 1 < len(anchors):
            end_pos = anchors[i + 1][0]
        else:
            body_end = html.find("</body>", pos)
            end_pos = body_end if body_end != -1 else len(html)

        section_content = html[pos:end_pos].strip()

        # Convert "Back to Contents" links to guide: scheme for WKWebView
        section_content = re.sub(
            r'<p class="back-to-top"><a href="#contents">.*?</a></p>',
            '<p class="back-to-top"><a href="guide:00-toc">↑ Back to Contents</a></p>',
            section_content,
            flags=re.DOTALL,
        )

        # Convert internal anchor links to guide: scheme
        section_content = re.sub(
            r'href="#(\d{2,3}-[a-z0-9-]+)"',
            r'href="guide:\1"',
            section_content,
        )

        section_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Writing Shed Pro Guide</title>
    <style>{css}</style>
</head>
<body>
<p class="back-nav"><a href="guide:00-toc">← Contents</a></p>
{section_content}
</body>
</html>
"""

        filename = f"guide_{section_id}.html"
        filepath = os.path.join(OUTPUT_DIR, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(section_html)

        lines = section_content.count("\n") + 1
        print(f"  ✅ {filename} ({lines} lines)")
        created += 1

    print(f"\nCreated {created + 1} files (1 TOC + {created} sections) in {OUTPUT_DIR}")


if __name__ == "__main__":
    split_guide()
