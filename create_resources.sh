#!/bin/bash

set -e  # Exit on error

# Load environment variables from .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi


# # --- CREATE RESOURCES ---
# echo "\n=== Creating S3 bucket ==="
# aws s3api create-bucket \
#   --bucket $BUCKET_NAME \
#   --region $REGION || true #if bucket exists, step is skipped

echo "\n=== Creating SQS queue ==="
QUEUE_URL=$(aws sqs create-queue --queue-name $QUEUE_NAME --query 'QueueUrl' --output text)
QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $QUEUE_URL \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
echo "SQS Queue URL: $QUEUE_URL"
echo "SQS Queue ARN: $QUEUE_ARN"

echo "\n=== Creating SNS topic ==="
TOPIC_ARN=$(aws sns create-topic --name $TOPIC_NAME --query 'TopicArn' --output text)
echo "SNS Topic ARN: $TOPIC_ARN"

# echo "\n=== Creating Lambda function ==="
# aws lambda create-function \
#   --function-name $LAMBDA_NAME \
#   --runtime python3.11 \
#   --role $LAMBDA_ROLE_ARN \
#   --handler lambda_function.lambda_handler \
#   --zip-file fileb://$ZIP_PATH \
#   --environment "Variables={BUCKET_NAME=$BUCKET_NAME}" \
#   --region $REGION || echo "Lambda function exists"

# echo "\n=== Subscribing SQS to SNS ==="
# aws sns subscribe \
#   --topic-arn $TOPIC_ARN \
#   --protocol sqs \
#   --notification-endpoint $QUEUE_ARN

# echo "=== Linking SQS to Lambda ==="
# aws lambda create-event-source-mapping \
#   --function-name $LAMBDA_NAME \
#   --event-source-arn $QUEUE_ARN \
#   --batch-size 5 \
#   --enabled


echo -e "\n=== Allowing SNS to send to SQS ==="

# Build the raw JSON policy
POLICY_JSON=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow-SNS-SendMessage",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "SQS:SendMessage",
      "Resource": "$QUEUE_ARN",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "$TOPIC_ARN"
        }
      }
    }
  ]
}
EOF
)

# ✅ Compact and escape the JSON using jq (must be installed)
ESCAPED_POLICY=$(echo "$POLICY_JSON" | jq -c '.')

# ✅ Apply the policy safely
aws sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attributes "Policy=$ESCAPED_POLICY"



#--- DESTROY RESOURCES ---
# echo "\n=== To destroy resources"
# echo "Deleting Lambda function..."
# aws lambda delete-function --function-name $LAMBDA_NAME

# echo "Deleting SNS topic..."
# aws sns delete-topic --topic-arn $TOPIC_ARN

# echo "Deleting SQS queue..."
# aws sqs delete-queue --queue-url https://sqs.us-east-1.amazonaws.com/440744229926/event-queue

# echo "Deleting S3 bucket and all contents..."
# aws s3 rm s3://$BUCKET_NAME --recursive
# aws s3api delete-bucket --bucket $BUCKET_NAME

# echo "Resources deleted."
