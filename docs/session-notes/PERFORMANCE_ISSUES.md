# Performance Issues

## File Closing Performance - High Priority

**Date Reported**: 2025-11-06

**Issue**: Beachball appears on Mac when closing a file, indicating UI freeze during save operation.

**Observable Symptoms**:
- Beachball cursor shows when user closes a file
- File opening may also be slow
- Affects macOS (Mac Catalyst) build

**Potential Causes to Investigate**:
1. **CoreData save operations blocking main thread**
   - Large attributed strings being encoded synchronously
   - Image data (1.8MB+) being written on main thread
   - Multiple undo states being persisted at once
   - Version history being saved

2. **AttributedString serialization overhead**
   - `encode(with:)` method may be doing heavy work
   - Image data being copied multiple times
   - Font/color/style encoding happening for entire document

3. **Multiple saves triggered**
   - Console logs showed many encode operations when closing
   - Undo stack might be triggering saves
   - Version system might be creating snapshots

4. **File system operations**
   - Large CoreData database (150MB+)
   - WAL checkpoint operations during save
   - incremental_vacuum running during close

**Suggested Investigation Steps**:
1. Profile with Instruments (Time Profiler)
   - Identify which methods are taking the most time
   - Check if work is happening on main thread
   
2. Check CoreData save strategy
   - Review if saves are synchronous vs asynchronous
   - Consider using background context for saves
   - Check if batching could help

3. Optimize AttributedString encoding
   - Cache encoded image data instead of re-encoding
   - Consider lazy serialization
   - Optimize attachment encoding

4. Review CoreData model
   - Check if relationships are causing cascading saves
   - Consider if undo stack size needs limiting
   - Review version retention policy

**Temporary Workarounds**:
- None currently implemented
- Could show progress indicator during save
- Could defer save to background

**Related Code**:
- `FileEditView.swift` - File close handling
- `AttributedStringSerializer.swift` - Encoding logic
- `DataController.swift` - CoreData save operations
- `ImageAttachment.swift` - Image data storage

**Notes**:
- This became more noticeable after adding image support
- Image data is large (1.8MB in test case)
- Multiple versions of images being saved (undo states)
- CoreData logs show database growing to 150-200MB
