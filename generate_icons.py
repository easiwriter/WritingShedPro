#!/usr/bin/env python3
"""
Generate all required app icon sizes from a source image.
"""
from PIL import Image
import os
import sys

# Icon sizes needed based on Contents.json
ICON_SIZES = [
    # iPhone
    ("40x40", "writing shed spotlight 2.png"),      # iPhone 20x20 @2x = 40x40
    ("60x60", "writing shed spotlight 3.png"),      # iPhone 20x20 @3x = 60x60
    ("29x29", "writing shed iPhone Settings.png"),  # iPhone 29x29 @1x = 29x29
    ("58x58", "writing shed settings 2.png"),       # iPhone 29x29 @2x = 58x58
    ("87x87", "writing shed settings 3.png"),       # iPhone 29x29 @3x = 87x87
    ("80x80", "writing shed spotlight 2.png"),      # iPhone 40x40 @2x = 80x80 (duplicate name, will use first)
    ("120x120", "writing shed spotlight 3.png"),    # iPhone 40x40 @3x = 120x120 (duplicate, will use first)
    ("120x120", "writing shed iphone 2.png"),       # iPhone 60x60 @2x = 120x120
    ("180x180", "writing shed iphone 3.png"),       # iPhone 60x60 @3x = 180x180
    
    # iPad
    ("20x20", None),                                 # iPad 20x20 @1x (not in use)
    ("40x40", None),                                 # iPad 20x20 @2x (not in use)
    ("29x29", "writing shed iPhone Settings-3.png"), # iPad 29x29 @1x = 29x29
    ("58x58", "writing shed settings 2-1.png"),      # iPad 29x29 @2x = 58x58
    ("40x40", "writing shed spotlight.png"),         # iPad 40x40 @1x = 40x40
    ("80x80", "writing shed spolight 2.png"),        # iPad 40x40 @2x = 80x80
    ("76x76", "writing shed iPad.png"),              # iPad 76x76 @1x = 76x76
    ("152x152", "writing shed ipad 2.png"),          # iPad 76x76 @2x = 152x152
    ("167x167", "writing shed iPad Pro 2.png"),      # iPad Pro 83.5x83.5 @2x = 167x167
    
    # App Store
    ("1024x1024", "writing shed 1024.png"),          # iOS Marketing 1024x1024 @1x
]

# Unique sizes we need to generate (removing duplicates)
UNIQUE_SIZES = {
    20: None,
    29: "writing shed iPhone Settings.png",
    40: "writing shed spotlight.png",
    58: "writing shed settings 2.png",
    60: "writing shed spotlight 3.png",
    76: "writing shed iPad.png",
    80: "writing shed spolight 2.png",
    87: "writing shed settings 3.png",
    120: "writing shed iphone 2.png",
    152: "writing shed ipad 2.png",
    167: "writing shed iPad Pro 2.png",
    180: "writing shed iphone 3.png",
    1024: "writing shed 1024.png",
}

def generate_icons(source_image_path, output_dir, scale_factor=1.2):
    """Generate all required icon sizes from source image.
    
    Args:
        source_image_path: Path to source image
        output_dir: Directory to save generated icons
        scale_factor: How much to scale up the content (default 1.2 = 20% bigger)
    """
    
    # Open the source image
    try:
        img = Image.open(source_image_path)
        print(f"Source image: {img.size[0]}x{img.size[1]} pixels")
        print(f"Scale factor: {scale_factor}x (content will be {int((scale_factor-1)*100)}% bigger)")
    except Exception as e:
        print(f"Error opening source image: {e}")
        return False
    
    # Convert to RGBA if necessary
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Generate each size
    for size, filename in UNIQUE_SIZES.items():
        if filename is None:
            continue
            
        try:
            # Calculate scaled content size
            content_size = int(size * scale_factor)
            
            # Resize the content larger with high-quality resampling
            scaled_content = img.resize((content_size, content_size), Image.Resampling.LANCZOS)
            
            # Create a new transparent canvas at the target size
            final_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            
            # Calculate position to center the scaled content
            paste_x = (size - content_size) // 2
            paste_y = (size - content_size) // 2
            
            # Crop the scaled content to fit within the final size
            if content_size > size:
                # Content is bigger than canvas, crop from center
                crop_margin = (content_size - size) // 2
                scaled_content = scaled_content.crop((
                    crop_margin,
                    crop_margin,
                    crop_margin + size,
                    crop_margin + size
                ))
                paste_x = 0
                paste_y = 0
            
            # Paste the content onto the canvas
            final_image.paste(scaled_content, (paste_x, paste_y), scaled_content)
            
            # Save as PNG
            output_path = os.path.join(output_dir, filename)
            final_image.save(output_path, 'PNG', optimize=True)
            print(f"✓ Generated {size}x{size} -> {filename}")
            
        except Exception as e:
            print(f"✗ Error generating {size}x{size}: {e}")
            return False
    
    return True

if __name__ == "__main__":
    source = "app_icon_source.png"  # The uploaded image
    output = "WrtingShedPro/Writing Shed Pro/Assets.xcassets/AppIcon.appiconset"
    
    if not os.path.exists(source):
        print(f"Error: Source image '{source}' not found")
        sys.exit(1)
    
    if not os.path.exists(output):
        print(f"Error: Output directory '{output}' not found")
        sys.exit(1)
    
    print(f"Generating app icons from {source}...")
    if generate_icons(source, output):
        print("\n✓ All icons generated successfully!")
    else:
        print("\n✗ Failed to generate some icons")
        sys.exit(1)
