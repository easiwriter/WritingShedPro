#!/usr/bin/env python3
"""
Build the monolithic Writing Shed Pro Guide HTML from markdown source files.

Reads all markdown files from docs/wsp-guide/ in correct numerical order,
converts each to HTML, inserts proper section anchors (<a id="XX-name">),
and assembles a single monolithic Writing Shed Pro Guide.html.

The section anchor IDs are derived from the markdown filename (e.g.,
21-installation.md → <a id="21-installation"></a>).

Usage:
    python3 build_guide.py

Output:
    Overwrites Writing Shed Pro Guide.html in the Resources directory.

After running this, run split_guide.py to regenerate the individual section files.
"""

import os
import re
import markdown

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GUIDE_SRC = os.path.join(SCRIPT_DIR, "docs", "wsp-guide")
OUTPUT_PATH = os.path.join(
    SCRIPT_DIR,
    "WrtingShedPro",
    "Writing Shed Pro",
    "Resources",
    "Writing Shed Pro Guide.html",
)

# CSS matching the existing guide style
CSS = """body { 
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    max-width: 800px;
    margin: 40px auto;
    padding: 20px;
    line-height: 1.6;
    color: #333;
}
h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; }
h1 { font-size: 2em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
h2 { font-size: 1.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
pre { background: #f4f4f4; padding: 16px; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 16px; color: #666; }
table { border-collapse: collapse; width: 100%; margin: 1em 0; }
th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
th { background: #f4f4f4; font-weight: bold; }
ul, ol { padding-left: 2em; }
a { color: #0066cc; }
hr { border: none; border-top: 1px solid #ddd; margin: 2em 0; }
/* Back to Contents link */
.back-to-top {
    text-align: right;
    font-size: 0.9em;
    margin: 1.5em 0 0.5em 0;
}
.back-to-top a {
    color: #666;
    text-decoration: none;
}
.back-to-top a:hover {
    color: #0066cc;
    text-decoration: underline;
}
@media (prefers-color-scheme: dark) {
    body { background: #1a1a1a; color: #e0e0e0; }
    code, pre { background: #2d2d2d; }
    th { background: #2d2d2d; }
    th, td { border-color: #444; }
    blockquote { border-color: #555; color: #aaa; }
    h1, h2 { border-color: #444; }
    a { color: #4da3ff; }
    .back-to-top a { color: #999; }
}"""

# Chapter directories in order — these match the folder names in docs/wsp-guide/
CHAPTERS = [
    "1-welcome",
    "2-tutorials",
    "3-getting-started",
    "4-projects",
    "5-writing",
    "6-prose-features",
    "7-poetry-features",
    "8-fiction-features",
    "9-drama-features",
    "10-publishing",
    "11-advanced-features",
    "12-reference",
    "13-appendices",
]

# Chapter display names for the TOC
CHAPTER_NAMES = {
    "1-welcome": "1. Welcome",
    "2-tutorials": "2. Tutorials",
    "3-getting-started": "3. Getting Started",
    "4-projects": "4. Projects",
    "5-writing": "5. Writing",
    "6-prose-features": "6. Prose Features",
    "7-poetry-features": "7. Poetry Features",
    "8-fiction-features": "8. Fiction Features",
    "9-drama-features": "9. Drama Features",
    "10-publishing": "10. Publishing",
    "11-advanced-features": "11. Advanced Features",
    "12-reference": "12. Reference",
    "13-appendices": "13. Appendices",
}

# Optional external links appended at the end of a chapter list in the TOC.
# Each tuple is (label, href).
CHAPTER_EXTRA_LINKS = {
    "2-tutorials": [
        (
            "Watch the video",
            "wspvideo:introduction",
        ),
        (
            "Watch the video",
            "wspvideo:tutorial-1",
        )
    ]
}


def get_section_files(chapter_dir: str) -> list[tuple[str, str]]:
    """
    Get all section markdown files in a chapter directory, sorted by number.
    
    Returns list of (section_id, filepath) tuples.
    Section ID is the filename without .md extension (e.g., "21-installation").
    """
    sections = []
    full_path = os.path.join(GUIDE_SRC, chapter_dir)
    if not os.path.isdir(full_path):
        print(f"  ⚠️  Chapter directory not found: {chapter_dir}")
        return sections

    for filename in sorted(os.listdir(full_path)):
        if not filename.endswith(".md"):
            continue
        if filename == "00-toc.md" or filename == "index.md":
            continue
        section_id = filename[:-3]  # Remove .md
        filepath = os.path.join(full_path, filename)
        sections.append((section_id, filepath))

    return sections


def md_to_html(md_content: str) -> str:
    """Convert markdown content to HTML using the markdown library."""
    # Use extensions for tables, fenced code, etc.
    html = markdown.markdown(
        md_content,
        extensions=["tables", "fenced_code", "toc"],
    )
    return html


def get_section_title(md_content: str) -> str:
    """Extract the first heading from markdown content."""
    for line in md_content.split("\n"):
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
    return "Untitled"


def clean_internal_links(html: str) -> str:
    """
    Convert relative markdown links to internal anchor links.
    
    Patterns:
    - (../07-publishing/01-export-options.md) → (#91-export-options) — cross-chapter
    - (01-export-options.md) → (#91-export-options) — same chapter
    - (#heading-id) → kept as-is
    """
    # Remove relative paths and .md extensions from links
    # Pattern: href="../XX-chapter/YY-section.md" → href="#YY-section"
    html = re.sub(
        r'href="\.\./[^/]+/([^"]+)\.md"',
        r'href="#\1"',
        html,
    )
    # Pattern: href="YY-section.md" → href="#YY-section"
    html = re.sub(
        r'href="([0-9]{2,3}-[^"]+)\.md"',
        r'href="#\1"',
        html,
    )
    return html


def build_toc(all_sections: dict[str, list[tuple[str, str, str]]]) -> str:
    """
    Build the table of contents HTML.
    
    all_sections: dict of chapter_dir → list of (section_id, title, filepath)
    """
    toc = '<a id="00-toc"></a>\n\n'
    toc += '<h1 id="contents">Contents</h1>\n\n'

    for chapter_dir in CHAPTERS:
        chapter_name = CHAPTER_NAMES.get(chapter_dir, chapter_dir)
        sections = all_sections.get(chapter_dir, [])
        if not sections:
            continue

        toc += f'<h2 id="{chapter_dir}">{chapter_name}</h2>\n'
        toc += "<ul>\n"
        for section_id, title, _ in sections:
            toc += f'<li><a href="#{section_id}">{title}</a></li>\n'
        extra_links = CHAPTER_EXTRA_LINKS.get(chapter_dir, [])
        if extra_links:
            # Blank line before externally curated links to make them stand out.
            toc += "\n"
            for label, href in extra_links:
                toc += f'<li><a href="{href}">{label}</a></li>\n'
        toc += "</ul>\n\n"

    return toc


def build_guide():
    """Build the complete monolithic HTML guide."""
    print("Building Writing Shed Pro Guide from markdown sources...")
    print(f"  Source: {GUIDE_SRC}")
    print(f"  Output: {OUTPUT_PATH}")
    print()

    # Collect all sections with their titles
    all_sections: dict[str, list[tuple[str, str, str]]] = {}
    total_sections = 0

    for chapter_dir in CHAPTERS:
        sections = get_section_files(chapter_dir)
        chapter_sections = []
        for section_id, filepath in sections:
            with open(filepath, "r", encoding="utf-8") as f:
                md_content = f.read()
            title = get_section_title(md_content)
            chapter_sections.append((section_id, title, filepath))
            total_sections += 1
        all_sections[chapter_dir] = chapter_sections
        if chapter_sections:
            print(f"  📁 {chapter_dir}: {len(chapter_sections)} sections")

    print(f"\n  Total: {total_sections} sections\n")

    # Build TOC
    toc_html = build_toc(all_sections)

    # Build section content
    sections_html = ""
    for chapter_dir in CHAPTERS:
        for section_id, title, filepath in all_sections.get(chapter_dir, []):
            with open(filepath, "r", encoding="utf-8") as f:
                md_content = f.read()

            # Convert markdown to HTML
            html_content = md_to_html(md_content)

            # Clean up internal links
            html_content = clean_internal_links(html_content)

            # Strip trailing <hr /> produced by the markdown --- separator
            # so we can insert the back-to-top link before a single <hr>
            html_content = re.sub(r'\s*<hr\s*/?\s*>\s*$', '', html_content)

            # Add section anchor and back-to-top link
            section_block = f'\n<a id="{section_id}"></a>\n\n'
            section_block += html_content
            section_block += '\n\n<p class="back-to-top"><a href="#contents">↑ Back to Contents</a></p>\n'
            section_block += "<hr>\n"

            sections_html += section_block
            print(f"  ✅ {section_id}: {title}")

    # Assemble full HTML
    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Writing Shed Pro Guide</title>
    <style>{CSS}</style>
</head>
<body>
{toc_html}
{sections_html}
</body>
</html>
"""

    # Write output
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        f.write(full_html)

    line_count = full_html.count("\n") + 1
    print(f"\n✅ Generated {OUTPUT_PATH}")
    print(f"   {line_count} lines, {total_sections} sections")
    print(f"\nNext step: run split_guide.py to regenerate individual section files")


if __name__ == "__main__":
    build_guide()
