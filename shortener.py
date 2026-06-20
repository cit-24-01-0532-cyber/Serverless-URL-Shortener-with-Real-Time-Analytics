import json
import os
import random
import string
import boto3

# DynamoDB සම්බන්ධ කරගැනීම
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    path = event.get('path', '')
    http_method = event.get('httpMethod', '')

    # 1. URL එකක් කොට කිරීම (POST /shorten)
    if http_method == 'POST' and path == '/shorten':
        body = json.loads(event.get('body', '{}'))
        long_url = body.get('long_url')
        
        if not long_url:
            return {"statusCode": 400, "body": json.dumps({"error": "long_url is required"})}

        # Random අකුරු 6ක string එකක් හැදීම (e.g., aBc12D)
        short_id = ''.join(random.choices(string.ascii_letters + string.digits, k=6))
        
        # Database එකට දත්ත ඇතුලත් කිරීම
        table.put_item(Item={
            'short_id': short_id,
            'long_url': long_url,
            'clicks': 0
        })
        
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"short_url": f"https://{event['requestContext']['domainName']}/prod/{short_id}"})
        }

    
    elif http_method == 'GET' and path != '/shorten':
        short_id = path.strip('/')
        
     
        response = table.get_item(Key={'short_id': short_id})
        item = response.get('item') or response.get('Item')
        
        if not item:
            return {"statusCode": 404, "body": json.dumps({"error": "URL not found"})}
        
        # Clicks ගණන 1කින් වැඩි කිරීම (Analytics)
        table.update_item(
            Key={'short_id': short_id},
            UpdateExpression="SET clicks = clicks + :val",
            ExpressionAttributeValues={':val': 1}
        )
        
        # User ව ඇත්තම URL එකට Redirect කිරීම
        return {
            "statusCode": 302,
            "headers": {"Location": item['long_url']}
        }

    return {"statusCode": 400, "body": json.dumps({"error": "Unsupported route"})}