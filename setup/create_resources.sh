#!/bin/bash

set -e  # Exit on error

# --- CONFIGURATION ---
REGION="us-east-1"
ACCOUNT_ID="440744229926"
BUCKET_NAME="event-pipeline-bucket"
QUEUE_NAME="event-queue"
TOPIC_NAME="event-topic"
LAMBDA_NAME="process-event-lambda"
LAMBDA_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/lambda-execution-role"
ZIP_PATH="../deploy/function.zip"

# --- CREATE RESOURCES ---
echo "\n=== Creating S3 bucket ==="
aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION

echo "\n=== Creating SQS queue ==="
QUEUE_URL=$(aws sqs create-queue --queue-name $QUEUE_NAME --query 'QueueUrl' --output text)
QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $QUEUE_URL \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
echo "SQS Queue URL: $QUEUE_URL"
echo "SQS Queue ARN: $QUEUE_ARN"

echo "\n=== Creating SNS topic ==="
TOPIC_ARN=$(aws sns create-topic --name $TOPIC_NAME --query 'TopicArn' --output text)
echo "SNS Topic ARN: $TOPIC_ARN"

echo "\n=== Creating Lambda function ==="
aws lambda create-function \
  --function-name $LAMBDA_NAME \
  --runtime python3.11 \
  --role $LAMBDA_ROLE_ARN \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://$ZIP_PATH \
  --environment "Variables={BUCKET_NAME=$BUCKET_NAME}" \
  --region $REGION

echo "\n=== Subscribing Lambda to SNS ==="
aws sns subscribe --topic-arn $TOPIC_ARN \
  --protocol lambda \
  --notification-endpoint arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_NAME

echo "\n=== Allowing SNS to invoke Lambda ==="
aws lambda add-permission \
  --function-name $LAMBDA_NAME \
  --statement-id sns-invoke \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn $TOPIC_ARN

echo "\n=== Setting SQS permissions for SNS ==="
POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "sns.amazonaws.com"},
    "Action": "sqs:SendMessage",
    "Resource": "$QUEUE_ARN",
    "Condition": {
      "ArnEquals": {"aws:SourceArn": "$TOPIC_ARN"}
    }
  }]
}
EOF
)
aws sqs set-queue-attributes \
  --queue-url $QUEUE_URL \
  --attributes Policy="$POLICY"

echo "\n=== Subscribing SQS to SNS ==="
aws sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol sqs \
  --notification-endpoint $QUEUE_ARN

# --- DESTROY RESOURCES ---
echo "\n=== To destroy resources"
# echo "Deleting Lambda function..."
# aws lambda delete-function --function-name $LAMBDA_NAME

# echo "Deleting SNS topic..."
# aws sns delete-topic --topic-arn $TOPIC_ARN

# echo "Deleting SQS queue..."
# aws sqs delete-queue --queue-url $QUEUE_URL

# echo "Deleting S3 bucket and all contents..."
# aws s3 rm s3://$BUCKET_NAME --recursive
# aws s3api delete-bucket --bucket $BUCKET_NAME

# echo "Resources deleted."
