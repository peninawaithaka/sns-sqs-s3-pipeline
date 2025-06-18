#!/bin/bash

cd ..
cd lambda
zip ../deploy/function.zip lambda_function.py
cd ..

# Update Lambda function
aws lambda update-function-code \
  --function-name process-event-lambda \
  --zip-file fileb://deploy/function.zip
