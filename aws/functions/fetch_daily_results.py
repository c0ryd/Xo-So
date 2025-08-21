import json
import boto3
import os
import datetime
from decimal import Decimal

def handler(event, context):
    """
    On-demand lottery results fetching triggered when a scan happens and results should be available.
    This function:
    1. Determines which provinces should have results for the given date
    2. Checks if it's after 4pm Vietnam time for current day (or any past day)
    3. Fetches results from external API for all relevant provinces
    4. Stores results in DynamoDB
    5. Processes any pending tickets against new results and sends notifications
    """
    try:
        # Parse the request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event
            
        # Get the date to fetch results for
        target_date = body.get('date')  # Format: YYYY-MM-DD
        
        if not target_date:
            # Default to yesterday if no date provided
            target_date = (datetime.datetime.now() - datetime.timedelta(days=1)).strftime('%Y-%m-%d')
            
        print(f"Starting on-demand results fetch for date: {target_date}")
        
        # Check if results should be available for this date
        if not should_results_be_available(target_date):
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
                    'message': f'Results not yet available for {target_date}. Check again after 4pm Vietnam time.',
                    'resultsFetched': 0,
                    'ticketsProcessed': 0
                })
            }
        
        # Initialize DynamoDB
        dynamodb = boto3.resource('dynamodb', region_name=os.environ['REGION'])
        tickets_table = dynamodb.Table(os.environ['DYNAMODB_TICKETS_TABLE'])
        results_table = dynamodb.Table(os.environ['DYNAMODB_RESULTS_TABLE'])
        
        # Get provinces that should have drawings on this date
        provinces_to_fetch = get_provinces_for_date(target_date)
        print(f"Found {len(provinces_to_fetch)} provinces to fetch results for on {target_date}")
        
        if not provinces_to_fetch:
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
                    'message': f'No provinces have drawings on {target_date}',
                    'resultsFetched': 0,
                    'ticketsProcessed': 0
                })
            }
        
        # Fetch and store results for each province
        results_fetched = 0
        for province in provinces_to_fetch:
            try:
                # Check if we already have results for this province and date
                existing = results_table.get_item(
                    Key={'province': province, 'date': target_date}
                )
                
                if 'Item' in existing:
                    print(f"Results already exist for {province} on {target_date}")
                    continue
                
                # Fetch results from external API
                external_results = fetch_lottery_results_from_api(province, target_date)
                
                if external_results:
                    # Store in DynamoDB
                    results_table.put_item(
                        Item={
                            'province': province,
                            'date': target_date,
                            'region': get_region_from_province(province),
                            'prizes': external_results,
                            'createdAt': datetime.datetime.now().isoformat(),
                            'source': 'on-demand-fetch'
                        }
                    )
                    results_fetched += 1
                    print(f"✅ Stored results for {province} on {target_date}")
                else:
                    print(f"❌ No results available from external API for {province} on {target_date}")
                    
            except Exception as e:
                print(f"Error fetching results for {province} on {target_date}: {e}")
                continue
        
        # Process any pending tickets for this date (regardless of whether we fetched new results)
        tickets_processed = 0
        winners_found = 0
        
        print(f"Processing pending tickets for {target_date}")
        tickets_processed, winners_found = process_pending_tickets(tickets_table, results_table, target_date)
        
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
                'message': f'On-demand fetch complete for {target_date}',
                'resultsFetched': results_fetched,
                'ticketsProcessed': tickets_processed,
                'winnersFound': winners_found
            })
        }
        
    except Exception as e:
        print(f"Error in fetch_daily_results: {e}")
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
                'error': str(e)
            })
        }

def should_results_be_available(target_date):
    """
    Check if lottery results should be available for the given date.
    For current day: must be after 4pm Vietnam time
    For past days: always available
    """
    try:
        import pytz
        
        # Parse target date
        target_datetime = datetime.datetime.strptime(target_date, '%Y-%m-%d')
        
        # Get current time in Vietnam timezone (UTC+7)
        vietnam_tz = pytz.timezone('Asia/Ho_Chi_Minh')
        vietnam_now = datetime.datetime.now(vietnam_tz)
        vietnam_today = vietnam_now.date()
        
        # If target date is in the past, results should be available
        if target_datetime.date() < vietnam_today:
            return True
            
        # If target date is today, check if it's after 4pm Vietnam time
        if target_datetime.date() == vietnam_today:
            cutoff_time = vietnam_now.replace(hour=16, minute=0, second=0, microsecond=0)  # 4pm
            return vietnam_now >= cutoff_time
            
        # If target date is in the future, results are not available
        return False
        
    except Exception as e:
        print(f"Error checking time availability: {e}")
        # Default to allowing the fetch for past dates
        target_datetime = datetime.datetime.strptime(target_date, '%Y-%m-%d')
        return target_datetime.date() <= datetime.datetime.now().date()

def get_provinces_for_date(date_str):
    """
    Get list of provinces that should have lottery drawings on the given date.
    Uses the province schedule to determine which provinces draw on which days.
    """
    try:
        # Parse the date to get the day of week
        target_date = datetime.datetime.strptime(date_str, '%Y-%m-%d')
        day_name = target_date.strftime('%A')  # Monday, Tuesday, etc.
        
        # Province schedule mapping (day of week -> list of provinces)
        province_schedule = {
            'Monday': ['Phú Yên', 'Huế', 'Đồng Tháp', 'Cà Mau', 'Hà Nội', 'TP.HCM'],
            'Tuesday': ['Đắk Lắk', 'Quảng Nam', 'Bến Tre', 'Vũng Tàu', 'Bạc Liêu', 'Quảng Ninh'],
            'Wednesday': ['Đồng Nai', 'Đà Nẵng', 'Sóc Trăng', 'Cần Thơ', 'Bắc Ninh', 'Khánh Hòa'],
            'Thursday': ['Bình Định', 'Bình Thuận', 'Quảng Bình', 'Quảng Trị', 'Hà Nội', 'Tây Ninh', 'An Giang'],
            'Friday': ['Bình Dương', 'Ninh Thuận', 'Trà Vinh', 'Gia Lai', 'Vĩnh Long', 'Hải Phòng'],
            'Saturday': ['Hậu Giang', 'Bình Phước', 'Long An', 'Đà Nẵng', 'Quảng Ngãi', 'Đắk Nông', 'Nam Định', 'TP.HCM'],
            'Sunday': ['Tiền Giang', 'Kiên Giang', 'Đà Lạt', 'Kon Tum', 'Huế', 'Khánh Hòa', 'Thái Bình']
        }
        
        provinces = province_schedule.get(day_name, [])
        print(f"Day: {day_name}, Provinces: {provinces}")
        return provinces
        
    except Exception as e:
        print(f"Error getting provinces for date {date_str}: {e}")
        return []

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

def process_pending_tickets(tickets_table, results_table, target_date):
    """
    Process any tickets that are pending for the given date and send notifications.
    Returns (tickets_processed, winners_found)
    """
    try:
        # Get all tickets for this date that haven't been checked or are pending
        response = tickets_table.scan(
            FilterExpression='drawDate = :date AND (attribute_not_exists(hasBeenChecked) OR hasBeenChecked = :false OR (attribute_exists(isPending) AND isPending = :true))',
            ExpressionAttributeValues={
                ':date': target_date,
                ':false': False,
                ':true': True
            }
        )
        
        tickets = response['Items']
        print(f"Found {len(tickets)} pending tickets for {target_date}")
        
        if not tickets:
            return 0, 0
        
        processed_count = 0
        winner_count = 0
        
        # Process each ticket
        for ticket in tickets:
            try:
                # Get lottery results for this ticket's province and date
                results_response = results_table.get_item(
                    Key={
                        'province': ticket['province'],
                        'date': ticket['drawDate']
                    }
                )
                
                if 'Item' not in results_response:
                    print(f"No results found for {ticket['province']} on {ticket['drawDate']}")
                    continue
                
                results = results_response['Item']
                
                # Use the winner checking logic directly (copied from check_ticket)
                
                # Check if ticket is a winner
                ticket_number = str(ticket['ticketNumber']).strip()
                province = ticket['province']
                region = ticket.get('region', get_region_from_province(province))
                
                prize_data = results.get('prizes', {})
                match_result = check_vietnamese_lottery_winner(ticket_number, prize_data, region)
                
                is_winner = match_result['is_winner']
                win_amount = match_result['amount']
                prize_category = match_result['category']
                
                # Update ticket with winner status
                update_expression = 'SET hasBeenChecked = :true, isWinner = :winner, checkedAt = :checked'
                expression_values = {
                    ':true': True,
                    ':winner': is_winner,
                    ':checked': datetime.datetime.now().isoformat()
                }
                
                if is_winner:
                    update_expression += ', winAmount = :amount, prizeCategory = :category'
                    expression_values[':amount'] = Decimal(str(win_amount))
                    expression_values[':category'] = prize_category
                    winner_count += 1
                    print(f"🎉 Winner found: Ticket {ticket['ticketId']} won {win_amount} VND ({prize_category})")
                    
                    # Send winner notification
                    send_notification(ticket, True, win_amount, prize_category)
                else:
                    # Send loser notification  
                    send_notification(ticket, False, 0, None)
                
                # Remove isPending if it exists
                update_expression += ' REMOVE isPending'
                
                tickets_table.update_item(
                    Key={'ticketId': ticket['ticketId']},
                    UpdateExpression=update_expression,
                    ExpressionAttributeValues=expression_values
                )
                
                processed_count += 1
                
            except Exception as e:
                print(f"Error processing ticket {ticket.get('ticketId', 'unknown')}: {e}")
                continue
        
        print(f"Pending ticket processing complete: {processed_count} tickets processed, {winner_count} winners found")
        return processed_count, winner_count
        
    except Exception as e:
        print(f"Error processing pending tickets: {e}")
        return 0, 0

def check_vietnamese_lottery_winner(ticket_number, prizes, region):
    """
    Check if a Vietnamese lottery ticket is a winner based on the rules.
    Returns dict with: is_winner, amount, category
    """
    try:
        # Normalize ticket number
        normalized_ticket = str(ticket_number).strip().zfill(6 if region in ['central', 'south'] else 5)
        
        # Prize amounts in VND (approximate values)
        prize_amounts = {
            'DB': 3000000000,     # Đặc Biệt - 3 billion VND
            'G1': 300000000,      # Giải Nhất - 300 million VND  
            'G2': 100000000,      # Giải Nhì - 100 million VND
            'G3': 50000000,       # Giải Ba - 50 million VND
            'G4': 10000000,       # Giải Tư - 10 million VND
            'G5': 3000000,        # Giải Năm - 3 million VND
            'G6': 1000000,        # Giải Sáu - 1 million VND
            'G7': 500000,         # Giải Bảy - 500k VND
            'PDB': 50000000,      # Phụ Đặc Biệt - 50 million VND
            'KK': 10000000        # Khuyến Khích - 10 million VND
        }
        
        matches = []
        
        # Check exact matches for DB (Special Prize)
        if 'DB' in prizes:
            for winning_number in prizes['DB']:
                if str(winning_number).strip() == normalized_ticket:
                    matches.append(('DB', 0, winning_number))
        
        # Check suffix matches for all other prizes
        for prize_tier in ['G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7']:
            if prize_tier in prizes:
                for winning_number in prizes[prize_tier]:
                    winning_str = str(winning_number).strip()
                    
                    # Check 2-digit suffix match
                    if ends_with_n_digits(normalized_ticket, winning_str, 2):
                        matches.append((prize_tier, 2, winning_number))
                    # Check 3-digit suffix match  
                    elif ends_with_n_digits(normalized_ticket, winning_str, 3):
                        matches.append((prize_tier, 3, winning_number))
                    # Check 4-digit suffix match
                    elif ends_with_n_digits(normalized_ticket, winning_str, 4):
                        matches.append((prize_tier, 4, winning_number))
                    # Check 5-digit suffix match (for eligible regions)
                    elif region in ['central', 'south'] and ends_with_n_digits(normalized_ticket, winning_str, 5):
                        matches.append((prize_tier, 5, winning_number))
        
        # Check bonus prizes for specific regions
        if region == 'north':
            # Phụ Đặc Biệt: last 5 digits of Đặc Biệt
            if 'DB' in prizes and prizes['DB']:
                db_number = str(prizes['DB'][0]).strip()
                if len(db_number) >= 5:
                    db_last_5 = db_number[-5:]
                    if normalized_ticket.endswith(db_last_5):
                        matches.append(('PDB', 5, db_last_5))
        else:
            # Central/South regions: Khuyến Khích
            # Last 4 digits of any G1 winner
            if 'G1' in prizes:
                for g1_number in prizes['G1']:
                    g1_str = str(g1_number).strip()
                    if len(g1_str) >= 4:
                        g1_last_4 = g1_str[-4:]
                        if normalized_ticket.endswith(g1_last_4):
                            matches.append(('KK', 4, g1_last_4))
        
        if not matches:
            return {'is_winner': False, 'amount': 0, 'category': ''}
        
        # Sort matches by prize rank (DB highest, G7 lowest)
        prize_rank = {'DB': 0, 'G1': 1, 'G2': 2, 'G3': 3, 'G4': 4, 'G5': 5, 'G6': 6, 'G7': 7, 'PDB': 8, 'KK': 9}
        matches.sort(key=lambda x: prize_rank.get(x[0], 99))
        
        # Return the highest prize match
        best_match = matches[0]
        prize_tier = best_match[0]
        digits_matched = best_match[1]
        winning_number = best_match[2]
        
        return {
            'is_winner': True,
            'amount': prize_amounts.get(prize_tier, 0),
            'category': prize_tier,
            'digits_matched': digits_matched,
            'winning_number': winning_number
        }
        
    except Exception as e:
        print(f"Error checking lottery winner: {e}")
        return {'is_winner': False, 'amount': 0, 'category': ''}

def ends_with_n_digits(ticket_number, winning_number, n):
    """Check if ticket number ends with the last n digits of winning number"""
    try:
        ticket_str = str(ticket_number).strip()
        winning_str = str(winning_number).strip()
        
        if len(winning_str) < n or len(ticket_str) < n:
            return False
            
        return ticket_str[-n:] == winning_str[-n:]
    except:
        return False

def send_notification(ticket, is_winner, win_amount=0, prize_category=None):
    """
    Send push notification to user about their ticket result using AWS SNS.
    """
    try:
        sns = boto3.client('sns', region_name=os.environ['REGION'])
        
        # Get user info from ticket
        user_id = ticket['userId']
        ticket_number = ticket.get('ticketNumber', 'Unknown')
        province = ticket.get('province', 'Unknown')
        draw_date = ticket.get('drawDate', 'Unknown')
        device_token = ticket.get('deviceToken', '')
        
        # Skip if no device token
        if not device_token:
            print(f"⚠️ No device token for user {user_id}, skipping push notification")
            return None
        
        # Create message based on result
        if is_winner:
            # Winner notification
            formatted_amount = f"{win_amount:,.0f}".replace(',', '.')
            title = "🎉 Congratulations! You Won!"
            message = f"Your ticket {ticket_number} won {formatted_amount} VND ({prize_category})!"
        else:
            # Non-winner notification  
            title = "Lottery Results Available"
            message = f"Your ticket {ticket_number} for {province} on {draw_date} was not a winner this time. Better luck next time!"
        
        # Determine platform application (use sandbox for dev, production for prod)
        stage = os.environ.get('STAGE', 'dev')
        if stage == 'prod':
            platform_app_arn = f"arn:aws:sns:{os.environ['REGION']}:911167902662:app/APNS/XoSo-iOS-Push-Production"
        else:
            platform_app_arn = f"arn:aws:sns:{os.environ['REGION']}:911167902662:app/APNS_SANDBOX/XoSo-iOS-Push"
        
        # Create or get endpoint for this device token
        try:
            endpoint_response = sns.create_platform_endpoint(
                PlatformApplicationArn=platform_app_arn,
                Token=device_token,
                CustomUserData=user_id
            )
            endpoint_arn = endpoint_response['EndpointArn']
            print(f"📱 Created/retrieved endpoint: {endpoint_arn}")
        except Exception as endpoint_error:
            print(f"❌ Error creating endpoint: {endpoint_error}")
            return None
        
        # Create APNS payload
        apns_payload = {
            'aps': {
                'alert': {
                    'title': title,
                    'body': message
                },
                'badge': 1,
                'sound': 'default'
            },
            'custom_data': {
                'ticketId': ticket['ticketId'],
                'userId': user_id,
                'isWinner': is_winner,
                'winAmount': str(win_amount) if is_winner else '0',
                'prizeCategory': prize_category if prize_category else '',
                'type': 'daily_results'
            }
        }
        
        # Create message payload for the appropriate platform
        message_payload = {'default': message}
        
        if stage == 'prod':
            message_payload['APNS'] = json.dumps(apns_payload)
        else:
            message_payload['APNS_SANDBOX'] = json.dumps(apns_payload)
        
        # Send notification directly to endpoint
        response = sns.publish(
            TargetArn=endpoint_arn,
            Message=json.dumps(message_payload),
            MessageStructure='json',
            Subject=title
        )
        
        print(f"📲 Push notification sent to user {user_id} ({stage}): {title}")
        print(f"📱 Message ID: {response.get('MessageId', 'unknown')}")
        return response
        
    except Exception as e:
        print(f"❌ Error sending notification for ticket {ticket.get('ticketId', 'unknown')}: {e}")
        return None
