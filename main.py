import json
import boto3
import uuid
import os


def lambda_handler(event, context):
    s3 = boto3.client('s3')