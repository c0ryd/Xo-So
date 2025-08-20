# 📸 AWS S3 Setup for Ticket Images

## 🎯 **Overview**

This setup enables automatic upload of scanned ticket images to AWS S3 with structured naming based on OCR data.

## 📁 **S3 Folder Structure**

Images are organized in S3 with this structure:
```
xoso-ticket-images/
├── tickets/
│   ├── 2025/
│   │   ├── 08/
│   │   │   ├── 19/
│   │   │   │   ├── tien_giang/
│   │   │   │   │   ├── 369952_d2958756_1755594149520.jpg
│   │   │   │   │   └── 457123_f3e4d2a1_1755594251630.jpg
│   │   │   │   ├── ho_chi_minh/
│   │   │   │   └── binh_duong/
│   │   │   └── 20/
│   │   └── 09/
│   └── 2024/
└── fallback/
```

## 🏗️ **AWS Setup Required**

### **1. Create S3 Bucket**
```bash
# AWS CLI command
aws s3 mb s3://xoso-ticket-images --region ap-southeast-1
```

**Or via AWS Console:**
1. Go to [S3 Console](https://s3.console.aws.amazon.com/)
2. Click **Create bucket**
3. **Bucket name**: `xoso-ticket-images`
4. **Region**: `ap-southeast-1` (Singapore)
5. **Block public access**: Keep enabled (default)
6. Click **Create bucket**

### **2. Configure Bucket Policy**
Add this policy to allow authenticated users to upload:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowAuthenticatedUploads",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
            },
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::xoso-ticket-images/*"
        },
        {
            "Sid": "AllowListBucket",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:root"
            },
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::xoso-ticket-images"
        }
    ]
}
```

### **3. Update Cognito Identity Pool**
Ensure your Cognito Identity Pool has S3 permissions:

**Authenticated Role Policy:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::xoso-ticket-images/*"
        }
    ]
}
```

## 📝 **Filename Convention**

**Format**: `tickets/YYYY/MM/DD/province/ticketNumber_userId_timestamp.jpg`

**Example**: `tickets/2025/08/19/tien_giang/369952_d2958756_1755594149520.jpg`

**Components**:
- **Year/Month/Day**: From scanned date
- **Province**: Cleaned (lowercase, underscores)
- **Ticket Number**: From OCR
- **User ID**: First 8 chars of Supabase user ID
- **Timestamp**: Upload time in milliseconds

## 🔧 **App Integration**

### **Current Implementation**
```dart
// Save locally + upload to S3
final saveResult = await ImageStorageService.saveTicketImageWithMetadata(
  imageBytes: imageBytes,
  ticketNumber: "369952",
  province: "Tiền Giang", 
  date: "2025-08-19",
);

// Returns:
// {
//   'localPath': 'ticket_369952_1755594149520.jpg',
//   's3Url': 'https://xoso-ticket-images.s3.ap-southeast-1.amazonaws.com/tickets/2025/08/19/tien_giang/369952_d2958756_1755594149520.jpg'
// }
```

### **Features**
✅ **Dual Storage**: Local + S3 backup  
✅ **Structured Naming**: Searchable by date/province/ticket  
✅ **Graceful Fallback**: Local save succeeds even if S3 fails  
✅ **AWS SigV4**: Secure authenticated uploads  
✅ **Metadata Encoding**: OCR data embedded in filename  

## 🧪 **Testing**

### **Test S3 Access**
```dart
final hasAccess = await S3ImageService.testS3Access();
print('S3 Access: $hasAccess');
```

### **Manual Upload Test**
```dart
final s3Url = await S3ImageService.uploadTicketImage(
  imageBytes: imageBytes,
  ticketNumber: "123456",
  province: "Test Province",
  date: "2025-08-19",
);
```

## 💰 **Cost Estimation**

**S3 Storage (Singapore region)**:
- **Storage**: ~$0.025/GB/month
- **PUT requests**: ~$0.005/1000 requests  
- **GET requests**: ~$0.0004/1000 requests

**Example monthly cost** (1000 users, 10 tickets/month each):
- 10,000 images × 200KB = 2GB storage = **$0.05/month**
- 10,000 uploads = **$0.05/month**
- **Total: ~$0.10/month**

## 🔒 **Security Features**

✅ **IAM Authentication**: Only authenticated users can upload  
✅ **SigV4 Signing**: All requests cryptographically signed  
✅ **Private Bucket**: No public read access  
✅ **User Isolation**: User ID in filename for traceability  
✅ **Temporary Credentials**: Uses Cognito temporary credentials  

## 📋 **Next Steps**

1. **Create S3 bucket** (`xoso-ticket-images`)
2. **Configure bucket policy** (see above)
3. **Update Cognito permissions** for S3 access
4. **Test upload** functionality
5. **Monitor costs** and usage patterns

## 🎉 **Benefits**

✅ **Searchable Storage**: Find images by date/province/ticket  
✅ **Backup & Recovery**: Images safe in cloud  
✅ **Analytics Ready**: Structured data for insights  
✅ **Scalable**: Handles millions of images  
✅ **Cost Effective**: Pay only for what you use  

