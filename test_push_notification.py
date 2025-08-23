#!/usr/bin/env python3
"""
Test script to send a push notification to your iOS device using AWS SNS.
Use this to test push notifications with the device token from your app.
"""

import boto3
import json
import os
from datetime import datetime

def send_test_push_notification(device_token, message_title="🎉 Test Notification", message_body="Your push notifications are working!"):
    """
    Send a test push notification to the specified device token.
    
    Args:
        device_token (str): The iOS device token from your app
        message_title (str): Title of the notification
        message_body (str): Body text of the notification
    """
    
    try:
        # Initialize SNS client
        region = 'ap-southeast-1'  # Your AWS region
        sns = boto3.client('sns', region_name=region)
        
        # Determine which platform app ARN to use (development vs production)
        # Use sandbox for development/testing
        platform_app_arn = f"arn:aws:sns:{region}:911167902662:app/APNS_SANDBOX/XoSo-iOS-Push"
        
        print(f"📱 Sending test notification to device token: {device_token[:10]}...")
        print(f"🔧 Using platform ARN: {platform_app_arn}")
        
        # Create or get endpoint for this device token
        try:
            endpoint_response = sns.create_platform_endpoint(
                PlatformApplicationArn=platform_app_arn,
                Token=device_token,
                CustomUserData=json.dumps({
                    'userId': 'test-user',
                    'appVersion': '1.0.0',
                    'createdAt': datetime.now().isoformat()
                })
            )
            endpoint_arn = endpoint_response['EndpointArn']
            print(f"✅ Created/retrieved endpoint: {endpoint_arn}")
            
        except Exception as e:
            print(f"❌ Error creating platform endpoint: {e}")
            return False
        
        # Create the notification payload
        notification_payload = {
            "aps": {
                "alert": {
                    "title": message_title,
                    "body": message_body
                },
                "badge": 1,
                "sound": "default",
                "category": "test_notification"
            },
            "custom_data": {
                "type": "test",
                "timestamp": datetime.now().isoformat(),
                "source": "test_script"
            }
        }
        
        # Create the SNS message structure
        sns_message = {
            "APNS_SANDBOX": json.dumps(notification_payload),
            "default": message_body
        }
        
        print(f"📤 Sending notification...")
        print(f"   Title: {message_title}")
        print(f"   Body: {message_body}")
        
        # Send the notification
        response = sns.publish(
            TargetArn=endpoint_arn,
            Message=json.dumps(sns_message),
            MessageStructure='json'
        )
        
        print(f"✅ Push notification sent successfully!")
        print(f"📲 Message ID: {response['MessageId']}")
        return True
        
    except Exception as e:
        print(f"❌ Error sending test notification: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """
    Main function to test push notifications.
    Replace the device_token below with your actual device token.
    """
    
    # TODO: Replace this with your actual device token from the app logs
    device_token = "YOUR_DEVICE_TOKEN_HERE"
    
    if device_token == "YOUR_DEVICE_TOKEN_HERE":
        print("❌ Please replace the device_token variable with your actual device token!")
        print("🔍 Check your app logs for the full device token - it should be 64 hex characters")
        print("Example: 82bc2ff02d1234567890abcdef1234567890abcdef1234567890abcdef123456")
        return
    
    if len(device_token) != 64:
        print(f"⚠️ Warning: Device token length is {len(device_token)}, expected 64 characters")
        print("iOS APNs tokens should be exactly 64 hexadecimal characters")
    
    print(f"🚀 Testing push notification to device: {device_token[:10]}...")
    
    # Send test notification
    success = send_test_push_notification(
        device_token=device_token,
        message_title="🎲 Xo So Test",
        message_body="Great! Your lottery app push notifications are working perfectly! 🎉"
    )
    
    if success:
        print("🎉 Test completed successfully! Check your iPhone for the notification.")
    else:
        print("❌ Test failed. Check the error messages above.")

if __name__ == "__main__":
    main()
