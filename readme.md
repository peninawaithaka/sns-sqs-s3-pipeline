### Pipeline Details:

Logging email like messages to s3

* SNS - publish the message to an SNS topic
* SQS - receives the message and triggers lambda
* Lambda function - Writes the message into and S3 as a JSON

Other services used:
* IAM

### Pipeline: 
SNS >> SQS >> Lambda >> S3