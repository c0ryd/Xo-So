#!/bin/bash
# Flutter run script to avoid directory issues

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Change to the Flutter project root
cd "$SCRIPT_DIR"

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    echo "Error: pubspec.yaml not found. Make sure you're in the Flutter project root."
    exit 1
fi

# Run Flutter with the device ID
flutter run -d 00008120-0016696E0240C01E
