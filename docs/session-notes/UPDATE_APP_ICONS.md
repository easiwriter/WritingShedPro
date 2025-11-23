# Update App Icons Instructions

## Quick Start

1. **Save your icon image** as `app_icon_source.png` in this directory (`/Users/Projects/WritingShedPro/`)

2. **Run the generator script**:
   ```bash
   python3 generate_icons.py
   ```

## What the Script Does

The `generate_icons.py` script will automatically generate all required iOS app icon sizes:

### iPhone Icons
- **20x20** @2x, @3x (40px, 60px) - Notification icons
- **29x29** @1x, @2x, @3x (29px, 58px, 87px) - Settings icons
- **40x40** @2x, @3x (80px, 120px) - Spotlight icons
- **60x60** @2x, @3x (120px, 180px) - App icons

### iPad Icons
- **20x20** @1x, @2x (20px, 40px) - Notification icons
- **29x29** @1x, @2x (29px, 58px) - Settings icons
- **40x40** @1x, @2x (40px, 80px) - Spotlight icons
- **76x76** @1x, @2x (76px, 152px) - App icons
- **83.5x83.5** @2x (167px) - iPad Pro icon

### App Store
- **1024x1024** - App Store icon

## File Mapping

The script generates these files in `Assets.xcassets/AppIcon.appiconset/`:

| Size | Filename |
|------|----------|
| 29×29 | writing shed iPhone Settings.png |
| 58×58 | writing shed settings 2.png |
| 87×87 | writing shed settings 3.png |
| 40×40 | writing shed spotlight.png |
| 80×80 | writing shed spolight 2.png |
| 120×120 | writing shed iphone 2.png |
| 60×60 | writing shed spotlight 3.png |
| 180×180 | writing shed iphone 3.png |
| 76×76 | writing shed iPad.png |
| 152×152 | writing shed ipad 2.png |
| 167×167 | writing shed iPad Pro 2.png |
| 1024×1024 | writing shed 1024.png |
| 29×29 | writing shed iPhone Settings-3.png |
| 58×58 | writing shed settings 2-1.png |

## Manual Alternative (Using Preview on Mac)

If you prefer to generate icons manually:

1. Open your icon image in **Preview**
2. Use **Tools → Adjust Size** to resize to each required dimension
3. Save each size with the corresponding filename above
4. Place all files in: `WrtingShedPro/Writing Shed Pro/Assets.xcassets/AppIcon.appiconset/`

## Requirements

- Python 3 (already installed)
- Pillow library (automatically installed by the script if needed)
- Source icon should ideally be at least 1024×1024 pixels for best quality

## Verification

After running the script, you should see output like:

```
Source image: 1024x1024 pixels
✓ Generated 29x29 -> writing shed iPhone Settings.png
✓ Generated 58x58 -> writing shed settings 2.png
✓ Generated 87x87 -> writing shed settings 3.png
...
✓ All icons generated successfully!
```

Then rebuild your app in Xcode to see the new icons!
