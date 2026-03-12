#!/usr/bin/env python3
"""Analyze a .wsp export file for sync/relationship issues."""
import json
import sys

WSP_PATH = "/Users/writingshedprod/Desktop/Crossborder Poets.wsp"

with open(WSP_PATH, "r") as f:
    data = json.load(f)

# === PROJECT ===
proj = data["project"]
print("=== PROJECT ===")
for k, v in proj.items():
    if isinstance(v, (str, int, float, bool, type(None))):
        print(f"  {k}: {repr(v)[:120]}")
    elif isinstance(v, list):
        print(f"  {k}: list with {len(v)} items")
    elif isinstance(v, dict):
        print(f"  {k}: dict with keys {list(v.keys())[:10]}")

# === FOLDERS ===
print("\n=== FOLDERS (9) ===")
all_folder_ids = set()
all_file_ids = set()
files_by_folder = {}
for folder in data["folders"]:
    fid = folder["id"]
    all_folder_ids.add(fid)
    parent = folder.get("parentId", None)
    tfs = folder.get("textFiles", [])
    sfs = folder.get("subfolders", [])
    tf_count = len(tfs)
    sf_count = len(sfs)
    print(f"  {folder['name']} id={fid[:8]}... parentId={str(parent)[:12] if parent else 'ROOT'} "
          f"textFiles={tf_count} subfolders={sf_count} order={folder.get('userOrder')}")
    for tf in tfs:
        all_file_ids.add(tf["id"])
        files_by_folder[tf["id"]] = fid
        pcids = tf.get("poetryCollectionIds", [])
        sids = tf.get("sectionIds", [])
        print(f"    -> file: {tf['name']} id={tf['id'][:8]}... "
              f"poetryCollectionIds={pcids} sectionIds={sids} "
              f"versions={len(tf.get('versions', []))}")
    for sf in sfs:
        all_folder_ids.add(sf["id"])
        for tf in sf.get("textFiles", []):
            all_file_ids.add(tf["id"])
            files_by_folder[tf["id"]] = sf["id"]
            pcids = tf.get("poetryCollectionIds", [])
            sids = tf.get("sectionIds", [])
            print(f"    -> subfolder/{sf['name']}/file: {tf['name']} id={tf['id'][:8]}... "
                  f"poetryCollectionIds={pcids} sectionIds={sids} "
                  f"versions={len(tf.get('versions', []))}")

# === POETRY COLLECTIONS ===
print("\n=== POETRY COLLECTIONS ===")
for pc in data["poetryCollections"]:
    print(f"  name={pc.get('name')} id={pc.get('id', '')[:8]}...")
    print(f"  keys: {list(pc.keys())}")
    poemIds = pc.get("poemIds", [])
    print(f"  poemIds ({len(poemIds)}): {poemIds}")
    # Check if poemIds reference valid files
    for pid in poemIds:
        if pid not in all_file_ids:
            print(f"    *** ORPHAN: poemId {pid[:8]}... NOT found in any folder!")
        else:
            print(f"    OK: poemId {pid[:8]}... found in folder")

# === CROSS-REFERENCE CHECK ===
print("\n=== CROSS-REFERENCE / JOIN TABLE ANALYSIS ===")

# Check: files that reference poetryCollectionIds
print("\nFiles referencing poetryCollections:")
collection_ids = {pc["id"] for pc in data["poetryCollections"]}
files_with_pcids = []

def check_files_in_folder(folder, depth=0):
    for tf in folder.get("textFiles", []):
        pcids = tf.get("poetryCollectionIds", [])
        if pcids:
            files_with_pcids.append((tf["name"], tf["id"], pcids))
            for pcid in pcids:
                status = "OK" if pcid in collection_ids else "*** BROKEN - collection not found!"
                print(f"  {'  '*depth}file '{tf['name']}' -> collection {pcid[:8]}... {status}")
    for sf in folder.get("subfolders", []):
        check_files_in_folder(sf, depth+1)

for folder in data["folders"]:
    check_files_in_folder(folder)

if not files_with_pcids:
    print("  (none)")

# Check: files that reference sectionIds  
print("\nFiles referencing proseSections:")
section_ids_in_export = {s["id"] for s in data.get("proseSections", [])}
files_with_sids = []

def check_section_refs(folder, depth=0):
    for tf in folder.get("textFiles", []):
        sids = tf.get("sectionIds", [])
        if sids:
            files_with_sids.append((tf["name"], tf["id"], sids))
            for sid in sids:
                status = "OK" if sid in section_ids_in_export else "*** BROKEN - section not found!"
                print(f"  {'  '*depth}file '{tf['name']}' -> section {sid[:8]}... {status}")
    for sf in folder.get("subfolders", []):
        check_section_refs(sf, depth+1)

for folder in data["folders"]:
    check_section_refs(folder)

if not files_with_sids:
    print("  (none)")

# === SUMMARY STATS ===
print("\n=== SUMMARY ===")
print(f"Total top-level folders: {len(data['folders'])}")
print(f"Total unique folder IDs (incl. subfolders): {len(all_folder_ids)}")
print(f"Total unique file IDs: {len(all_file_ids)}")
print(f"Poetry collections: {len(data['poetryCollections'])}")
print(f"Prose sections: {len(data['proseSections'])}")
print(f"Scenes: {len(data['scenes'])}")
print(f"Characters: {len(data['characters'])}")
print(f"Submissions: {len(data['submissions'])}")

# Check for any data oddities
print("\n=== POTENTIAL ISSUES ===")

# Check stylesheet
ss = data.get("stylesheet", {})
if ss:
    print(f"Stylesheet: name='{ss.get('name')}' id={ss.get('id','')[:8]}... "
          f"textStyles={len(ss.get('textStyles', []))} imageStyles={len(ss.get('imageStyles', []))}")

# Look for very large base64 fields that might cause CloudKit record size limits
print("\nChecking for large records (CloudKit has 1MB record limit)...")
def estimate_size(obj):
    return len(json.dumps(obj))

for folder in data["folders"]:
    def check_file_sizes(folder, path=""):
        for tf in folder.get("textFiles", []):
            size = estimate_size(tf)
            if size > 500000:  # 500KB
                print(f"  *** LARGE FILE: {path}/{tf['name']} ~{size//1024}KB")
            for v in tf.get("versions", []):
                vsize = len(v.get("formattedContentBase64", "")) + len(v.get("content", ""))
                if vsize > 500000:
                    print(f"  *** LARGE VERSION in {path}/{tf['name']}: ~{vsize//1024}KB")
        for sf in folder.get("subfolders", []):
            check_file_sizes(sf, f"{path}/{sf['name']}")
    check_file_sizes(folder, folder["name"])
