#!/usr/bin/env python3
"""
Test script to validate AWS API endpoints for ticket storage and retrieval
"""

import json
import requests
import boto3
import uuid
from datetime import datetime
from amazon_cognito_identity import CognitoIdentityProvider

# Configuration
API_BASE_URL = "https://u9maewv4ch.execute-api.ap-southeast-1.amazonaws.com/dev"
IDENTITY_POOL_ID = "ap-southeast-1:9728af83-62a8-410f-a585-53de188a5079"
AWS_REGION = "ap-southeast-1"

def get_aws_credentials():
    """Get AWS credentials using Cognito Identity Pool for unauthenticated access"""
    try:
        # Create Cognito Identity client
        cognito_identity = boto3.client('cognito-identity', region_name=AWS_REGION)
        
        # Get identity ID for unauthenticated access
        identity_response = cognito_identity.get_id(
            IdentityPoolId=IDENTITY_POOL_ID
        )
        identity_id = identity_response['IdentityId']
        print(f"✅ Got Identity ID: {identity_id}")
        
        # Get credentials for this identity
        credentials_response = cognito_identity.get_credentials_for_identity(
            IdentityId=identity_id
        )
        
        credentials = credentials_response['Credentials']
        print(f"✅ Got AWS credentials")
        return credentials
        
    except Exception as e:
        print(f"❌ Error getting AWS credentials: {e}")
        return None

def make_signed_request(method, path, payload=None):
    """Make a signed request to the API Gateway"""
    try:
        from botocore.auth import SigV4Auth
        from botocore.awsrequest import AWSRequest
        import botocore.session
        
        # Get credentials
        aws_credentials = get_aws_credentials()
        if not aws_credentials:
            return None
            
        # Create a session with the credentials
        session = botocore.session.Session()
        credentials = botocore.credentials.Credentials(
            access_key=aws_credentials['AccessKeyId'],
            secret_key=aws_credentials['SecretKey'],
            token=aws_credentials['SessionToken']
        )
        
        # Create the request
        url = f"{API_BASE_URL}{path}"
        headers = {'Content-Type': 'application/json'}
        
        if method.upper() == 'POST' and payload:
            body = json.dumps(payload)
        else:
            body = None
            
        request = AWSRequest(method=method, url=url, data=body, headers=headers)
        
        # Sign the request
        SigV4Auth(credentials, 'execute-api', AWS_REGION).add_auth(request)
        
        # Make the request
        prepared_request = request.prepare()
        response = requests.request(
            method=prepared_request.method,
            url=prepared_request.url,
            headers=dict(prepared_request.headers),
            data=prepared_request.body
        )
        
        return response
        
    except Exception as e:
        print(f"❌ Error making signed request: {e}")
        return None

def test_store_ticket():
    """Test the storeTicket endpoint with mock data including image path"""
    print("\n🔍 TESTING STORE TICKET ENDPOINT")
    print("=" * 50)
    
    # Mock test data
    test_payload = {
        "userId": f"test-user-{uuid.uuid4()}",
        "ticketNumber": "123456",
        "province": "Tiền Giang",
        "drawDate": "2025-01-20",
        "region": "south",
        "deviceToken": "mock-device-token",
        "userEmail": "test@example.com",
        "scannedAt": datetime.utcnow().isoformat(),
        "ocrRawText": "Mock OCR text from test",
        "imagePath": "/path/to/test/image123456_1642680000000.jpg"  # THIS IS THE KEY FIELD
    }
    
    print(f"📤 Sending payload:")
    print(json.dumps(test_payload, indent=2))
    
    # Make the request
    response = make_signed_request('POST', '/storeTicket', test_payload)
    
    if response:
        print(f"\n📥 Response Status: {response.status_code}")
        print(f"📥 Response Body: {response.text}")
        
        if response.status_code == 200:
            response_data = response.json()
            if response_data.get('success'):
                ticket_id = response_data.get('ticketId')
                print(f"✅ Ticket stored successfully with ID: {ticket_id}")
                return test_payload['userId'], ticket_id
            else:
                print(f"❌ Store ticket failed: {response_data}")
        else:
            print(f"❌ API call failed with status {response.status_code}")
    else:
        print("❌ Failed to make API request")
    
    return None, None

def test_get_user_tickets(user_id):
    """Test the getUserTickets endpoint"""
    print(f"\n🔍 TESTING GET USER TICKETS ENDPOINT")
    print("=" * 50)
    
    test_payload = {
        "userId": user_id
    }
    
    print(f"📤 Requesting tickets for user: {user_id}")
    
    # Make the request
    response = make_signed_request('POST', '/getUserTickets', test_payload)
    
    if response:
        print(f"\n📥 Response Status: {response.status_code}")
        print(f"📥 Response Body: {response.text}")
        
        if response.status_code == 200:
            response_data = response.json()
            if response_data.get('success'):
                tickets = response_data.get('tickets', [])
                print(f"✅ Retrieved {len(tickets)} tickets")
                
                # Check if imagePath is present in the retrieved tickets
                for i, ticket in enumerate(tickets):
                    print(f"\n🎫 Ticket {i+1}:")
                    print(f"   ID: {ticket.get('ticketId')}")
                    print(f"   Number: {ticket.get('ticketNumber')}")
                    print(f"   Province: {ticket.get('province')}")
                    print(f"   Date: {ticket.get('drawDate')}")
                    
                    # THIS IS THE CRITICAL CHECK
                    image_path = ticket.get('imagePath')
                    if image_path:
                        print(f"   ✅ Image Path: {image_path}")
                    else:
                        print(f"   ❌ Image Path: MISSING!")
                        
                return tickets
            else:
                print(f"❌ Get tickets failed: {response_data}")
        else:
            print(f"❌ API call failed with status {response.status_code}")
    else:
        print("❌ Failed to make API request")
    
    return []

def main():
    """Main test function"""
    print("🚀 TESTING AWS API ENDPOINTS FOR IMAGE PATH STORAGE")
    print("=" * 60)
    
    # Step 1: Store a ticket with image path
    user_id, ticket_id = test_store_ticket()
    
    if not user_id:
        print("❌ Failed to store ticket, cannot proceed with retrieval test")
        return
    
    # Step 2: Retrieve the user's tickets and check for image path
    tickets = test_get_user_tickets(user_id)
    
    # Step 3: Analysis
    print(f"\n📊 ANALYSIS RESULTS")
    print("=" * 30)
    
    if tickets:
        image_paths_found = [t for t in tickets if t.get('imagePath')]
        image_paths_missing = [t for t in tickets if not t.get('imagePath')]
        
        print(f"✅ Tickets with image path: {len(image_paths_found)}")
        print(f"❌ Tickets missing image path: {len(image_paths_missing)}")
        
        if image_paths_missing:
            print("\n🔍 ISSUE DETECTED: Image paths are not being stored in DynamoDB!")
            print("   This explains why images don't appear on the summary page.")
        else:
            print("\n✅ SUCCESS: Image paths are being stored correctly!")
    else:
        print("❌ No tickets retrieved, cannot analyze image path storage")

if __name__ == "__main__":
    main()
