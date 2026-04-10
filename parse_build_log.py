#!/usr/bin/env python3
import gzip, re, sys

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
        before = parts[i-1][-1000:]
        # Extract file names from "Compiling X.swift, Y.swift" patterns
        files = re.findall(r'Compiling\\ (\S+\.swift)', before)
        if not files:
            files = re.findall(r'Compiling (\S+\.swift)', before)
        if not files:
            files = re.findall(r'Compile (\S+\.swift)', before)
        results.append((dur, files, before[-200:]))

# Sort by duration descending
results.sort(key=lambda x: x[0], reverse=True)

print("Top 10 slowest compilation batches:")
print("=" * 60)
for dur, files, ctx in results[:10]:
    dur_s = dur / 1_000_000  # Convert to seconds (values are in microseconds? or ns?)
    # Try both interpretations
    print(f"\nDuration: {dur:,} (~{dur/1_000_000:.1f}s if µs, ~{dur/1_000_000_000:.1f}s if ns)")
    if files:
        for f in files:
            print(f"  - {f}")
    else:
        print(f"  Context: {ctx[:150]}")
