import json
import boto3
import uuid
import os


s3 = boto3.client('s3')
BUCKET_NAME = os.environ['BUCKET_NAME']

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    for record in event['Records']:
        message = json.loads(record['Sns']['Message'])
        key = f"processed/{uuid.uuid4()}.json"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=key,
            Body=json.dumps(message),
            ContentType='application/json'
        )

    return {"status": "done"}