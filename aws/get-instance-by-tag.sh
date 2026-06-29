# ---------------------------------------------------------------------------
# get-instance-by-tag.sh
#
# What it does:
#   Prints the public DNS name(s) of running EC2 instances that are owned by
#   jmartinson@hashicorp.com AND whose "Name" tag matches the argument you pass.
#
# How to run:
#   ./get-instance-by-tag.sh <name-tag-value>
#   Example: ./get-instance-by-tag.sh my-consul-server
#   You can use AWS wildcards in the value, e.g. 'my-consul-*'.
#
# Prerequisites:
#   - The AWS CLI v2 and jq (a command-line JSON parser) installed.
#   - Working AWS credentials/region that allow ec2:DescribeInstances.
# ---------------------------------------------------------------------------

# Describe instances, narrowing the results with three --filters (all must match):
#   tag:owner            -> only instances owned by this person
#   instance-state-name  -> only instances currently "running"
#   tag:Name             -> only instances whose Name tag matches "$1",
#                           the first argument given on the command line.
aws ec2 describe-instances --filters "Name=tag:owner,Values=jmartinson@hashicorp.com" \
 "Name=instance-state-name,Values=running" "Name=tag:Name,Values=$1" \
 | jq -r .Reservations[].Instances[].PublicDnsName
# Pipe the JSON output into jq to extract just the public DNS name.
#   -r   : "raw" output (print the string without surrounding quotes).
#   The path .Reservations[].Instances[].PublicDnsName walks the JSON: every
#   reservation -> every instance inside it -> that instance's PublicDnsName.
#   The empty [] means "for each element of this array".

