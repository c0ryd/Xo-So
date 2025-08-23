#!/usr/bin/env python3
"""
Quick script to extract device token from Flutter app logs.
Run this after your Flutter app has started to extract the device token.
"""

import re
import subprocess
import sys

def find_device_token_in_logs():
    """
    Look for device token in recent Flutter logs.
    """
    
    print("🔍 Searching for device tokens in Flutter logs...")
    
    try:
        # Run flutter logs command to get recent output
        result = subprocess.run(['flutter', 'logs'], 
                              capture_output=True, 
                              text=True, 
                              timeout=5)
        
        logs = result.stdout
        
        # Look for the full device token pattern
        patterns = [
            r'🔍 FULL DEVICE TOKEN: ([a-fA-F0-9]{64})',
            r'APNs registration successful! Token: ([a-fA-F0-9]{64})',
            r'device token from iOS: ([a-fA-F0-9]{64})',
            r'Real iOS APNs token received: ([a-fA-F0-9]{64})'
        ]
        
        found_tokens = []
        
        for pattern in patterns:
            matches = re.findall(pattern, logs)
            for match in matches:
                if match not in found_tokens:
                    found_tokens.append(match)
        
        if found_tokens:
            print(f"✅ Found {len(found_tokens)} device token(s):")
            for i, token in enumerate(found_tokens, 1):
                print(f"   {i}. {token}")
                print(f"      Length: {len(token)} characters")
            
            return found_tokens[0]  # Return the first one
        else:
            print("❌ No device tokens found in recent logs")
            print("💡 Make sure your Flutter app is running and has registered for push notifications")
            return None
            
    except subprocess.TimeoutExpired:
        print("⏰ Flutter logs command timed out")
        return None
    except Exception as e:
        print(f"❌ Error reading Flutter logs: {e}")
        return None

def create_test_script_with_token(device_token):
    """
    Create a customized version of the test script with the device token.
    """
    
    script_content = f"""#!/usr/bin/env python3
# Auto-generated test script with your device token

import boto3
import json
from datetime import datetime

def send_test_push():
    device_token = "{device_token}"
    
    try:
        sns = boto3.client('sns', region_name='ap-southeast-1')
        
        # Use sandbox for development
        platform_app_arn = "arn:aws:sns:ap-southeast-1:911167902662:app/APNS_SANDBOX/XoSo-iOS-Push"
        
        print(f"📱 Sending to device: {{device_token[:10]}}...")
        
        # Create endpoint
        endpoint_response = sns.create_platform_endpoint(
            PlatformApplicationArn=platform_app_arn,
            Token=device_token
        )
        endpoint_arn = endpoint_response['EndpointArn']
        
        # Create notification
        notification = {{
            "aps": {{
                "alert": {{
                    "title": "🎲 Xo So Test",
                    "body": "Your lottery notifications are working! 🎉"
                }},
                "badge": 1,
                "sound": "default"
            }}
        }}
        
        sns_message = {{
            "APNS_SANDBOX": json.dumps(notification),
            "default": "Test notification"
        }}
        
        # Send it
        response = sns.publish(
            TargetArn=endpoint_arn,
            Message=json.dumps(sns_message),
            MessageStructure='json'
        )
        
        print(f"✅ Notification sent! Message ID: {{response['MessageId']}}")
        
    except Exception as e:
        print(f"❌ Error: {{e}}")

if __name__ == "__main__":
    send_test_push()
"""
    
    with open('send_push_test.py', 'w') as f:
        f.write(script_content)
    
    print(f"✅ Created send_push_test.py with your device token!")
    print(f"🚀 Run: python3 send_push_test.py")

def main():
    print("🔍 Device Token Extractor")
    print("=" * 40)
    
    device_token = find_device_token_in_logs()
    
    if device_token:
        print(f"\\n🎯 Your device token: {device_token}")
        print(f"📏 Length: {len(device_token)} characters")
        
        # Validate token format
        if len(device_token) == 64 and all(c in '0123456789abcdefABCDEF' for c in device_token):
            print("✅ Token format looks valid!")
            
            # Create customized test script
            create_test_script_with_token(device_token)
            
        else:
            print("⚠️ Token format might be invalid (should be 64 hex characters)")
    else:
        print("\\n💡 To get your device token:")
        print("   1. Make sure your Flutter app is running")
        print("   2. Check the console logs for 'FULL DEVICE TOKEN'")
        print("   3. Or run this script again while the app is running")

if __name__ == "__main__":
    main()
