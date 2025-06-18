import os
import json
import boto3
from dotenv import load_dotenv

load_dotenv()

REGION = os.getenv("REGION")
TOPIC_ARN = os.getenv("TOPIC_ARN")
EVENT_FILE = 'events.json'

sns = boto3.client('sns', region_name=REGION)

file_path = os.path.join(os.path.dirname(__file__), EVENT_FILE)
with open(file_path, 'r') as f:
    event_data = json.load(f)

response = sns.publish(
    TopicArn=TOPIC_ARN,
    Message=json.dumps(event_data),
    Subject='User Event'
)

print(f"SNS Response", response)

