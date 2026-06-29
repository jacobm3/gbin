#!/usr/bin/python3
#
# azsp2env.py — convert an Azure service principal (SP) JSON blob into the
# `export VAR=value` shell lines that Terraform's azurerm provider expects.
#
# WHAT IT DOES
#   Reads the JSON that `az ad sp create-for-rbac` prints, and emits four
#   `export ARM_*` lines. Terraform (and other ARM tooling) authenticates to
#   Azure by reading those ARM_* environment variables.
#
# HOW TO RUN
#   Pipe the service-principal JSON in on stdin and `eval` the output so the
#   exports land in your CURRENT shell (a plain run only prints them):
#
#     az ad sp create-for-rbac --name myapp -o json | ./azsp2env.py
#     eval "$(az ad sp create-for-rbac --name myapp -o json | ./azsp2env.py)"
#
#   The expected input JSON looks like:
#     { "appId": "...", "password": "...", "tenant": "...", "displayName": "..." }
#
# PREREQUISITES
#   - python3 (only the standard library is used; nothing to pip install).
#   - The Azure CLI (`az`) to produce the input JSON, though any matching JSON works.
#
# NOTE
#   ARM_SUBSCRIPTION_ID is intentionally left blank — the SP JSON doesn't
#   include it. Fill it in yourself (e.g. from `az account show`).

# json: parse the service-principal text into a Python dict.
# sys:  gives us sys.stdin, the piped-in input stream.
import json
import sys

# Read everything piped into stdin and parse it as JSON into a dict named `data`.
# json.load (not json.loads) takes a file-like object; sys.stdin is one.
data = json.load(sys.stdin)
# Emit each export line. The `%s` is replaced by the matching JSON field:
#   tenant   -> ARM_TENANT_ID      (the Azure AD tenant/directory the SP lives in)
#   appId    -> ARM_CLIENT_ID      (the SP's application/client ID — its "username")
#   password -> ARM_CLIENT_SECRET  (the SP's secret — its "password"; keep private)
print('export ARM_TENANT_ID=%s' % data["tenant"])
print('export ARM_CLIENT_ID=%s' % data["appId"])
print('export ARM_CLIENT_SECRET=%s' % data["password"])
# Subscription ID isn't part of the SP JSON, so print an empty assignment as a
# placeholder/reminder for the user to fill in (e.g. from `az account show`).
print('export ARM_SUBSCRIPTION_ID=')


