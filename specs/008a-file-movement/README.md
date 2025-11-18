# Feature 008a: File Movement System

**Status**: Ready for Implementation  
**Priority**: High  
**Estimated Effort**: 2.5 weeks (12 days)  
**Dependencies**: None (can start immediately)

## Quick Links

- **[Full Specification](./spec.md)** - Complete feature requirements and user stories
- **[Implementation Plan](./plan.md)** - Detailed 7-phase development plan
- **Parent Feature**: [008-file-movement-system](../008-file-movement-system/) (split into 008a and 008b)

## What This Feature Delivers

Enable users to move text files between source folders (Draft, Ready, Set Aside) with:

✅ **Multi-file selection** via iOS-standard Edit Mode  
✅ **Quick single-file actions** via swipe gestures  
✅ **Smart Trash** with Put Back functionality  
✅ **Automatic restoration** to original folder  
✅ **CloudKit sync** across iOS and macOS devices  

## User Workflows

### Move Files Between Folders
1. Tap **Edit** button
2. Select files (tap to toggle)
3. Tap **Move X items**
4. Choose destination folder

### Quick Move (Single File)
1. Swipe left on file
2. Tap **Move**
3. Choose destination folder

### Delete to Trash
1. Swipe left on file → **Delete**  
   OR  
2. Edit mode → Select files → **Delete**

### Restore from Trash
1. Open **Trash** folder
2. Select trashed file(s)
3. Tap **Put Back** → Returns to original folder

## Technical Summary

**New Models**: TrashItem (tracks original location for restoration)  
**New Services**: FileMoveService (handles all movement logic)  
**New Views**: FileListView, MoveDestinationPicker, TrashView  
**Modified Views**: FolderDetailView (uses new FileListView component)

**Platform Support**:
- iOS: Edit Mode + Swipe Actions
- macOS: Cmd+Click + Right-click context menus

## Implementation Phases

1. **Phase 0**: Research iOS edit mode patterns (1 day)
2. **Phase 1**: Data model & FileMoveService (2 days)
3. **Phase 2**: FileListView with edit mode (2 days)
4. **Phase 3**: MoveDestinationPicker (1 day)
5. **Phase 4**: TrashView & Put Back (1 day)
6. **Phase 5**: Integration & CloudKit testing (1 day)
7. **Phase 6**: Mac Catalyst enhancements (2 days)
8. **Phase 7**: Testing & documentation (2 days)

## Success Criteria

- Move single file in < 3 taps
- Move 10 files in < 10 seconds
- 95%+ Put Back success rate (to original folder)
- CloudKit sync within 5 seconds
- Zero data loss

## Next Steps

1. Read [plan.md](./plan.md) for detailed implementation steps
2. Begin Phase 0: Research iOS edit mode patterns
3. Create research.md documenting findings

## Related Features

- **Next**: [008b-publication-system](../008b-publication-system/) - Publication and submission tracking
- **Depends On**: Features 001 (Projects), 002 (Folders), 003 (Files) - all complete
