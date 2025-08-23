#!/usr/bin/env python3
"""
Trigger the winner check process after running the automated winner test.
This script invokes the fetch_daily_results Lambda to process the winning ticket
that was created by the automated test.
"""

import boto3
import json
import sys
from datetime import datetime, timedelta

def trigger_winner_check(date_str=None):
    """
    Trigger the fetch_daily_results Lambda function to check for winners.
    
    Args:
        date_str (str): Date in YYYY-MM-DD format. Defaults to yesterday.
    """
    
    if not date_str:
        # Default to yesterday
        yesterday = datetime.now() - timedelta(days=1)
        date_str = yesterday.strftime('%Y-%m-%d')
    
    print(f"🚀 Triggering winner check for date: {date_str}")
    
    try:
        # Initialize Lambda client
        lambda_client = boto3.client('lambda', region_name='ap-southeast-1')
        
        # Prepare the payload
        payload = {
            'date': date_str,
            'source': 'automated_winner_test',
            'forceCheck': True
        }
        
        print(f"📡 Invoking Lambda: xoso-dev-fetchDailyResults")
        print(f"📅 Payload: {json.dumps(payload, indent=2)}")
        
        # Invoke the Lambda function
        response = lambda_client.invoke(
            FunctionName='xoso-dev-fetchDailyResults',
            InvocationType='RequestResponse',  # Synchronous call
            Payload=json.dumps(payload)
        )
        
        # Parse the response
        status_code = response['StatusCode']
        
        if status_code == 200:
            # Read the response payload
            response_payload = json.loads(response['Payload'].read().decode('utf-8'))
            
            print(f"✅ Lambda executed successfully!")
            print(f"📊 Status Code: {status_code}")
            print(f"📋 Response:")
            print(json.dumps(response_payload, indent=2))
            
            # Check if any tickets were processed
            body = response_payload.get('body')
            if body:
                if isinstance(body, str):
                    body = json.loads(body)
                
                tickets_processed = body.get('ticketsProcessed', 0)
                winners_found = body.get('winnersFound', 0)
                
                print(f"\n🎯 RESULTS:")
                print(f"   📝 Tickets Processed: {tickets_processed}")
                print(f"   🏆 Winners Found: {winners_found}")
                
                if winners_found > 0:
                    print(f"\n🎉 CONGRATULATIONS! You should receive a winner notification!")
                    print(f"📱 Check your iPhone for the push notification.")
                else:
                    print(f"\n💔 No winners found for {date_str}")
                    print(f"💡 Make sure you ran the automated winner test first.")
            
        else:
            print(f"❌ Lambda execution failed with status: {status_code}")
            print(f"📋 Response: {response}")
            
    except Exception as e:
        print(f"❌ Error triggering winner check: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

def main():
    """Main function with command line argument support."""
    
    print("🎲 Xo So Winner Test Trigger")
    print("=" * 50)
    
    # Check for date argument
    date_str = None
    if len(sys.argv) > 1:
        if sys.argv[1] in ['--help', '-h']:
            print("Usage: python3 trigger_winner_test.py [YYYY-MM-DD]")
            print("       python3 trigger_winner_test.py  (uses yesterday's date)")
            print("")
            print("This script triggers the Lambda function to check for winners")
            print("after you've run the automated winner test in the app.")
            return
        else:
            date_str = sys.argv[1]
    
    # Trigger the winner check
    success = trigger_winner_check(date_str)
    
    if success:
        print("\n🎯 Winner check completed!")
        print("📱 If you had a winning ticket, you should receive a push notification.")
    else:
        print("\n❌ Winner check failed. Check the error messages above.")

if __name__ == "__main__":
    main()
