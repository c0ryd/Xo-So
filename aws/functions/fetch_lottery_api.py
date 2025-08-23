import json
import boto3
import requests
import datetime
from decimal import Decimal

def handler(event, context):
    """
    Centralized lottery results fetching from external API.
    
    Input:
        - province: str (e.g., "Hà Nội")
        - date: str (YYYY-MM-DD format)
        - source: str (optional, for tracking)
    
    Output:
        - success: bool
        - data: dict (prize data if successful)
        - message: str
        - province: str
        - date: str
    """
    try:
        # Parse input
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event
        
        province = body.get('province')
        date = body.get('date')
        source = body.get('source', 'unknown')
        
        if not province or not date:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'success': False,
                    'message': 'Province and date are required',
                    'data': None
                })
            }
        
        print(f"🎯 Fetching lottery results: {province} on {date} (source: {source})")
        
        # Fetch from external API
        lottery_data = fetch_lottery_results_from_api(province, date)
        
        if lottery_data:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'data': lottery_data,
                    'message': f'Successfully fetched results for {province} on {date}',
                    'province': province,
                    'date': date,
                    'source': source
                }, default=decimal_default)
            }
        else:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': False,
                    'data': None,
                    'message': f'No results available for {province} on {date}',
                    'province': province,
                    'date': date,
                    'source': source
                })
            }
            
    except Exception as e:
        print(f"❌ Error in centralized lottery fetch: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'data': None,
                'message': f'Internal error: {str(e)}',
                'error': str(e)
            })
        }

def fetch_lottery_results_from_api(province, date):
    """
    Fetch lottery results from the real Vietnamese lottery API (xoso188.net)
    Returns: dict with prize data or None if not available
    """
    try:
        # Get API code for province
        api_code = get_province_api_code(province)
        if not api_code:
            print(f"❌ No API code found for province: {province}")
            return None
        
        # Convert date format for API
        try:
            date_obj = datetime.datetime.strptime(date, '%Y-%m-%d')
            target_date = date_obj.strftime('%Y-%m-%d')
        except:
            print(f"❌ Invalid date format: {date}")
            return None
            
        print(f"🌐 Calling xoso188.net API for province: {province} (code: {api_code}), target date: {target_date}")
        
        # Call the real Vietnamese lottery API
        api_url = f"https://xoso188.net/api/front/open/lottery/history/list/5/{api_code}"
        
        response = requests.get(api_url, timeout=10)
        if response.status_code == 200:
            api_data = response.json()
            
            # Find results for our target date - REAL API structure is {"t": {"issueList": [...]}}
            if not api_data.get('success'):
                print(f"API returned unsuccessful response: {api_data}")
                return None
            
            # Parse the API response to extract lottery results
            issue_list = api_data.get('t', {}).get('issueList', [])
            target_result = None
            
            # Convert target date to DD/MM/YYYY format for comparison
            try:
                date_obj = datetime.datetime.strptime(target_date, '%Y-%m-%d')
                formatted_target_date = date_obj.strftime('%d/%m/%Y')
            except:
                print(f"❌ Invalid date format: {target_date}")
                return None
            
            for issue in issue_list:
                if issue.get('turnNum') == formatted_target_date:
                    target_result = issue
                    break
            
            if target_result:
                print(f"✅ Found lottery data for {province} on {target_date}")
                return parse_xoso188_result(target_result)
            else:
                print(f"⚠️ No results found for date {formatted_target_date} in API response")
                return None
        else:
            print(f"❌ xoso188.net API returned status code: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ Error calling xoso188.net API: {e}")
        return None

def get_province_api_code(province):
    """
    Map province name to API code used by xoso188.net
    """
    # Province name to API code mapping based on cities.csv
    province_codes = {
        'Hà Nội': 'hano',
        'TP.HCM': 'hcm', 
        'Đồng Tháp': 'dongthap',
        'Cà Mau': 'camau',
        'Bến Tre': 'bentre',
        'Vũng Tàu': 'vungtau',
        'Bạc Liêu': 'baclieu',
        'Đà Nẵng': 'danang',
        'Quảng Nam': 'quangnam',
        'Daklak': 'daklak',
        'Đắk Lắk': 'daklak',  # Alternative spelling
        'Quảng Ninh': 'quangninh',
        'Hải Phòng': 'haiphong',
        'Thừa Thiên Huế': 'hue',
        'An Giang': 'angi',
        'Bình Thuận': 'binhthuan',
        'Tây Ninh': 'tayninh',
        'Bình Dương': 'binhduong',
        'Trà Vinh': 'travinh',
        'Vinh Long': 'vinhlong',
        'Vĩnh Long': 'vinhlong',  # Alternative spelling
        'Kiên Giang': 'kiengiang',
        'Tiền Giang': 'tiengiang',
        'Sóc Trăng': 'soctrang',
        'Cần Thơ': 'cantho',
        'Đồng Nai': 'dongnai',
        'Long An': 'longan',
        'Hậu Giang': 'haugiang',
        'Kon Tum': 'kontum',
        'Quảng Trị': 'quangtri',
        'Đà Lạt': 'dalat',
        'Thái Bình': 'thaibinh',
        'Gia Lai': 'gialai',
        'Ninh Thuận': 'ninhthuan',
        'Bắc Ninh': 'bacninh',
        'Bình Định': 'binhdinh',
        'Quảng Bình': 'quangbinh',
        'Phú Yên': 'phuyen'
    }
    
    return province_codes.get(province)

def parse_xoso188_result(record):
    """
    Parse xoso188.net API result into our expected prize format
    """
    try:
        if not record or 'results' not in record:
            return None
        
        results_str = record['results']
        if not results_str:
            return None
        
        # Split by comma and clean up the numbers
        raw_numbers = results_str.split(',')
        cleaned_numbers = []
        
        for number in raw_numbers:
            # Remove any non-digit characters and strip whitespace
            clean_num = ''.join(filter(str.isdigit, number.strip()))
            if clean_num:
                cleaned_numbers.append(clean_num)
        
        if not cleaned_numbers:
            return None
        
        # Organize into prize structure (simplified version)
        # The first number is usually the special prize, others are various prize levels
        prize_data = {
            'special': cleaned_numbers[0] if len(cleaned_numbers) > 0 else '',
            'first': cleaned_numbers[1:3] if len(cleaned_numbers) > 1 else [],
            'second': cleaned_numbers[3:8] if len(cleaned_numbers) > 3 else [],
            'third': cleaned_numbers[8:14] if len(cleaned_numbers) > 8 else [],
            'fourth': cleaned_numbers[14:18] if len(cleaned_numbers) > 14 else [],
            'fifth': cleaned_numbers[18:24] if len(cleaned_numbers) > 18 else [],
            'sixth': cleaned_numbers[24:27] if len(cleaned_numbers) > 24 else [],
            'seventh': cleaned_numbers[27:30] if len(cleaned_numbers) > 27 else [],
            'eighth': cleaned_numbers[30:] if len(cleaned_numbers) > 30 else []
        }
        
        return prize_data
        
    except Exception as e:
        print(f"❌ Error parsing xoso188.net result: {e}")
        return None

def decimal_default(obj):
    """JSON serializer for Decimal objects"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError
