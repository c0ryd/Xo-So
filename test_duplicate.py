#!/usr/bin/env python3

import requests
import json

# Test the duplicate endpoint directly
url = "https://u9maewv4ch.execute-api.ap-southeast-1.amazonaws.com/dev/duplicateTicket"

# You'll need to replace this with an actual ticket ID from your DB
test_payload = {
    "ticketId": "REPLACE_WITH_REAL_TICKET_ID",  # Replace with actual ticket ID
    "quantity": 3
}

headers = {
    "Content-Type": "application/json"
}

print(f"Testing duplicate endpoint: {url}")
print(f"Payload: {json.dumps(test_payload, indent=2)}")

try:
    response = requests.post(url, headers=headers, json=test_payload)
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
