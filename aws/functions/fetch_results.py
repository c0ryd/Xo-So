import json
import boto3
from decimal import Decimal
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
results_table = dynamodb.Table(os.environ['DYNAMODB_RESULTS_TABLE'])

def should_province_have_drawing(province, date_str):
    """
    Check if a specific province should have had a lottery drawing on the given date.
    Uses the province schedule to determine which provinces draw on which days.
    """
    try:
        # Parse the date to get the day of week
        target_date = datetime.strptime(date_str, '%Y-%m-%d')
        day_name = target_date.strftime('%A')  # Monday, Tuesday, etc.
        
        # Province schedule mapping (day of week -> list of provinces)
        # This matches the schedule used in fetch_daily_results.py
        province_schedule = {
            'Monday': ['Phú Yên', 'Huế', 'Đồng Tháp', 'Cà Mau', 'Hà Nội', 'TP.HCM'],
            'Tuesday': ['Đắk Lắk', 'Quảng Nam', 'Bến Tre', 'Vũng Tàu', 'Bạc Liêu', 'Quảng Ninh'],
            'Wednesday': ['Đồng Nai', 'Đà Nẵng', 'Sóc Trăng', 'Cần Thơ', 'Bắc Ninh', 'Khánh Hòa'],
            'Thursday': ['Bình Định', 'Bình Thuận', 'Quảng Bình', 'Quảng Trị', 'Hà Nội', 'Tây Ninh', 'An Giang'],
            'Friday': ['Bình Dương', 'Ninh Thuận', 'Trà Vinh', 'Gia Lai', 'Vĩnh Long', 'Hải Phòng'],
            'Saturday': ['Hậu Giang', 'Bình Phước', 'Long An', 'Đà Nẵng', 'Quảng Ngãi', 'Đắk Nông', 'Nam Định', 'TP.HCM'],
            'Sunday': ['Tiền Giang', 'Kiên Giang', 'Đà Lạt', 'Kon Tum', 'Huế', 'Khánh Hòa', 'Thái Bình']
        }
        
        provinces_for_day = province_schedule.get(day_name, [])
        
        # Check if the province is in the list for this day
        # Handle common name variations
        province_normalized = province.strip()
        for scheduled_province in provinces_for_day:
            if (province_normalized == scheduled_province or 
                province_normalized.replace(' ', '') == scheduled_province.replace(' ', '') or
                province_normalized in scheduled_province or
                scheduled_province in province_normalized):
                print(f"✅ Province {province} has drawing on {day_name}")
                return True
        
        print(f"❌ Province {province} does not have drawing on {day_name} (provinces for {day_name}: {provinces_for_day})")
        return False
        
    except Exception as e:
        print(f"Error checking province schedule for {province} on {date_str}: {e}")
        return False

def should_trigger_background_fetch(target_date):
    """
    Check if we should trigger background fetch for the given date.
    For current day: must be after 4pm Vietnam time
    For past days: always trigger
    """
    try:
        import pytz
        
        # Parse target date
        target_datetime = datetime.strptime(target_date, '%Y-%m-%d')
        
        # Get current time in Vietnam timezone (UTC+7)
        vietnam_tz = pytz.timezone('Asia/Ho_Chi_Minh')
        vietnam_now = datetime.now(vietnam_tz)
        vietnam_today = vietnam_now.date()
        
        # If target date is in the past, we should trigger fetch
        if target_datetime.date() < vietnam_today:
            return True
            
        # If target date is today, check if it's after 4pm Vietnam time
        if target_datetime.date() == vietnam_today:
            cutoff_time = vietnam_now.replace(hour=16, minute=0, second=0, microsecond=0)  # 4pm
            return vietnam_now >= cutoff_time
            
        # If target date is in the future, don't trigger fetch
        return False
        
    except Exception as e:
        print(f"Error checking if should trigger background fetch: {e}")
        # Default to allowing the fetch for past dates
        target_datetime = datetime.strptime(target_date, '%Y-%m-%d')
        return target_datetime.date() <= datetime.now().date()

def handler(event, context):
    try:
        # Debug incoming request
        try:
            headers = event.get('headers', {}) if isinstance(event, dict) else {}
            agent = headers.get('User-Agent') or headers.get('user-agent')
            print(f"FetchResults UA: {agent}")
            raw_body = event.get('body') if isinstance(event, dict) else None
            if isinstance(raw_body, str):
                preview = raw_body if len(raw_body) <= 500 else raw_body[:500] + '...'
                print(f"FetchResults raw body: {preview}")
            else:
                print(f"FetchResults body (non-string): {raw_body}")
        except Exception as log_e:
            print(f"FetchResults log error: {log_e}")
        # Parse the request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event
        
        province = body.get('province')
        date = body.get('date')
        
        if not province or not date:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Province and date are required'
                })
            }
        
        print(f"Fetching results for province: {province}, date: {date}")
        
        # Query the results table
        response = results_table.get_item(
            Key={
                'province': province,
                'date': date
            }
        )
        
        if 'Item' in response:
            item = response['Item']
            
            # Convert Decimal types to regular types for JSON serialization
            def convert_decimals(obj):
                if isinstance(obj, list):
                    return [convert_decimals(i) for i in obj]
                elif isinstance(obj, dict):
                    return {k: convert_decimals(v) for k, v in obj.items()}
                elif isinstance(obj, Decimal):
                    return int(obj) if obj % 1 == 0 else float(obj)
                else:
                    return obj
            
            # Extract results
            # Prefer nested 'prizes' map if present; otherwise include all non-metadata keys
            if 'prizes' in item and isinstance(item['prizes'], dict):
                results = convert_decimals(item['prizes'])
            else:
                results = {}
                for key, value in item.items():
                    if key not in ['province', 'date', 'region', 'createdAt', 'updatedAt']:
                        results[key] = convert_decimals(value)
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({
                    'success': True,
                    'results': results
                })
            }
        else:
            print(f"No results found for {province} on {date} - checking if we should trigger background fetch")
            
            # Check if this province should have had a drawing on this specific date
            if should_province_have_drawing(province, date):
                print(f"Province {province} should have drawing on {date} but results missing")
                
                # Check if results should be available based on time (after 4pm Vietnam time)
                if should_trigger_background_fetch(date):
                    print(f"Triggering background fetch for {province} on {date}")
                    
                    # Trigger the background fetch Lambda function asynchronously
                    try:
                        lambda_client = boto3.client('lambda', region_name=os.environ['REGION'])
                        
                        # Invoke the fetch_daily_results function asynchronously
                        lambda_client.invoke(
                            FunctionName=f"{os.environ.get('SERVICE_NAME', 'xoso')}-{os.environ.get('STAGE', 'dev')}-fetchDailyResults",
                            InvocationType='Event',  # Asynchronous invocation
                            Payload=json.dumps({
                                'date': date,
                                'triggered_by': 'fetch_results',
                                'trigger_province': province
                            })
                        )
                        print(f"✅ Background fetch triggered for {province} on {date}")
                        
                        # Return a message indicating background fetch was initiated
                        message = f'Results not yet available for {province} on {date}. Background fetch initiated - please try again in a few moments.'
                        
                    except Exception as lambda_error:
                        print(f"❌ Failed to trigger background fetch: {lambda_error}")
                        message = f'Results not yet available for {province} on {date}.'
                else:
                    print(f"Results not yet available for {date} (before 4pm Vietnam time)")
                    message = f'Results not yet available for {province} on {date}. Check again after 4pm Vietnam time.'
            else:
                print(f"Province {province} does not have drawing on {date} - no results expected")
                message = f'No lottery drawing expected for {province} on {date}.'
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({
                    'success': False,
                    'message': message
                })
            }
            
    except Exception as e:
        print(f"Error fetching results: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'success': False,
                'error': 'Internal server error'
            })
        }