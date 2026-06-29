# ---------------------------------------------------------------------------
# aws-search-ec2-by-name.sh
#
# What it does:
#   Lists the public IP addresses of EC2 instances whose "Name" tag matches
#   a fixed wildcard pattern (jacobm-consul-poc-*).
#
# How to run:
#   ./aws-search-ec2-by-name.sh
#   (No arguments. The search pattern is hard-coded below. Edit the Values=
#    pattern if you want to search for a different set of instances.)
#
# Prerequisites:
#   - The AWS CLI v2 installed and on your PATH.
#   - Working AWS credentials/region (e.g. via `aws configure`, env vars,
#     or an instance/SSO role) that allow ec2:DescribeInstances.
# ---------------------------------------------------------------------------

# Ask AWS to describe EC2 instances and print the result.
#   --output=text  : print plain text (one value per line) instead of JSON,
#                    which is easy to read or pipe into other commands.
#   --filters      : only return instances matching this filter. Here we match
#                    the "Name" tag against the wildcard jacobm-consul-poc-*
#                    (the trailing * means "anything after that prefix").
aws ec2 describe-instances --output=text --filters 'Name=tag:Name,Values=jacobm-consul-poc-*' \
 --query "Reservations[*].Instances[*].PublicIpAddress"
# --query uses JMESPath (AWS's JSON query language) to pull out just the field
# we care about. describe-instances groups instances inside "Reservations",
# and each reservation holds an "Instances" list, so we walk
# Reservations -> Instances -> PublicIpAddress to get only the public IPs.
