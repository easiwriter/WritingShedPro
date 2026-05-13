#!/usr/bin/env python3
"""
Create an A5 PDF flyer for Writing Shed Pro
"""

from reportlab.lib.pagesizes import A5
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, white, black
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.enums import TA_CENTER, TA_LEFT
import os

# A5 dimensions: 148mm x 210mm
WIDTH, HEIGHT = A5

# Color palette - warm, inviting colors for writers
DEEP_PURPLE = HexColor('#4A154B')       # Header background
WARM_ORANGE = HexColor('#FF6B35')       # Accent color
SOFT_TEAL = HexColor('#2EC4B6')         # Secondary accent
LIGHT_CREAM = HexColor('#FFF8F0')       # Background
DARK_GRAY = HexColor('#333333')         # Body text
WARM_GOLD = HexColor('#FFB347')         # Highlights
SOFT_PURPLE = HexColor('#7B4B8A')       # Section headers

def draw_rounded_rect(c, x, y, width, height, radius, fill_color=None, stroke_color=None, stroke_width=1):
    """Draw a rounded rectangle"""
    c.saveState()
    if fill_color:
        c.setFillColor(fill_color)
    if stroke_color:
        c.setStrokeColor(stroke_color)
        c.setLineWidth(stroke_width)
    
    path = c.beginPath()
    path.moveTo(x + radius, y)
    path.lineTo(x + width - radius, y)
    path.arcTo(x + width - radius, y, x + width, y + radius, 90)
    path.lineTo(x + width, y + height - radius)
    path.arcTo(x + width - radius, y + height - radius, x + width, y + height, 0)
    path.lineTo(x + radius, y + height)
    path.arcTo(x, y + height - radius, x + radius, y + height, -90)
    path.lineTo(x, y + radius)
    path.arcTo(x, y, x + radius, y + radius, 180)
    path.close()
    
    if fill_color and stroke_color:
        c.drawPath(path, fill=1, stroke=1)
    elif fill_color:
        c.drawPath(path, fill=1, stroke=0)
    else:
        c.drawPath(path, fill=0, stroke=1)
    c.restoreState()

def draw_feature_icon(c, x, y, icon_type):
    """Draw a simple icon shape"""
    c.saveState()
    c.setFillColor(WARM_ORANGE)
    
    if icon_type == "pen":
        # Stylized pen
        c.setLineWidth(2)
        c.setStrokeColor(WARM_ORANGE)
        c.line(x, y, x + 8, y + 12)
        c.circle(x + 9, y + 13, 2, fill=1)
    elif icon_type == "cloud":
        # Cloud shape
        c.circle(x + 4, y + 4, 4, fill=1)
        c.circle(x + 10, y + 4, 5, fill=1)
        c.circle(x + 7, y + 8, 4, fill=1)
    elif icon_type == "book":
        # Book shape
        c.rect(x, y, 12, 14, fill=1)
        c.setFillColor(white)
        c.rect(x + 2, y + 2, 8, 10, fill=1)
    elif icon_type == "star":
        # Simple star
        from math import cos, sin, pi
        points = []
        for i in range(5):
            angle = i * 2 * pi / 5 - pi / 2
            points.append((x + 7 + 7 * cos(angle), y + 7 + 7 * sin(angle)))
            angle += pi / 5
            points.append((x + 7 + 3 * cos(angle), y + 7 + 3 * sin(angle)))
        path = c.beginPath()
        path.moveTo(*points[0])
        for p in points[1:]:
            path.lineTo(*p)
        path.close()
        c.drawPath(path, fill=1)
    
    c.restoreState()

def create_flyer():
    output_path = os.path.join(os.path.dirname(__file__), "WritingShedPro_Flyer.pdf")
    c = canvas.Canvas(output_path, pagesize=A5)
    
    # Background gradient effect (simulated with rectangles)
    c.setFillColor(LIGHT_CREAM)
    c.rect(0, 0, WIDTH, HEIGHT, fill=1, stroke=0)
    
    # Decorative top bar
    c.setFillColor(DEEP_PURPLE)
    c.rect(0, HEIGHT - 55*mm, WIDTH, 55*mm, fill=1, stroke=0)
    
    # Decorative wave/curve at bottom of header
    c.saveState()
    path = c.beginPath()
    path.moveTo(0, HEIGHT - 55*mm)
    path.curveTo(WIDTH/3, HEIGHT - 50*mm, 2*WIDTH/3, HEIGHT - 60*mm, WIDTH, HEIGHT - 55*mm)
    path.lineTo(WIDTH, HEIGHT - 60*mm)
    path.curveTo(2*WIDTH/3, HEIGHT - 65*mm, WIDTH/3, HEIGHT - 55*mm, 0, HEIGHT - 60*mm)
    path.close()
    c.setFillColor(SOFT_TEAL)
    c.drawPath(path, fill=1, stroke=0)
    c.restoreState()
    
    # App Title
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 28)
    c.drawCentredString(WIDTH/2, HEIGHT - 22*mm, "Writing Shed Pro")
    
    # Tagline
    c.setFont("Helvetica-Oblique", 12)
    c.setFillColor(WARM_GOLD)
    c.drawCentredString(WIDTH/2, HEIGHT - 30*mm, "Your Complete Creative Writing Studio")
    
    # Platform badges
    c.setFont("Helvetica", 9)
    badge_y = HEIGHT - 42*mm
    platforms = ["iPhone", "iPad", "Mac"]
    badge_width = 28*mm
    start_x = (WIDTH - (len(platforms) * badge_width + (len(platforms)-1) * 3*mm)) / 2
    
    for i, platform in enumerate(platforms):
        x = start_x + i * (badge_width + 3*mm)
        draw_rounded_rect(c, x, badge_y - 4*mm, badge_width, 8*mm, 3*mm, 
                         fill_color=WARM_GOLD)
        c.setFillColor(DEEP_PURPLE)
        c.setFont("Helvetica-Bold", 9)
        c.drawCentredString(x + badge_width/2, badge_y - 1*mm, platform)
    
    # Main content area - starting position
    content_y = HEIGHT - 72*mm
    margin = 10*mm
    
    # "Write Your Way" section
    c.setFillColor(SOFT_PURPLE)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(margin, content_y, "✦ Write Your Way")
    
    content_y -= 6*mm
    c.setFillColor(DARK_GRAY)
    c.setFont("Helvetica", 9)
    
    writing_types = [
        ("📝 Prose", "Essays, articles, journals"),
        ("📜 Poetry", "Syllable counting, rhymes, common forms"),
        ("📖 Fiction", "Novels, short fiction, plot outlines"),
        ("🎭 Drama", "Stage plays, screenplays, DML"),
    ]
    
    for wtype, desc in writing_types:
        c.setFont("Helvetica-Bold", 9)
        c.setFillColor(DEEP_PURPLE)
        c.drawString(margin + 3*mm, content_y, wtype)
        c.setFont("Helvetica", 8)
        c.setFillColor(DARK_GRAY)
        c.drawString(margin + 28*mm, content_y, desc)
        content_y -= 5*mm
    
    content_y -= 5*mm
    
    # Feature boxes - two columns
    box_width = (WIDTH - 3*margin) / 2
    box_height = 28*mm
    
    features = [
        ("Professional Tools", [
            "Rich text editor",
            "Style sheet manager",
            "Footnotes & comments",
            "Search & replace"
        ], SOFT_TEAL),
        ("Seamless Sync", [
            "iCloud across devices",
            "Automatic backup",
            "Work anywhere",
            "Never lose a word"
        ], WARM_ORANGE),
        ("Poetry Magic", [
            "Syllable counting",
            "Rhyme suggestions",
            "Stress patterns",
            "Form templates"
        ], SOFT_PURPLE),
        ("Publish Ready", [
            "Export to PDF",
            "Export to EPUB",
            "Professional layouts",
            "Submission tracking",
            "Print directly"
        ], DEEP_PURPLE),
    ]
    
    for i, (title, items, color) in enumerate(features):
        col = i % 2
        row = i // 2
        
        x = margin + col * (box_width + margin)
        y = content_y - row * (box_height + 3*mm)
        
        # Feature box
        draw_rounded_rect(c, x, y - box_height, box_width, box_height, 3*mm,
                         fill_color=HexColor('#FFFFFF'))
        
        # Colored left accent bar
        c.setFillColor(color)
        c.rect(x, y - box_height, 3*mm, box_height, fill=1, stroke=0)
        
        # Title
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 9)
        c.drawString(x + 5*mm, y - 5*mm, title)
        
        # Items
        c.setFillColor(DARK_GRAY)
        c.setFont("Helvetica", 7)
        for j, item in enumerate(items):
            c.drawString(x + 5*mm, y - 10*mm - j * 4*mm, f"• {item}")
    
    # Bottom section
    bottom_y = 25*mm
    
    # Decorative bottom bar
    c.setFillColor(DEEP_PURPLE)
    c.rect(0, 0, WIDTH, 18*mm, fill=1, stroke=0)
    
    # Call to action box
    cta_width = WIDTH - 2*margin
    cta_height = 18*mm
    cta_y = 20*mm
    
    draw_rounded_rect(c, margin, cta_y, cta_width, cta_height, 4*mm,
                     fill_color=WARM_ORANGE)
    
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 13)
    cta_label = "Available Now on the App Store"
    cta_prefix = "Available Now on the "
    cta_link_word = "App Store"
    cta_text_width = c.stringWidth(cta_label, "Helvetica-Bold", 13)
    cta_text_x = WIDTH/2 - cta_text_width / 2
    cta_text_y = cta_y + 7*mm
    # Draw prefix in white
    c.drawString(cta_text_x, cta_text_y, cta_prefix)
    # Draw "App Store" in blue
    prefix_width = c.stringWidth(cta_prefix, "Helvetica-Bold", 13)
    link_word_width = c.stringWidth(cta_link_word, "Helvetica-Bold", 13)
    c.setFillColor(HexColor('#ADD8E6'))
    c.drawString(cta_text_x + prefix_width, cta_text_y, cta_link_word)
    c.linkURL("https://apps.apple.com/gb/app/writing-shed-pro/id6747890719",
              (cta_text_x, cta_text_y - 1*mm, cta_text_x + cta_text_width, cta_text_y + 5*mm),
              relative=0)
    
    # Footer
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 11)
    c.drawCentredString(WIDTH/2, 6*mm, "writingshedpro.com")
    
    c.save()
    print(f"✅ Flyer created successfully: {output_path}")
    return output_path

if __name__ == "__main__":
    create_flyer()
