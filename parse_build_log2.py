#!/usr/bin/env python3
import gzip, re

logpath = "/Users/writingshedprod/Library/Developer/Xcode/DerivedData/Writing_Shed_Pro-hktbzjdrkdegnkcbqqodjidfyxgr/Logs/Build/6515CA2F-17AB-457B-BB30-F4985A732CEE.xcactivitylog"

with gzip.open(logpath, 'rb') as f:
    data = f.read().decode('utf-8', errors='replace')

# Find all task metrics with their context
parts = data.split('TaskMetrics')
print(f"Found {len(parts)-1} TaskMetrics entries\n")

results = []
for i, part in enumerate(parts[1:], 1):
    m = re.search(r'wcDuration.?:(\d+)', part[:300])
    if m:
        dur = int(m.group(1))
        before = parts[i-1][-2000:]
        # Try to find readable file references
        swift_files = re.findall(r'([A-Za-z]\w+\.swift)', before)
        # Unique, preserve order
        seen = set()
        unique_files = []
        for f in swift_files:
            if f not in seen:
                seen.add(f)
                unique_files.append(f)
        
        # Also try to decode hex-encoded content
        hex_matches = re.findall(r'([0-9a-fA-F]{20,})', before)
        decoded_files = []
        for hm in hex_matches:
            try:
                decoded = bytes.fromhex(hm).decode('utf-8', errors='replace')
                df = re.findall(r'([A-Za-z]\w+\.swift)', decoded)
                for f in df:
                    if f not in seen:
                        seen.add(f)
                        decoded_files.append(f)
            except:
                pass
        
        results.append((dur, unique_files, decoded_files))

# Sort by duration descending
results.sort(key=lambda x: x[0], reverse=True)

print("Top 15 slowest compilation batches:")
print("=" * 60)
for dur, files, decoded_files in results[:15]:
    dur_s = dur / 1_000_000
    print(f"\nDuration: {dur_s:.1f}s")
    all_files = files + decoded_files
    if all_files:
        for f in all_files[:10]:
            print(f"  - {f}")
        if len(all_files) > 10:
            print(f"  ... and {len(all_files)-10} more")
    else:
        print("  (no files found)")
