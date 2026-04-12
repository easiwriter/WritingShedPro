#!/usr/bin/env python3
"""Prepare HTML files for Apple Help Book: convert guide: links, set unique titles, add meta tags."""
import os, re, glob

help_dir = os.path.join(
    os.path.dirname(__file__),
    "WrtingShedPro", "Writing Shed Pro",
    "WritingShedProHelp.help", "Contents", "Resources", "en.lproj"
)

# First, re-copy fresh files from source
src_dir = os.path.join(
    os.path.dirname(__file__),
    "WrtingShedPro", "Writing Shed Pro", "Resources"
)
import shutil
for path in glob.glob(os.path.join(help_dir, "guide_*.html")):
    os.remove(path)
for path in glob.glob(os.path.join(src_dir, "guide_*.html")):
    shutil.copy2(path, help_dir)

count = 0
for path in glob.glob(os.path.join(help_dir, "guide_*.html")):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Convert guide:XX-section links to guide_XX-section.html
    content = re.sub(r'href="guide:([^"]*)"', r'href="guide_\1.html"', content)

    # Extract the first <h1> text for a unique title
    h1_match = re.search(r'<h1[^>]*>(.+?)</h1>', content)
    if h1_match:
        section_title = re.sub(r'<[^>]+>', '', h1_match.group(1)).strip()
        page_title = f"{section_title} — Writing Shed Pro Help"
    else:
        page_title = "Writing Shed Pro Help"

    # Replace the generic <title> with a unique one
    content = re.sub(
        r'<title>Writing Shed Pro Guide</title>',
        f'<title>{page_title}</title>',
        content
    )

    # Extract first paragraph for description meta tag
    p_match = re.search(r'<p>(.+?)</p>', content, re.DOTALL)
    desc = ""
    if p_match:
        desc = re.sub(r'<[^>]+>', '', p_match.group(1)).strip()[:200]

    # Add Apple Help meta tags after <title> if not already present
    if 'name="AppleTitle"' not in content:
        meta_tags = '    <meta name="AppleTitle" content="Writing Shed Pro Help"/>'
        if desc:
            meta_tags += f'\n    <meta name="description" content="{desc}"/>'
        content = content.replace(
            f"<title>{page_title}</title>",
            f"<title>{page_title}</title>\n{meta_tags}"
        )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    count += 1

print(f"Processed {count} files")
