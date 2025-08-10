# Lottery Ticket Storage & Winner Notification System

This system automatically stores lottery tickets before drawings and sends notifications to winners after results are available.

## Architecture Overview

```
Flutter App → AWS API Gateway → Lambda Functions → DynamoDB
                                       ↓
Local Notifications + Email ← Winner Processing ← Scheduled Events
```

## Components

### 1. **DynamoDB Table** - `LotteryTickets`
- **Primary Key**: `ticketId` (UUID)
- **Global Secondary Indexes**:
  - `UserIndex`: Query tickets by `userId`
  - `DrawDateIndex`: Query tickets by `drawDate` and `province`

### 2. **Lambda Functions**
- **Store Ticket**: Saves ticket data before drawings
- **Process Winners**: Checks results and sends notifications after drawings
- **Get User Tickets**: Retrieves user's ticket history

### 3. **Notification System**
- Local notifications for immediate feedback
- Email notifications via AWS SNS for winners
- Database polling for app-based notifications

## Setup Instructions

### Prerequisites
- AWS CLI configured
- Node.js and npm installed
- Serverless Framework
- Supabase project (already configured)

### 1. AWS Infrastructure Deployment

1. **Install Dependencies**:
   ```bash
   cd aws/
   npm install
   ```

2. **Set Environment Variables** (optional):
   ```bash
   export SNS_EMAIL_TOPIC_ARN="arn:aws:account::911167902662:account"
   export CHECK_RESULTS_API_URL="https://nt1f2gqrh4.execute-api.ap-southeast-1.amazonaws.com/Production/check_results"
   ```

3. **Deploy to AWS**:
   ```bash
   # Development deployment
   npm run deploy-dev
   
   # Production deployment
   npm run deploy-prod
   ```

4. **Note the API Gateway URLs** from deployment output:
   ```
   endpoints:
     POST - https://xxxxxxxxxx.execute-api.ap-southeast-1.amazonaws.com/dev/storeTicket
     POST - https://xxxxxxxxxx.execute-api.ap-southeast-1.amazonaws.com/dev/processWinners  
     GET  - https://xxxxxxxxxx.execute-api.ap-southeast-1.amazonaws.com/dev/getUserTickets/{userId}
   ```

### 2. Flutter App Configuration

1. **Update API URL**:
   ```dart
   // In lib/services/ticket_storage_service.dart
   static const String _storeTicketApiUrl = 'YOUR_DEPLOYED_API_URL/storeTicket';
   ```

2. **Update Dependencies**:
   ```bash
   flutter pub get
   ```

### 3. Testing the System

1. **Test Ticket Storage**:
   ```bash
   # Scan a future lottery ticket
   # Should see: "✅ TICKET STORED FOR PROCESSING"
   ```

2. **Test Winner Processing**:
   ```bash
   # Manually trigger winner processing
   curl -X POST "YOUR_API_URL/processWinners" \
        -H "Content-Type: application/json" \
        -d '{"drawDate":"2025-01-15","province":"Tiền Giang","region":"south"}'
   ```

## Data Flow

### When User Scans a Ticket

1. **OCR Processing**: Extract city, date, ticket number
2. **Date Check**: Is draw date in the future?
   - **Yes**: Store in DynamoDB → Subscribe to notifications
   - **No**: Check winner immediately (existing flow)

### After Lottery Drawing

1. **Scheduled Trigger**: Lambda runs at 4:30 PM Vietnam time
2. **Query Tickets**: Get all tickets for today's drawings
3. **Check Winners**: Call existing winner API for each ticket
4. **Send Notifications**: Push notifications to winners via FCM
5. **Update Records**: Mark tickets as processed

## Database Schema

```json
{
  "ticketId": "uuid-string",
  "userId": "supabase-user-id", 
  "ticketNumber": "123456",
  "province": "Tiền Giang",
  "drawDate": "2025-01-15",
  "region": "south",
  "deviceToken": "device-token-for-notifications",
  "userEmail": "user@example.com",
  "scannedAt": "2025-01-14T10:30:00Z",
  "ocrRawText": "OCR extracted text",
  "isProcessed": false,
  "isWinner": null,
  "winAmount": null,
  "matchedTiers": null,
  "createdAt": "2025-01-14T10:30:00Z",
  "updatedAt": "2025-01-14T10:30:00Z"
}
```

## Notification Methods

### 1. Local Notifications (Immediate Feedback)
- Shown when tickets are successfully stored
- No external dependencies required
- Works offline

### 2. Email Notifications (Winners)
```
Subject: 🎉 Congratulations! You Won the Lottery! 🎉

Your lottery ticket 123456 is a WINNER!
Prize Amount: 50,000₫
Matched Tiers: Tier 5

Please check your lottery app for more details.
```

### 3. Database Polling (Future Enhancement)
- Notifications stored in DynamoDB
- App can poll for new notifications
- Fallback when email isn't available

## Monitoring & Troubleshooting

### CloudWatch Logs
```bash
# View Lambda logs
npm run logs-store    # serverless logs -f storeTicket -t
npm run logs-process  # serverless logs -f processWinners -t
npm run logs-get      # serverless logs -f getUserTickets -t
```

### DynamoDB Monitoring
- Check table metrics in AWS Console
- Monitor read/write capacity usage
- Review GSI performance

### Email Debugging
- Check SNS topic configuration
- Verify email addresses are valid
- Monitor SNS delivery reports

## Security Considerations

1. **API Authentication**: Uses AWS Cognito Identity Pool
2. **User Isolation**: Tickets filtered by authenticated user ID
3. **Data Encryption**: DynamoDB encryption at rest
4. **Token Security**: FCM tokens stored securely

## Cost Optimization

- **DynamoDB**: Start with 5 RCU/WCU, scale as needed
- **Lambda**: Efficient cold start with proper memory allocation
- **API Gateway**: Caching enabled for frequent requests
- **SNS**: Free tier covers most email usage

## Maintenance

### Regular Tasks
1. **Monitor costs** in AWS billing dashboard
2. **Review error logs** weekly
3. **Update dependencies** monthly
4. **Backup DynamoDB** (point-in-time recovery enabled)

### Scaling Considerations
- Increase DynamoDB capacity during peak lottery periods
- Add CloudFront for global API distribution
- Implement SQS for high-volume winner processing
