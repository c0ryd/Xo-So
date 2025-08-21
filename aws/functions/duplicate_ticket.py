import json
import uuid
import boto3
from datetime import datetime
from decimal import Decimal
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TICKETS_TABLE'])

def handler(event, context):
    try:
        # Parse the request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event
            
        ticket_id = body.get('ticketId')
        quantity = body.get('quantity', 1)
        
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
        
        if not isinstance(quantity, int) or quantity < 1 or quantity > 10:
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
                    'error': 'quantity must be between 1 and 10'
                })
            }
        
        duplicates_needed = quantity - 1  # Total quantity minus the original
        print(f"Duplicating ticket {ticket_id}: creating {duplicates_needed} duplicates for total of {quantity}")
        
        # Get the original ticket
        response = table.get_item(Key={'ticketId': ticket_id})
        
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
                    'error': 'Original ticket not found'
                })
            }
        
        original_ticket = response['Item']
        duplicates_created = 0
        
        # Create duplicates (quantity - 1)
        for i in range(duplicates_needed):
            try:
                # Create new ticket with same data but new ID
                new_ticket = original_ticket.copy()
                new_ticket['ticketId'] = str(uuid.uuid4())
                new_ticket['scannedAt'] = datetime.now().isoformat()
                new_ticket['isDuplicate'] = True
                new_ticket['originalTicketId'] = ticket_id
                
                # Store the duplicate ticket
                table.put_item(Item=new_ticket)
                duplicates_created += 1
                
            except Exception as e:
                print(f"Error creating duplicate {i+1}: {str(e)}")
                continue
        
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
                'duplicatesCreated': duplicates_created,
                'requestedQuantity': quantity,
                'totalTickets': duplicates_created + 1  # Include original
            })
        }
        
    except Exception as e:
        print(f"Error duplicating ticket: {str(e)}")
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