from time import sleep
import collections
import json

def execute(event, context): 
    id = 1
    params = event['queryStringParameters']
    if isinstance(params, collections.Mapping):
        id = params.get('id', 1)
        
    sleep(0.6)
    return {
        "statusCode": 200,
        "headers": {
            "Cache-Control": "no-cache, no-store, must-revalidate"
        },
        "body": json.dumps({'id': id})
    }