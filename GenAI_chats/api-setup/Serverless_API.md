# ChatGPT Transcript

## Asking for a deployable AWS serverless API solution

What follows is a transcript between the requester and ChatGPT. The goal was to create an AWS-based serverless REST API service solution using ChatGPT at each step. My prompts are coded as blockquotes:
> I put my prompts in blockquotes like this

And the ChatGPT responses are in relatively untouched markdown (copying from the Mac ChatGPT app is iffy). Generated files are saved locally and linked to in the text.

## Transcript

> I want a facility to start a halted EC2 instance without logging into AWS -- preferably by hitting a REST endpoint. Make an API GW api that, when invoked with an active API Key will trigger a Lambda script that in turn starts a specific EC2 instance. Also make an option to stop that instance.

Here’s a high-level plan for setting up an AWS API Gateway + Lambda solution to start and stop a specific EC2 instance when invoked with an API key.

Solution Overview  
	1.	API Gateway: A REST API that provides two endpoints (/start and /stop) secured with an API key.  
	2.	Lambda Function: A Python-based Lambda function that handles the API requests and interacts with EC2.  
	3.	IAM Role & Permissions: A role allowing the Lambda function to start and stop EC2 instances.  
	4.	API Key Security: API Gateway requires a valid API key for invocation.  

<hr>

Implementation Steps

Step 1: Create an IAM Role for Lambda  
	1.	Go to the IAM Console → Create a role.  
	2.	Select AWS Service → Lambda.  
	3.	Attach the following policies:  
	•	AWSLambdaBasicExecutionRole
	•	A custom policy for EC2 start/stop permissions:  
		
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:DescribeInstances"
            ],
            "Resource": "arn:aws:ec2:your-region:your-account-id:instance/i-xxxxxxxxxxxxxxxxx"
        }
    ]
}
```
4.	Attach the policy to the Lambda role.

<hr>

Step 2: Create a Lambda Function  
	1.	Go to AWS Lambda Console → Create a function.  
	2.	Select Author from scratch.  
	3.	Use Python 3.9+ as the runtime.  
	4.	Attach the IAM role created in Step 1.  
	5.	Add the following Lambda function code:  

```python
import json
import boto3
import os

ec2 = boto3.client('ec2', region_name="your-region")

INSTANCE_ID = "i-xxxxxxxxxxxxxxxxx"  # Replace with your EC2 Instance ID

def lambda_handler(event, context):
    body = json.loads(event.get("body", "{}"))
    action = body.get("action", "").lower()

    if action not in ["start", "stop"]:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "Invalid action. Use 'start' or 'stop'."})
        }

    try:
        if action == "start":
            ec2.start_instances(InstanceIds=[INSTANCE_ID])
            message = f"Instance {INSTANCE_ID} is starting."
        else:
            ec2.stop_instances(InstanceIds=[INSTANCE_ID])
            message = f"Instance {INSTANCE_ID} is stopping."

        return {
            "statusCode": 200,
            "body": json.dumps({"message": message})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
```

6.	Deploy the function.

<hr>

Step 3: Create an API Gateway  
	1.	Go to API Gateway Console → Create REST API.  
	2.	Create a resource ”/ec2”.  
	3.	Add a POST method.  
	4.	Set Integration Type to “Lambda Function.”  
	5.	Select the created Lambda function.  

<hr>

Step 5: Deploy the API  
	1.	Click Deploy API.  
	2.	Create a new stage (e.g., “prod”).  
	3.	Copy the Invoke URL.  

<hr>

Using the API

Start EC2 Instance

```bash
curl -X POST "https://your-api-id.execute-api.your-region.amazonaws.com/prod/ec2" \
     -H "x-api-key: your-api-key" \
     -H "Content-Type: application/json" \
     -d '{"action": "start"}'
```
 
Stop EC2 Instance
 
```bash
 curl -X POST "https://your-api-id.execute-api.your-region.amazonaws.com/prod/ec2" \
     -H "x-api-key: your-api-key" \
     -H "Content-Type: application/json" \
     -d '{"action": "stop"}'
```
 
 <hr>
 
 Next Steps  
	•	You can configure CloudWatch Alarms to monitor instance status.  
	•	Enable IAM authentication instead of an API key for better security.  
	•	Set up a custom domain for the API.  

Would you like me to refine any part of this implementation? 🚀