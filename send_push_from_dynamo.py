#!/usr/bin/env python3
"""
Get device token from DynamoDB and send a test push notification.
This script will find the most recent ticket with a device token and use it to send a test notification.
"""

import boto3
import json
import os
from datetime import datetime
from boto3.dynamodb.conditions import Key

def get_recent_device_token(user_id=None):
    """
    Get the most recent device token from DynamoDB tickets table.
    
    Args:
        user_id (str, optional): Specific user ID to search for. If None, gets the most recent overall.
    
    Returns:
        tuple: (device_token, user_id, ticket_info) or (None, None, None) if not found
    """
    
    try:
        # Initialize DynamoDB
        dynamodb = boto3.resource('dynamodb', region_name='ap-southeast-1')
        
        # Use your tickets table name based on serverless config
        table_name = 'xoso-tickets-dev'  # Development table name
        table = dynamodb.Table(table_name)
        
        print(f"🔍 Searching for device tokens in table: {table_name}")
        
        if user_id:
            # Query for specific user using UserIndex GSI
            print(f"🔍 Searching for user: {user_id}")
            response = table.query(
                IndexName='UserIndex',
                KeyConditionExpression=Key('userId').eq(user_id),
                ScanIndexForward=False,  # Get most recent first
                Limit=10  # Just get recent tickets
            )
            items = response.get('Items', [])
        else:
            # Scan for all tickets (less efficient but works when we don't know user ID)
            print("🔍 Scanning for any recent tickets with device tokens...")
            response = table.scan(
                FilterExpression='attribute_exists(deviceToken) AND deviceToken <> :empty',
                ExpressionAttributeValues={':empty': ''},
                Limit=50  # Limit scan for performance
            )
            items = response.get('Items', [])
            
            # Sort by createdAt to get most recent
            items = sorted(items, key=lambda x: x.get('createdAt', ''), reverse=True)
        
        print(f"📊 Found {len(items)} tickets")
        
        # Find the first ticket with a valid device token
        for ticket in items:
            device_token = ticket.get('deviceToken', '').strip()
            if device_token and len(device_token) >= 60:  # Valid device token length
                ticket_user_id = ticket.get('userId', 'unknown')
                ticket_id = ticket.get('ticketId', 'unknown')
                province = ticket.get('province', 'unknown')
                created_at = ticket.get('createdAt', 'unknown')
                
                print(f"✅ Found valid device token!")
                print(f"   User ID: {ticket_user_id}")
                print(f"   Ticket ID: {ticket_id}")
                print(f"   Province: {province}")
                print(f"   Created: {created_at}")
                print(f"   Token: {device_token[:10]}...{device_token[-10:]}")
                print(f"   Token length: {len(device_token)}")
                
                return device_token, ticket_user_id, {
                    'ticketId': ticket_id,
                    'province': province,
                    'createdAt': created_at
                }
        
        print("❌ No valid device tokens found")
        return None, None, None
        
    except Exception as e:
        print(f"❌ Error querying DynamoDB: {e}")
        import traceback
        traceback.print_exc()
        return None, None, None

def send_push_notification(device_token, user_id, ticket_info=None):
    """
    Send a test push notification using AWS SNS.
    """
    
    try:
        # Initialize SNS
        sns = boto3.client('sns', region_name='ap-southeast-1')
        
        # Use sandbox for development (change to production ARN for prod)
        platform_app_arn = "arn:aws:sns:ap-southeast-1:911167902662:app/APNS_SANDBOX/XoSo-iOS-Push"
        
        print(f"📱 Sending push notification...")
        print(f"   To device: {device_token[:10]}...{device_token[-10:]}")
        print(f"   User: {user_id}")
        
        # Create or get platform endpoint
        try:
            endpoint_response = sns.create_platform_endpoint(
                PlatformApplicationArn=platform_app_arn,
                Token=device_token,
                CustomUserData=json.dumps({
                    'userId': user_id,
                    'testNotification': True,
                    'timestamp': datetime.now().isoformat()
                })
            )
            endpoint_arn = endpoint_response['EndpointArn']
            print(f"✅ Platform endpoint: {endpoint_arn}")
            
        except Exception as e:
            print(f"❌ Error creating platform endpoint: {e}")
            return False
        
        # Create notification payload
        title = "🎲 Xo So Test Notification"
        body = "Great! Your push notifications are working perfectly! 🎉"
        
        if ticket_info:
            body = f"Test notification for your {ticket_info.get('province', 'unknown')} ticket!"
        
        notification_payload = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body
                },
                "badge": 1,
                "sound": "default",
                "category": "test_notification"
            },
            "custom_data": {
                "type": "test_notification",
                "user_id": user_id,
                "timestamp": datetime.now().isoformat(),
                "source": "dynamo_test_script"
            }
        }
        
        # Create SNS message
        sns_message = {
            "APNS_SANDBOX": json.dumps(notification_payload),
            "default": body
        }
        
        # Send the notification
        response = sns.publish(
            TargetArn=endpoint_arn,
            Message=json.dumps(sns_message),
            MessageStructure='json'
        )
        
        print(f"✅ Push notification sent successfully!")
        print(f"📲 Message ID: {response['MessageId']}")
        print(f"💬 Title: {title}")
        print(f"💬 Body: {body}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error sending push notification: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """
    Main function to get device token from DynamoDB and send test notification.
    """
    
    print("🚀 DynamoDB Device Token Push Test")
    print("=" * 50)
    
    # Try to get device token from DynamoDB
    # You can optionally specify a user_id if you know it
    user_id = None  # Set this to a specific user ID if you know it
    
    device_token, found_user_id, ticket_info = get_recent_device_token(user_id)
    
    if device_token:
        print(f"\n🎯 Found device token for user: {found_user_id}")
        
        # Send test notification
        success = send_push_notification(device_token, found_user_id, ticket_info)
        
        if success:
            print("\n🎉 Test completed successfully!")
            print("📱 Check your iPhone for the notification.")
        else:
            print("\n❌ Test failed. Check the error messages above.")
            
    else:
        print("\n❌ No device tokens found in DynamoDB")
        print("💡 Make sure you have:")
        print("   1. Scanned at least one ticket in your app")
        print("   2. The app successfully stored the ticket with device token")
        print("   3. Using the correct DynamoDB table name in this script")

if __name__ == "__main__":
    main()
