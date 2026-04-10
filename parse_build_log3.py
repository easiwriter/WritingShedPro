#!/usr/bin/env python3
import gzip, re

logpath = "/Users/writingshedprod/Library/Developer/Xcode/DerivedData/Writing_Shed_Pro-hktbzjdrkdegnkcbqqodjidfyxgr/Logs/Build/6515CA2F-17AB-457B-BB30-F4985A732CEE.xcactivitylog"

with gzip.open(logpath, 'rb') as f:
    data = f.read().decode('utf-8', errors='replace')

# Find all task metrics
# The format has sections like:
# "Compiling X.swift, Y.swift" ... "TaskMetrics" ... {"wcDuration":NNN}
# Let's find each TaskMetrics and go back further to find the Compiling line

metrics_iter = list(re.finditer(r'wcDuration.?:(\d+)', data))
print(f"Found {len(metrics_iter)} duration entries\n")

results = []
for m in metrics_iter:
    dur = int(m.group(1))
    if dur < 10_000_000:  # Skip short ones (< 10s)
        continue
    
    # Get a larger context window before this match
    start = max(0, m.start() - 5000)
    before = data[start:m.start()]
    
    # Find Compiling patterns
    compile_match = re.findall(r'Compiling ([^"]+?)(?:\s*\(in target|$)', before)
    if compile_match:
        last_compile = compile_match[-1]
        files = [f.strip().replace('\\', '') for f in last_compile.split(',')]
        results.append((dur, files))
    else:
        # Try finding "Compile X.swift" pattern
        compile_single = re.findall(r'Compile (\S+\.swift)', before)
        if compile_single:
            results.append((dur, compile_single[-5:]))
        else:
            # Try decoding hex
            hex_chunks = re.findall(r'([0-9a-fA-F]{40,})', before)
            decoded_files = []
            for hc in hex_chunks:
                try:
                    decoded = bytes.fromhex(hc).decode('utf-8', errors='ignore')
                    df = re.findall(r'(\w+\.swift)', decoded)
                    decoded_files.extend(df)
                except:
                    pass
            if decoded_files:
                results.append((dur, list(dict.fromkeys(decoded_files))))
            else:
                # Just get any .swift references
                swift_refs = re.findall(r'(\w+\.swift)', before[-500:])
                results.append((dur, list(dict.fromkeys(swift_refs)) if swift_refs else ['(unknown)']))

results.sort(key=lambda x: x[0], reverse=True)

print("Top 15 slowest steps:")
print("=" * 60)
for dur, files in results[:15]:
    dur_s = dur / 1_000_000
    print(f"\nDuration: {dur_s:.1f}s")
    for f in files[:15]:
        print(f"  - {f}")
    if len(files) > 15:
        print(f"  ... and {len(files)-15} more")
