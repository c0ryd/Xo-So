#!/usr/bin/env python3
"""
Fix app icon white border by ensuring no transparency at edges
"""
from PIL import Image, ImageDraw
import os

def fix_app_icon():
    # Load the current icon
    icon_path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
    
    if not os.path.exists(icon_path):
        print(f"Icon not found at {icon_path}")
        return
        
    # Open the original icon
    icon = Image.open(icon_path)
    print(f"Original icon size: {icon.size}")
    print(f"Original icon mode: {icon.mode}")
    
    # Create a new image with solid background
    # Use the red gradient color from your icon (approximate)
    background_color = (196, 67, 43)  # Reddish-brown color from your icon
    
    # Create new image with solid background
    fixed_icon = Image.new('RGB', (1024, 1024), background_color)
    
    # If original has transparency, paste it on the background
    if icon.mode in ('RGBA', 'LA'):
        # Create a mask from the alpha channel
        if icon.mode == 'RGBA':
            r, g, b, a = icon.split()
            # Create a gradient background that matches your icon's style
            gradient = Image.new('RGB', (1024, 1024))
            draw = ImageDraw.Draw(gradient)
            
            # Create a red to darker red gradient (matching your design)
            for y in range(1024):
                red_intensity = int(220 - (y / 1024) * 50)  # From 220 to 170
                color = (red_intensity, 67, 43)
                draw.line([(0, y), (1023, y)], fill=color)
            
            # Paste the icon on the gradient background
            fixed_icon = gradient
            fixed_icon.paste(icon, (0, 0), a)  # Use alpha as mask
        else:
            fixed_icon.paste(icon, (0, 0))
    else:
        # No transparency, just copy
        fixed_icon = icon.convert('RGB')
    
    # Save the fixed icon
    fixed_icon.save(icon_path, 'PNG', quality=100)
    print(f"Fixed icon saved to {icon_path}")
    
    return fixed_icon

if __name__ == "__main__":
    fix_app_icon()
