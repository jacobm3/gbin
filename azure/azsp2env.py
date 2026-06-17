#!/usr/bin/python3

import json
import sys

data = json.load(sys.stdin)
print('export ARM_TENANT_ID=%s' % data["tenant"])
print('export ARM_CLIENT_ID=%s' % data["appId"])
print('export ARM_CLIENT_SECRET=%s' % data["password"])
print('export ARM_SUBSCRIPTION_ID=')


