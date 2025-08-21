import json
import uuid
import boto3
from datetime import datetime
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TICKETS_TABLE'])

def handler(event, context):
    """
    Store a lottery ticket in DynamoDB for future processing
    """
    try:
        # Parse request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        # Required fields
        required_fields = ['userId', 'ticketNumber', 'province', 'drawDate', 'region']
        for field in required_fields:
            if not body.get(field):
                return {
                    'statusCode': 400,
                    'headers': {
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type',
                        'Access-Control-Allow-Methods': 'OPTIONS,POST'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': f'Missing required field: {field}'
                    })
                }
        
        # Always create a new ticket (no deduplication here)
        user_id = body['userId']
        ticket_number = body['ticketNumber']
        province = body['province']
        draw_date = body['drawDate']
        
        # Generate ticket ID
        ticket_id = str(uuid.uuid4())
        
        # Prepare ticket data
        ticket_data = {
            'ticketId': ticket_id,
            'userId': user_id,
            'ticketNumber': ticket_number,
            'province': province,
            'drawDate': draw_date,
            'region': body['region'],
            'deviceToken': body.get('deviceToken', ''),
            'userEmail': body.get('userEmail', ''),
            'scannedAt': body.get('scannedAt', datetime.utcnow().isoformat()),
            'ocrRawText': body.get('ocrRawText', ''),
            'imagePath': body.get('imagePath', ''),
            'status': 'pending',
            'processed': False,
            'createdAt': datetime.utcnow().isoformat(),
            'updatedAt': datetime.utcnow().isoformat()
        }
        
        # Store in DynamoDB
        table.put_item(Item=ticket_data)
        
        print(f"✅ Stored ticket {ticket_id} for user {user_id}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'success': True,
                'isDuplicate': False,
                'ticketId': ticket_id,
                'message': 'Ticket stored successfully'
            })
        }
        
    except Exception as e:
        print(f"❌ Error storing ticket: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }
