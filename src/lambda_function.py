# -*- coding: utf-8 -*-
import os
import requests
import json
import ast

SLACK_VERIFICATION_TOKEN = os.environ["SLACK_VERIFICATION_TOKEN"]
WEB_HOOK_URL = os.environ["WEB_HOOK_URL"]


def description_of(event_type):
    if event_type == 'channel_created':
        return '作成されました'
    elif event_type == 'channel_rename':
        return '名前が変更されました'
    else:
        raise Exception('Unexcepted EventType: {}'.format(event_type))


def is_verify_token(event):
    token = event.get('token')
    if token != SLACK_VERIFICATION_TOKEN:
        return False

    return True


def lambda_handler(event, context):
    # url verification
    body = json.loads(event.get('body'))
    if 'challenge' in body.keys():
        return {
            'statusCode': 200,
            'body': json.dumps(
                {
                    'challeng': body['challenge']
                }
            )
        }

    if not is_verify_token(body):
        raise Exception('Unexpected Token.')

    event_type = body['event']['type']
    channel = body['event']['channel']['name']

    text = 'チャンネルが{event_msg}: #{channel}'.format(event_msg=description_of(event_type), channel=channel)
    payload = {
        'text': text
    }
    requests.post(WEB_HOOK_URL,  data=json.dumps(payload))

    return {
        'statusCode': 200
    }
