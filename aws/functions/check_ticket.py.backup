import json
import boto3
import os
import random
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
tickets_table = dynamodb.Table(os.environ['DYNAMODB_TICKETS_TABLE'])
results_table = dynamodb.Table(os.environ['DYNAMODB_RESULTS_TABLE'])

def get_region_from_province(province):
    """Map province to region (north/central/south)"""
    north_provinces = ['Hà Nội', 'Hải Phòng', 'Nam Định', 'Quảng Ninh', 'Bắc Ninh', 'Thái Bình']
    central_provinces = ['Đà Nẵng', 'Khánh Hòa', 'Phú Yên', 'Bình Định', 'Quảng Nam', 'Quảng Ngãi', 'Thừa Thiên Huế', 'Đắk Lắk', 'Nghệ An', 'Hà Tĩnh', 'Quảng Trị', 'Quảng Bình']
    
    if province in north_provinces:
        return 'north'
    elif province in central_provinces:
        return 'central'
    else:
        return 'south'

def ends_with_n_digits(ticket, target, n):
    """Check if ticket ends with the same n digits as target"""
    if len(ticket) < n or len(target) < n:
        return False
    return ticket[-n:] == target[-n:]

def hamming_distance(a, b):
    """Calculate Hamming distance between two strings"""
    if len(a) != len(b):
        return float('inf')
    return sum(c1 != c2 for c1, c2 in zip(a, b))

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

def fetch_lottery_results_from_api(province, date):
    """
    Fetch lottery results from the real Vietnamese lottery API (xoso188.net)
    Returns: dict with prize data or None if not available
    """
    try:
        import requests
        
        # Get the API code for the province
        api_code = get_province_api_code(province)
        if not api_code:
            print(f"No API code found for province: {province}")
            return None
        
        # Format date for finding the right result (convert YYYY-MM-DD to DD/MM/YYYY)
        try:
            date_parts = date.split('-')
            if len(date_parts) == 3:
                target_date = f"{date_parts[2]}/{date_parts[1]}/{date_parts[0]}"
            else:
                target_date = date
        except:
            target_date = date
            
        print(f"Calling xoso188.net API for province: {province} (code: {api_code}), target date: {target_date}")
        
        # Call the real Vietnamese lottery API
        api_url = f"https://xoso188.net/api/front/open/lottery/history/list/5/{api_code}"
        
        response = requests.get(api_url, timeout=10)
        if response.status_code == 200:
            api_data = response.json()
            
            if not api_data.get('success'):
                print(f"API returned unsuccessful response: {api_data}")
                return None
            
            # Find the specific date in the issue list
            issue_list = api_data.get('t', {}).get('issueList', [])
            target_result = None
            
            for issue in issue_list:
                if issue.get('turnNum') == target_date:
                    target_result = issue
                    break
            
            if not target_result:
                print(f"No results found for date {target_date} in API response")
                return None
            
            # Parse the API response into our expected format
            prizes = parse_xoso188_result(target_result)
            print(f"Successfully parsed lottery results for {province} on {target_date}")
            return prizes
            
        else:
            print(f"API returned status {response.status_code}")
            return None
        
    except Exception as e:
        print(f"Error calling xoso188.net API: {e}")
        return None

def get_province_api_code(province_name):
    """
    Map province name to API code used by xoso188.net
    """
    # Province name to API code mapping based on cities.csv
    province_mapping = {
        'An Giang': 'angi',
        'Bạc Liêu': 'bali', 'Bac Lieu': 'bali',
        'Bắc Ninh': 'bani', 'Bac Ninh': 'bani',
        'Bến Tre': 'betr', 'Ben Tre': 'betr',
        'Bình Định': 'bidi', 'Binh Dinh': 'bidi',
        'Bình Dương': 'bidu', 'Binh Duong': 'bidu',
        'Bình Phước': 'biph', 'Binh Phuoc': 'biph',
        'Bình Thuận': 'bith', 'Binh Thuan': 'bith',
        'Cà Mau': 'cama', 'Ca Mau': 'cama',
        'Cần Thơ': 'cath', 'Can Tho': 'cath',
        'Đà Lạt': 'dalat', 'Da Lat': 'dalat',
        'Đà Nẵng': 'dana', 'Da Nang': 'dana',
        'Đắk Lắk': 'dalak', 'Dak Lak': 'dalak',
        'Đắk Nông': 'dano', 'Dak Nong': 'dano',
        'Đồng Nai': 'dona', 'Dong Nai': 'dona',
        'Đồng Tháp': 'doth', 'Dong Thap': 'doth',
        'Gia Lai': 'gila',
        'Hải Phòng': 'haph', 'Hai Phong': 'haph',
        'Hà Nội': 'hano', 'Hanoi': 'hano',
        'Hậu Giang': 'haug', 'Hau Giang': 'haug',
        'TP.HCM': 'hcm', 'Ho Chi Minh': 'hcm',
        'Huế': 'hue', 'Hue': 'hue',
        'Khánh Hòa': 'kaha', 'Khanh Hoa': 'kaha',
        'Kiên Giang': 'kigi', 'Kien Giang': 'kigi',
        'Kon Tum': 'kotu',
        'Long An': 'loan',
        'Nam Định': 'nadi', 'Nam Dinh': 'nadi',
        'Ninh Thuận': 'nith', 'Ninh Thuan': 'nith',
        'Phú Yên': 'phye', 'Phu Yen': 'phye',
        'Quảng Bình': 'qubi', 'Quang Binh': 'qubi',
        'Quảng Nam': 'quna', 'Quang Nam': 'quna',
        'Quảng Ngãi': 'qung', 'Quang Ngai': 'qung',
        'Quảng Ninh': 'quni', 'Quang Ninh': 'quni',
        'Quảng Trị': 'qutr', 'Quang Tri': 'qutr',
        'Sóc Trăng': 'sotr', 'Soc Trang': 'sotr',
        'Tây Ninh': 'tani', 'Tay Ninh': 'tani',
        'Thái Bình': 'thbi', 'Thai Binh': 'thbi',
        'Tiền Giang': 'tigi', 'Tien Giang': 'tigi',
        'Trà Vinh': 'trvi', 'Tra Vinh': 'trvi',
        'Vĩnh Long': 'vilo', 'Vinh Long': 'vilo',
        'Vũng Tàu': 'vuta', 'Vung Tau': 'vuta'
    }
    
    return province_mapping.get(province_name.strip())

def parse_xoso188_result(issue_data):
    """
    Parse xoso188.net API result into our expected prize format
    """
    try:
        import json
        
        # The detail field contains the prize information as a JSON string
        detail_str = issue_data.get('detail', '[]')
        detail_data = json.loads(detail_str)
        
        if len(detail_data) < 8:
            print(f"Unexpected detail format: {detail_data}")
            return None
        
        # Map the detail array to our prize structure
        # Based on Vietnamese lottery structure:
        # [0] = DB (Đặc Biệt)
        # [1] = G1 (Giải Nhất) 
        # [2] = G2 (Giải Nhì)
        # [3] = G3 (Giải Ba)
        # [4] = G4 (Giải Tư)
        # [5] = G5 (Giải Năm)
        # [6] = G6 (Giải Sáu)
        # [7] = G7 (Giải Bảy)
        
        prizes = {}
        
        # Parse each prize tier
        if detail_data[0]:  # DB (Special Prize)
            prizes['DB'] = [detail_data[0]]
            
        if detail_data[1]:  # G1 (First Prize)
            prizes['G1'] = [detail_data[1]]
            
        if detail_data[2]:  # G2 (Second Prize)
            g2_numbers = detail_data[2].split(',') if isinstance(detail_data[2], str) else detail_data[2]
            prizes['G2'] = [num.strip() for num in g2_numbers if num.strip()]
            
        if detail_data[3]:  # G3 (Third Prize)
            g3_numbers = detail_data[3].split(',') if isinstance(detail_data[3], str) else detail_data[3]
            prizes['G3'] = [num.strip() for num in g3_numbers if num.strip()]
            
        if detail_data[4]:  # G4 (Fourth Prize)
            g4_numbers = detail_data[4].split(',') if isinstance(detail_data[4], str) else detail_data[4]
            prizes['G4'] = [num.strip() for num in g4_numbers if num.strip()]
            
        if detail_data[5]:  # G5 (Fifth Prize)
            g5_numbers = detail_data[5].split(',') if isinstance(detail_data[5], str) else detail_data[5]
            prizes['G5'] = [num.strip() for num in g5_numbers if num.strip()]
            
        if detail_data[6]:  # G6 (Sixth Prize)
            g6_numbers = detail_data[6].split(',') if isinstance(detail_data[6], str) else detail_data[6]
            prizes['G6'] = [num.strip() for num in g6_numbers if num.strip()]
            
        if detail_data[7]:  # G7 (Seventh Prize)
            g7_numbers = detail_data[7].split(',') if isinstance(detail_data[7], str) else detail_data[7]
            prizes['G7'] = [num.strip() for num in g7_numbers if num.strip()]
        
        print(f"Parsed prizes: {prizes}")
        return prizes
        
    except Exception as e:
        print(f"Error parsing xoso188 result: {e}")
        return None

def check_vietnamese_lottery_winner(ticket_number, prize_data, region):
    """
    Check if ticket is a winner using Vietnamese lottery rules
    Returns: {'is_winner': bool, 'amount': int, 'category': str}
    """
    if not isinstance(prize_data, dict):
        return {'is_winner': False, 'amount': 0, 'category': ''}
    
    # Configure payouts by region
    if region == 'north':
        expected_digits = 5
        payouts = {
            'DB': 1000000000,  # 1 billion VND for north
            'G1': 10000000, 'G2': 5000000, 'G3': 2000000,
            'G4': 600000, 'G5': 200000, 'G6': 100000, 'G7': 40000
        }
        tiers = [
            {'id': 'DB', 'suffix': 5},
            {'id': 'G1', 'suffix': 5}, {'id': 'G2', 'suffix': 5}, {'id': 'G3', 'suffix': 5},
            {'id': 'G4', 'suffix': 4}, {'id': 'G5', 'suffix': 4},
            {'id': 'G6', 'suffix': 3}, {'id': 'G7', 'suffix': 2}
        ]
        bonuses = {}
    else:  # south or central (6 digits)
        expected_digits = 6
        payouts = {
            'DB': 2000000000,  # 2 billion VND
            'G1': 30000000, 'G2': 15000000, 'G3': 10000000, 'G4': 3000000,
            'G5': 1000000, 'G6': 400000, 'G7': 200000, 'G8': 100000,
            'PHU_DB': 50000000, 'KK': 600000
        }
        tiers = [
            {'id': 'DB', 'suffix': 6},
            {'id': 'G1', 'suffix': 5}, {'id': 'G2', 'suffix': 5}, {'id': 'G3', 'suffix': 5}, {'id': 'G4', 'suffix': 5},
            {'id': 'G5', 'suffix': 4}, {'id': 'G6', 'suffix': 4},
            {'id': 'G7', 'suffix': 3}, {'id': 'G8', 'suffix': 2}
        ]
        bonuses = {'PHU_DB': True, 'KK': True}
    
    # Normalize ticket number
    ticket = ticket_number.replace(' ', '').zfill(expected_digits)
    
    print(f"Checking {expected_digits}-digit ticket: {ticket} in {region} region")
    
    all_matches = []
    
    # 1. Check exact DB matches first (highest priority)
    db_numbers = []
    for key in ['DB', 'ĐB', 'dacbiet', 'jackpot']:
        if key in prize_data:
            numbers = prize_data[key]
            if isinstance(numbers, list):
                db_numbers.extend([str(n).replace(' ', '') for n in numbers])
            elif isinstance(numbers, str):
                db_numbers.append(numbers.replace(' ', ''))
    
    for db_num in db_numbers:
        db_normalized = db_num.zfill(expected_digits)
        if ticket == db_normalized:
            all_matches.append({
                'tier': 'DB',
                'matched': db_normalized,
                'suffix_length': expected_digits,
                'amount': payouts.get('DB', 0),
                'rank': 1
            })
            print(f"✅ DB exact match: {ticket} == {db_normalized}")
    
    # 2. Check regular tier suffix matches
    for tier in tiers:
        if tier['id'] == 'DB':
            continue  # Already checked
            
        tier_numbers = []
        # Try various key formats for this tier
        possible_keys = [tier['id'], tier['id'].lower(), f"g{tier['id'][1:]}" if tier['id'].startswith('G') else tier['id']]
        
        for key in possible_keys:
            if key in prize_data:
                numbers = prize_data[key]
                if isinstance(numbers, list):
                    tier_numbers.extend([str(n).replace(' ', '') for n in numbers])
                elif isinstance(numbers, str):
                    tier_numbers.append(numbers.replace(' ', ''))
        
        for num in tier_numbers:
            num_normalized = num.zfill(expected_digits)
            if ends_with_n_digits(ticket, num_normalized, tier['suffix']):
                tier_rank = {'G1': 3, 'G2': 4, 'G3': 5, 'G4': 6, 'G5': 7, 'G6': 8, 'G7': 9, 'G8': 10}.get(tier['id'], 99)
                all_matches.append({
                    'tier': tier['id'],
                    'matched': num_normalized,
                    'suffix_length': tier['suffix'],
                    'amount': payouts.get(tier['id'], 0),
                    'rank': tier_rank
                })
                print(f"✅ {tier['id']} suffix match: {ticket} ends like {num_normalized} (last {tier['suffix']} digits)")
    
    # 3. Check bonuses (for 6-digit regions only)
    if expected_digits == 6 and db_numbers:
        for db_num in db_numbers:
            db_normalized = db_num.zfill(6)
            
            # PHU_DB: last 5 digits match DB, first digit differs
            if bonuses.get('PHU_DB') and len(ticket) == 6 and len(db_normalized) == 6:
                if ticket[1:] == db_normalized[1:] and ticket[0] != db_normalized[0]:
                    all_matches.append({
                        'tier': 'PHU_DB',
                        'matched': db_normalized,
                        'suffix_length': 0,
                        'amount': payouts.get('PHU_DB', 0),
                        'rank': 2
                    })
                    print(f"✅ PHU_DB match: {ticket} vs {db_normalized} (last 5 same, first diff)")
            
            # KK: Hamming distance 1 (exactly one digit different)
            if bonuses.get('KK') and len(ticket) == len(db_normalized):
                if hamming_distance(ticket, db_normalized) == 1:
                    all_matches.append({
                        'tier': 'KK',
                        'matched': db_normalized,
                        'suffix_length': 0,
                        'amount': payouts.get('KK', 0),
                        'rank': 11
                    })
                    print(f"✅ KK match: {ticket} vs {db_normalized} (Hamming distance 1)")
    
    if not all_matches:
        print(f"❌ No matches found for ticket {ticket}")
        return {'is_winner': False, 'amount': 0, 'category': ''}
    
    # Sort by rank (lower = better) and return highest prize
    all_matches.sort(key=lambda x: (x['rank'], -x['suffix_length']))
    best_match = all_matches[0]
    
    print(f"🎉 Winner! Best match: {best_match['tier']} for {best_match['amount']:,} VND")
    
    return {
        'is_winner': True,
        'amount': best_match['amount'],
        'category': best_match['tier']
    }

def handler(event, context):
    try:
        # Debug: Log incoming request details to compare client calls
        try:
            # Basic request context
            req_ctx = event.get('requestContext', {}) if isinstance(event, dict) else {}
            stage = req_ctx.get('stage')
            api_id = req_ctx.get('apiId') or req_ctx.get('apiId')
            print(f"REQ ctx stage={stage} apiId={api_id}")

            # Log essential headers only (avoid auth tokens)
            headers = event.get('headers', {}) if isinstance(event, dict) else {}
            host = headers.get('Host') or headers.get('host')
            xff = headers.get('X-Forwarded-For') or headers.get('x-forwarded-for')
            agent = headers.get('User-Agent') or headers.get('user-agent')
            print(f"REQ headers host={host} xff={xff} agent={agent}")

            # Log query/path params
            qp = event.get('queryStringParameters') if isinstance(event, dict) else None
            pp = event.get('pathParameters') if isinstance(event, dict) else None
            print(f"REQ query={qp} path={pp}")

            # Body (raw and parsed)
            raw_body = event.get('body') if isinstance(event, dict) else None
            if isinstance(raw_body, str):
                preview = raw_body if len(raw_body) <= 500 else raw_body[:500] + '...'
                print(f"REQ raw body: {preview}")
            else:
                print(f"REQ body (non-string): {raw_body}")
        except Exception as log_e:
            print(f"Debug log error: {log_e}")

        # Parse the request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event
            
        ticket_id = body.get('ticketId')
        
        if not ticket_id:
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
                    'error': 'ticketId is required'
                })
            }
        
        print(f"Checking ticket: {ticket_id}")
        
        # Get the ticket
        response = tickets_table.get_item(Key={'ticketId': ticket_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Ticket not found'
                })
            }
        
        ticket = response['Item']
        
        # Check if already processed
        if 'isWinner' in ticket:
            existing_amount = ticket.get('winAmount', 0)
            if isinstance(existing_amount, Decimal):
                try:
                    existing_amount = int(existing_amount)
                except Exception:
                    existing_amount = float(existing_amount)
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
                    'isWinner': ticket['isWinner'],
                    'winAmount': existing_amount,
                    'prizeCategory': ticket.get('prizeCategory', '')
                })
            }
        
        # Get lottery results for the ticket's draw date and province
        results_response = results_table.get_item(
            Key={
                'province': ticket['province'],
                'date': ticket['drawDate']
            }
        )
        
        if 'Item' not in results_response:
            # Results not found in DB - check if this province should have had a drawing on this date
            draw_date = ticket['drawDate']  # Format: YYYY-MM-DD
            province = ticket['province']
            
            print(f"No results found for {province} on {draw_date} - checking if province should have drawing on this date")
            
            # Check if this province should have had a drawing on this specific date
            if should_province_have_drawing(province, draw_date):
                print(f"Province {province} should have drawing on {draw_date} but results missing")
                
                # Check if results should be available based on time (after 4pm Vietnam time)
                if should_trigger_background_fetch(draw_date):
                    print(f"Triggering background fetch for {province} on {draw_date}")
                    
                    # Trigger the background fetch Lambda function asynchronously
                    try:
                        lambda_client = boto3.client('lambda', region_name=os.environ['REGION'])
                        
                        # Invoke the fetch_daily_results function asynchronously
                        lambda_client.invoke(
                            FunctionName=f"{os.environ.get('SERVICE_NAME', 'xoso')}-{os.environ.get('STAGE', 'dev')}-fetchDailyResults",
                            InvocationType='Event',  # Asynchronous invocation
                            Payload=json.dumps({
                                'date': draw_date,
                                'triggered_by': 'check_ticket',
                                'trigger_province': province
                            })
                        )
                        print(f"✅ Background fetch triggered for {province} on {draw_date}")
                        
                        # For now, still return pending status since the fetch is asynchronous
                        # The user can check again later after the background process completes
                        
                    except Exception as lambda_error:
                        print(f"❌ Failed to trigger background fetch: {lambda_error}")
                else:
                    print(f"Results not yet available for {draw_date} (before 4pm Vietnam time)")
            else:
                print(f"Province {province} does not have drawing on {draw_date} - no results expected")
            
            # Return pending status - background fetch will process later if applicable
            print(f"Returning pending status for ticket {ticket_id}")
            
            # Determine appropriate message based on whether province should have drawing
            if should_province_have_drawing(province, draw_date):
                if should_trigger_background_fetch(draw_date):
                    message = 'Results not yet available - ticket status is pending. Background fetch initiated.'
                else:
                    message = f'Results not yet available for {draw_date}. Check again after 4pm Vietnam time.'
            else:
                message = f'No lottery drawing expected for {province} on {draw_date}.'
            
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
                    'isPending': True,
                    'isWinner': None,  # Use None to indicate pending status
                    'winAmount': 0,
                    'prizeCategory': '',
                    'message': message
                })
            }
        
        # Vietnamese lottery winner checking logic
        results = results_response['Item']
        ticket_number = str(ticket['ticketNumber']).strip()
        province = ticket['province']
        region = ticket.get('region', 'south')  # Default to south if not specified
        
        # Determine region from province if not set
        if not region or region == 'unknown':
            region = get_region_from_province(province)
        
        # Get prize data
        prize_data = None
        if isinstance(results, dict) and 'prizes' in results and isinstance(results['prizes'], dict):
            prize_data = results['prizes']
        else:
            prize_data = results

        print(f"Checking ticket {ticket_number} in {province} ({region}) against results: {list(prize_data.keys()) if isinstance(prize_data, dict) else 'no prize data'}")
        
        # Check for winner using Vietnamese lottery rules
        match_result = check_vietnamese_lottery_winner(ticket_number, prize_data, region)
        
        is_winner = match_result['is_winner']
        win_amount = match_result['amount']
        prize_category = match_result['category']
        
        # Update ticket with results
        tickets_table.update_item(
            Key={'ticketId': ticket_id},
            UpdateExpression='SET isWinner = :winner, winAmount = :amount, prizeCategory = :category, checkedAt = :checked, hasBeenChecked = :hasChecked',
            ExpressionAttributeValues={
                ':winner': is_winner,
                ':amount': int(win_amount) if isinstance(win_amount, Decimal) else win_amount,
                ':category': prize_category,
                ':checked': datetime.now().isoformat(),
                ':hasChecked': True
            }
        )
        
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
                'isWinner': is_winner,
                'winAmount': int(win_amount) if isinstance(win_amount, Decimal) else win_amount,
                'prizeCategory': prize_category
            })
        }
        
    except Exception as e:
        print(f"Error checking ticket: {str(e)}")
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