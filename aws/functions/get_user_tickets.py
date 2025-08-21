import json
import boto3
import os
from decimal import Decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TICKETS_TABLE'])

def handler(event, context):
    try:
        # Debug minimal request info
        try:
            headers = event.get('headers', {}) if isinstance(event, dict) else {}
            agent = headers.get('User-Agent') or headers.get('user-agent')
            print(f"MyTickets UA: {agent}")
        except Exception:
            pass

        user_id = None
        if isinstance(event, dict):
            # Prefer pathParameters for GET /getUserTickets/{userId}
            path_params = event.get('pathParameters') or {}
            if isinstance(path_params, dict):
                user_id = path_params.get('userId') or user_id

            # Fallback to query string
            if not user_id:
                qs = event.get('queryStringParameters') or {}
                if isinstance(qs, dict):
                    user_id = qs.get('userId') or user_id

            # Fallback to JSON body (POST support)
            if not user_id:
                raw_body = event.get('body')
                if isinstance(raw_body, str) and raw_body.strip():
                    try:
                        body = json.loads(raw_body)
                        user_id = body.get('userId')
                    except Exception:
                        pass
        
        if not user_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'userId is required'
                })
            }
        
        print(f"Fetching tickets for user: {user_id}")
        
        # Query using the UserIndex GSI
        response = table.query(
            IndexName='UserIndex',
            KeyConditionExpression=Key('userId').eq(user_id),
            ScanIndexForward=False
        )
        
        tickets = response.get('Items', [])
        
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
        
        tickets = convert_decimals(tickets)
        
        print(f"Found {len(tickets)} tickets for user {user_id}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
            },
            'body': json.dumps({
                'success': True,
                'tickets': tickets,
                'count': len(tickets)
            })
        }
        
    except Exception as e:
        print(f"Error fetching user tickets: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
            },
            'body': json.dumps({
                'success': False,
                'error': 'Internal server error'
            })
        }