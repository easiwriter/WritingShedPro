# Pagination Feature User Guide

**Feature 010: Paginated Document View**  
**Version:** 1.0  
**Last Updated:** November 19, 2025

---

## Overview

The Pagination feature allows you to preview how your documents will look when printed or exported with page breaks. You can view your work formatted with proper margins, page sizes, and page counts without leaving the editor.

### Key Features

- ✅ Real-time pagination preview
- ✅ Multiple paper sizes (Letter, A4, Legal, etc.)
- ✅ Portrait and landscape orientations
- ✅ Customizable margins
- ✅ Zoom controls (50%-200%)
- ✅ Pinch-to-zoom on touch devices
- ✅ Page navigation
- ✅ Virtual scrolling for large documents
- ✅ Version support (preview any version)

---

## Getting Started

### Prerequisites

Before you can use the pagination feature, you need to configure page setup for your project:

1. Open your project
2. Go to **Project Settings**
3. Navigate to **Page Setup**
4. Configure:
   - Paper size (Letter, A4, Legal, etc.)
   - Orientation (Portrait or Landscape)
   - Margins (Top, Bottom, Left, Right)
   - Optional: Headers and footers

### Accessing Pagination Mode

1. Open any text file in your project
2. Look for the **document stack icon** in the top-right toolbar
3. Tap the icon to switch to Pagination Preview mode
4. Tap again (now filled) to return to Edit mode

**Icon Reference:**
- 📄📄 (outline) = Edit Mode (tap to enter pagination mode)
- 📄📄 (filled) = Pagination Mode (tap to return to edit mode)

---

## Using Pagination Mode

### Navigation

**Scrolling:**
- **iPhone/iPad:** Swipe up/down to scroll through pages
- **Mac:** Use trackpad, mouse wheel, or scroll bars

**Page Indicator:**
- Top-left shows current page: "Page X of Y"
- Updates automatically as you scroll
- Helps you know your position in the document

### Zoom Controls

**Button Controls (All Platforms):**
- **Minus (−):** Zoom out by 25%
- **Plus (+):** Zoom in by 25%
- **Reset (↻):** Return to 100% zoom
- **Percentage Display:** Shows current zoom level

**Pinch-to-Zoom (iOS/iPad):**
- Use two fingers to pinch inward/outward
- Natural, continuous zoom
- Works alongside button controls
- Clamped between 50%-200%

**Zoom Range:**
- Minimum: 50% (half size)
- Maximum: 200% (double size)
- Default: 100% (actual size)
- Increments: 25% per button press

### Version Navigation

**Version Toolbar:**
- The version toolbar remains available in pagination mode
- Navigate between versions to compare layouts
- See how different versions look when paginated
- Useful for comparing edits across drafts

**To Switch Versions:**
1. Use the version navigation arrows (◀ ▶)
2. The pagination updates automatically
3. Page count may change between versions

---

## Understanding Page Layout

### What You See

Each page shows:
- **White Page:** Your actual content area
- **Gray Background:** Paper separation
- **Subtle Shadow:** Depth effect for visual clarity
- **Margins:** Applied from page setup configuration

### Page Spacing

- **Vertical Spacing:** 20pt between pages
- **Horizontal Centering:** Pages centered on screen
- **Realistic View:** Mimics physical paper stack

### Content Flow

- Text flows naturally across pages
- Page breaks occur at boundaries
- No content is cut off mid-line
- Images maintain their positioning

---

## Tips and Best Practices

### Performance

✅ **Large Documents:**
- The system only renders visible pages
- Memory usage stays constant (~9MB)
- Smooth scrolling even with 500+ pages
- No lag or stuttering

✅ **Switching Modes:**
- Mode switching is instant (<50ms)
- All state is preserved
- No layout recalculation needed
- Edit mode remains unchanged

### Editing Workflow

**Recommended Approach:**
1. Write in Edit mode (full features)
2. Switch to Pagination mode to review
3. Check page breaks and layout
4. Return to Edit mode for changes
5. Repeat as needed

**Why Not Edit in Pagination Mode?**
- Pagination is preview-only
- Optimized for reading, not editing
- Edit mode has all formatting tools
- Cleaner separation of concerns

### Accessibility

**VoiceOver Support:**
- All buttons have descriptive labels
- Page count is announced
- Zoom level is announced
- Proper navigation hints

**Dynamic Type:**
- Toolbar text respects system font size
- Scales up to xxxLarge
- Remains readable at all sizes

**Motor Accessibility:**
- Large touch targets for buttons
- Keyboard support on Mac
- Multiple ways to zoom
- No fine motor skills required

---

## Troubleshooting

### "No Page Setup" Message

**Problem:** You see "Configure page setup in project settings to enable pagination view."

**Solution:**
1. Exit the file
2. Go to Project Settings
3. Configure Page Setup (paper size, margins, etc.)
4. Return to your file
5. The pagination mode will now be available

### Toggle Button Not Visible

**Problem:** You don't see the pagination toggle button.

**Causes:**
- Project doesn't have page setup configured
- You're not in a text file
- You're in a different view

**Solution:**
- Configure page setup first
- Open a text file (not folder or project)
- Look in top-right toolbar

### Zoom Not Working

**Problem:** Zoom buttons are disabled or pinch doesn't work.

**Causes:**
- Already at min (50%) or max (200%) zoom
- Pinch gesture not available on Mac
- Buttons disabled when at limits

**Solution:**
- Check current zoom percentage
- Use opposite button (+ if at min, − if at max)
- On Mac, use button controls (pinch not available)
- Reset zoom to return to 100%

### Pages Look Wrong

**Problem:** Layout doesn't match expectations.

**Possible Issues:**
1. **Wrong Paper Size:** Check page setup configuration
2. **Wrong Orientation:** Verify portrait vs landscape
3. **Large Margins:** Check margin settings
4. **Font Size:** Content determines page count
5. **Images:** Large images affect layout

**Solution:**
- Review page setup in project settings
- Adjust margins if too large
- Check paper size matches your needs
- Font size affects how much fits per page

### Slow Performance

**Problem:** Scrolling is laggy or slow.

**Unlikely But Possible:**
- Very old device (pre-2015)
- Extreme document size (10,000+ pages)
- Background tasks consuming resources

**Solution:**
- Close other apps
- Restart the app
- Update to latest version
- Contact support if persists

---

## Keyboard Shortcuts (Mac)

| Action | Shortcut |
|--------|----------|
| Toggle Pagination Mode | ⌘P (if implemented) |
| Zoom In | ⌘+ |
| Zoom Out | ⌘− |
| Reset Zoom | ⌘0 |
| Scroll Page Down | Space |
| Scroll Page Up | Shift+Space |

*Note: Some shortcuts may require implementation in future updates.*

---

## Technical Details

### Memory Usage

- **Empty Document:** ~2MB
- **Small Document (1-10 pages):** ~5MB
- **Medium Document (50 pages):** ~9MB
- **Large Document (500+ pages):** ~9MB ✅ **Constant**

### Performance Metrics

- **Mode Switch:** <50ms
- **Layout Calculation:** 
  - Small docs: <200ms
  - Medium docs (50 pages): <1s
  - Large docs: Background async
- **Scroll Performance:** 60fps
- **Zoom Animation:** 200ms smooth

### Virtual Scrolling

The pagination system uses "virtual scrolling" which means:
- Only visible pages are rendered (5-7 pages)
- Pages above/below are removed from memory
- New pages created as you scroll
- Constant memory usage regardless of size
- No performance degradation with size

---

## FAQ

**Q: Can I edit text in pagination mode?**  
A: No, pagination mode is read-only preview. Switch back to edit mode for changes.

**Q: Does pagination affect my actual file?**  
A: No, it's just a preview. Your file content is unchanged.

**Q: Can I print directly from pagination mode?**  
A: Not in the current version. Export your document for printing.

**Q: Why doesn't my project have pagination?**  
A: You need to configure page setup in project settings first.

**Q: Does zoom affect the actual page size?**  
A: No, zoom only affects the preview display. Actual pages remain at configured size.

**Q: Can I see headers and footers?**  
A: Headers and footers are reserved for future updates. Currently shows content area only.

**Q: Does it work offline?**  
A: Yes, pagination works completely offline. No internet required.

**Q: Can I export paginated PDFs?**  
A: PDF export will be added in a future update.

---

## Future Enhancements

Planned improvements for future releases:

- 🔜 PDF export with pagination
- 🔜 Header and footer display
- 🔜 Page number overlays
- 🔜 Two-page spread view (book style)
- 🔜 Page thumbnails navigation
- 🔜 Custom page breaks
- 🔜 Section-based page numbering
- 🔜 Print preview integration

---

## Support

If you encounter issues not covered in this guide:

1. Check the app's built-in help
2. Visit our support website
3. Contact support@writingshedpro.com
4. Report bugs through the app

---

## Version History

### 1.0 (November 2025)
- Initial release
- Basic pagination preview
- Zoom controls
- Virtual scrolling
- Multi-platform support

---

*This guide covers Writing Shed Pro Feature 010: Pagination v1.0*
