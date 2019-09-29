# slack-channel-event-notifier

## Getting Started
* terraform apply
* setting slack app

To Create aws resource with Terraform.

```
$ pip install -r requirements.txt -t src/
$ terraform apply
```

To Create slack app in your workspace.

https://api.slack.com/apps

* On Incoming Webhooks page, get Webhook URLs
  - Set the environment variable of lambda function
* On Event Subscriptions page, set event api
  - Get api endpoint from lambda function page, and fill in request url form.
  - Set token posted at this time to environment variable of lambda function.
  - In the Subscribe to Workspace Events item, add `channel_create` and `channel_rename` to workspace event.