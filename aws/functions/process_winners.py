import json
import boto3
import os
import datetime
from decimal import Decimal

def handler(event, context):
    """
    Daily lottery processing:
    1. Fetch latest lottery results from external API
    2. Store results in DynamoDB
    3. Process any tickets against new results
    This function runs daily via cron regardless of ticket volume.
    """
    try:
        # Initialize DynamoDB
        dynamodb = boto3.resource('dynamodb', region_name=os.environ['REGION'])
        tickets_table = dynamodb.Table(os.environ['DYNAMODB_TICKETS_TABLE'])
        results_table = dynamodb.Table(os.environ['DYNAMODB_RESULTS_TABLE'])
        
        # Get yesterday's date (when drawing results should be available)
        yesterday = (datetime.datetime.now() - datetime.timedelta(days=1)).strftime('%Y-%m-%d')
        
        print(f"Daily lottery processing for date: {yesterday}")
        
        # Step 1: Fetch and store latest lottery results
        results_fetched = fetch_and_store_lottery_results(results_table, yesterday)
        print(f"Lottery results fetched and stored: {results_fetched}")
        
        # Step 2: Process any tickets against results
        
        # Get all tickets for yesterday that haven't been checked
        response = tickets_table.scan(
            FilterExpression='drawDate = :date AND (attribute_not_exists(hasBeenChecked) OR hasBeenChecked = :false)',
            ExpressionAttributeValues={
                ':date': yesterday,
                ':false': False
            }
        )
        
        tickets = response['Items']
        print(f"Found {len(tickets)} unchecked tickets for {yesterday}")
        
        if not tickets:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'message': f'No unchecked tickets found for {yesterday}',
                    'ticketsProcessed': 0
                })
            }
        
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
                
                # Check if ticket is a winner
                is_winner, win_amount, prize_category = check_ticket_against_results(
                    ticket['numbers'], 
                    results['prizes']
                )
                
                # Update ticket with winner status
                update_expression = 'SET hasBeenChecked = :true, isWinner = :winner'
                expression_values = {
                    ':true': True,
                    ':winner': is_winner
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
                
                tickets_table.update_item(
                    Key={'ticketId': ticket['ticketId']},
                    UpdateExpression=update_expression,
                    ExpressionAttributeValues=expression_values
                )
                
                processed_count += 1
                
            except Exception as e:
                print(f"Error processing ticket {ticket.get('ticketId', 'unknown')}: {e}")
                continue
        
        print(f"Processing complete: {processed_count} tickets processed, {winner_count} winners found")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'message': f'Daily processing complete for {yesterday}',
                'resultsFetched': results_fetched,
                'ticketsProcessed': processed_count,
                'winnersFound': winner_count
            })
        }
        
    except Exception as e:
        print(f"Error in process_winners: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }

def check_ticket_against_results(ticket_numbers, lottery_results):
    """
    Check if a ticket matches any winning numbers.
    Returns (is_winner, win_amount, prize_category)
    """
    # Prize amounts in VND
    prize_amounts = {
        'G1': 3000000000,  # 3 billion VND
        'G2': 1000000000,  # 1 billion VND  
        'G3': 300000000,   # 300 million VND
        'G4': 50000000,    # 50 million VND
        'G5': 10000000,    # 10 million VND
        'G6': 3000000,     # 3 million VND
        'G7': 1000000,     # 1 million VND
        'DB': 500000000    # 500 million VND (Special Prize)
    }
    
    # Parse ticket numbers (remove spaces and convert to list)
    ticket_nums = [num.strip() for num in ticket_numbers.split(',') if num.strip()]
    
    # Check against each prize category
    for category, winning_numbers in lottery_results.items():
        if category not in prize_amounts:
            continue
            
        # winning_numbers is a list from DynamoDB
        for winning_num in winning_numbers:
            for ticket_num in ticket_nums:
                if ticket_num == winning_num:
                    return True, prize_amounts[category], category
    
    return False, 0, None

def fetch_and_store_lottery_results(results_table, date):
    """
    Fetch lottery results from external APIs and store in DynamoDB.
    Returns the number of province results fetched and stored.
    """
    # Vietnamese provinces that have daily lottery drawings
    provinces = [
        'Hà Nội', 'TP.HCM', 'Đồng Tháp', 'Cà Mau', 'Bến Tre', 'Vũng Tàu',
        'Bạc Liêu', 'Đà Nẵng', 'Quảng Nam', 'Daklak', 'Quảng Ninh', 'Hải Phòng',
        'Thừa Thiên Huế', 'An Giang', 'Bình Thuận', 'Tây Ninh', 'Bình Dương',
        'Trà Vinh', 'Vinh Long', 'Vĩnh Long', 'Kiên Giang', 'Tiền Giang',
        'Sóc Trăng', 'Cần Thơ', 'Đồng Nai', 'Long An', 'Hậu Giang'
    ]
    
    results_stored = 0
    
    for province in provinces:
        try:
            # Check if we already have results for this province and date
            existing = results_table.get_item(
                Key={'province': province, 'date': date}
            )
            
            if 'Item' in existing:
                print(f"Results already exist for {province} on {date}")
                continue
            
            # Generate sample lottery results (in production, this would call real API)
            results = generate_sample_lottery_results(province, date)
            
            if results:
                # Store in DynamoDB
                results_table.put_item(Item=results)
                results_stored += 1
                print(f"Stored results for {province} on {date}")
            
        except Exception as e:
            print(f"Error fetching results for {province} on {date}: {e}")
            continue
    
    return results_stored

def generate_sample_lottery_results(province, date):
    """
    Generate sample lottery results. In production, this would fetch from real APIs.
    Returns a DynamoDB item with lottery results.
    """
    import random
    
    # Generate realistic lottery numbers
    def random_number(digits):
        return str(random.randint(10**(digits-1), 10**digits - 1)).zfill(digits)
    
    # Vietnamese lottery structure
    results = {
        'province': province,
        'date': date,
        'region': 'vietnam',
        'prizes': {
            'DB': [random_number(5)],  # Special Prize
            'G1': [random_number(5)],  # First Prize  
            'G2': [random_number(5) for _ in range(2)],  # Second Prize
            'G3': [random_number(5) for _ in range(6)],  # Third Prize
            'G4': [random_number(4) for _ in range(4)],  # Fourth Prize
            'G5': [random_number(4) for _ in range(6)],  # Fifth Prize
            'G6': [random_number(3) for _ in range(3)],  # Sixth Prize
            'G7': [random_number(2) for _ in range(4)]   # Seventh Prize
        }
    }
    
    return results

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
        
        # Create message based on result
        if is_winner:
            # Winner notification
            formatted_amount = f"{win_amount:,.0f}".replace(',', '.')
            title = "🎉 Congratulations! You Won!"
            message = f"Your ticket {ticket_number} won {formatted_amount} VND ({prize_category})!"
            
            # Send to topic for winners
            topic_arn = f"arn:aws:sns:{os.environ['REGION']}:911167902662:lottery-winners"
        else:
            # Non-winner notification  
            title = "Lottery Results Available"
            message = f"Your ticket {ticket_number} for {province} on {draw_date} was not a winner this time. Better luck next time!"
            
            # Send to topic for all users
            topic_arn = f"arn:aws:sns:{os.environ['REGION']}:911167902662:lottery-results"
        
        # Create SNS message with structured data
        sns_message = {
            'default': message,
            'GCM': json.dumps({
                'data': {
                    'title': title,
                    'body': message,
                    'ticketId': ticket['ticketId'],
                    'userId': user_id,
                    'isWinner': is_winner,
                    'winAmount': str(win_amount) if is_winner else '0',
                    'prizeCategory': prize_category if prize_category else '',
                    'type': 'daily_results'
                }
            }),
            'APNS': json.dumps({
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
            })
        }
        
        # Publish to SNS topic
        response = sns.publish(
            TopicArn=topic_arn,
            Message=json.dumps(sns_message),
            MessageStructure='json',
            Subject=title
        )
        
        print(f"📲 Notification sent to user {user_id}: {title}")
        return response
        
    except Exception as e:
        print(f"❌ Error sending notification for ticket {ticket.get('ticketId', 'unknown')}: {e}")
        return None