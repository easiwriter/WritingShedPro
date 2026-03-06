#!/usr/bin/env python3
"""Analyze a WSP file for corruption."""
import json, sys

with open('/Users/writingshedprod/Desktop/The Republic of Heaven.wsp', 'r') as f:
    data = json.load(f)

print('Top-level keys:', list(data.keys()))
print()
print('Project name:', data.get('projectName'))
print('Project type:', data.get('projectType'))
print()

# Folders
folders = data.get('folders', [])
print(f'Folders: {len(folders)}')
all_file_ids = set()
for fld in folders:
    files = fld.get('textFiles', [])
    subs = fld.get('subfolders', [])
    name = fld.get('name', 'NO NAME')
    fid = fld['id'][:8]
    print(f'  - "{name}" (id={fid}...) files={len(files)} subfolders={len(subs)}')
    for tf in files:
        all_file_ids.add(tf.get('id', ''))
        print(f'      file: "{tf.get("name", "NO NAME")}" id={tf.get("id","?")[:8]}...')
    for sf in subs:
        sf_files = sf.get('textFiles', [])
        sf_subs = sf.get('subfolders', [])
        sf_name = sf.get('name', 'NO NAME')
        print(f'    - "{sf_name}" (id={sf["id"][:8]}...) files={len(sf_files)} subfolders={len(sf_subs)}')
        for tf in sf_files:
            all_file_ids.add(tf.get('id', ''))

print()
print(f'Total unique file IDs across folders: {len(all_file_ids)}')

# Poetry collections
collections = data.get('poetryCollections', [])
print(f'\nPoetry collections: {len(collections)}')
for c in collections:
    links = c.get('fileLinks', [])
    name = c.get('name', 'NO NAME')
    cid = c['id'][:8]
    print(f'  - name="{name}" id={cid}... fileLinks={len(links)}')
    for link in links:
        lid = link.get('id', '?')[:8]
        tfid = link.get('textFileID', 'MISSING')
        print(f'      link id={lid}... textFileID={tfid[:8] if tfid != "MISSING" else "MISSING"}...')
    # Check for empty/null name
    if not name or name == 'NO NAME':
        print(f'    *** PROBLEM: Collection has no name! Full data: {json.dumps(c, indent=2)[:500]}')

# Check for broken links
print('\n--- Checking for broken references ---')
for c in collections:
    for link in c.get('fileLinks', []):
        tfid = link.get('textFileID', '')
        if tfid and tfid not in all_file_ids:
            print(f'  BROKEN LINK: collection "{c.get("name","")}": textFileID {tfid[:8]}... not found in any folder')

# Other container types
for key in ['books', 'chapters', 'acts', 'proseSections']:
    items = data.get(key, [])
    if items:
        print(f'\n{key}: {len(items)}')
        for item in items:
            name = item.get('name', 'NO NAME')
            iid = item.get('id', '?')[:8]
            links = item.get('fileLinks', item.get('sceneLinks', []))
            print(f'  - name="{name}" id={iid}... links={len(links)}')
            if not name or name == 'NO NAME':
                print(f'    *** PROBLEM: {key} item has no name! Full: {json.dumps(item, indent=2)[:500]}')
