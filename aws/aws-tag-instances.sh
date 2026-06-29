
# ---------------------------------------------------------------------------
# aws-tag-instances.sh
#
# What it does:
#   Adds (or overwrites) two tags on a fixed list of EC2 instances:
#     owner = jmartinson@hashicorp.com
#     TTL   = 2880   (minutes; here 2880 = 48 hours)
#   Tags are key/value labels AWS uses for ownership, billing, and automated
#   cleanup. A "TTL" tag is commonly read by a janitor/reaper job that deletes
#   resources older than the TTL.
#
# How to run:
#   ./aws-tag-instances.sh
#   (No arguments. The instance IDs and tag values are hard-coded below.
#    Edit the --resources list to tag a different set of instances.)
#
# Prerequisites:
#   - The AWS CLI v2 installed and on your PATH.
#   - Working AWS credentials/region that allow ec2:CreateTags.
# ---------------------------------------------------------------------------

# create-tags applies the same tags to every instance listed after --resources.
#   --resources : the EC2 instance IDs (i-xxxx...) to tag. The backslashes (\)
#                 at the end of each line just continue one long command across
#                 several lines so it is easier to read.
aws ec2 create-tags --resources i-0aff34473f1118c17 i-0b8450b3f6e0a3381 i-0602f2e08b0847a2b \
 i-09adcc5f4ee0078c3 i-06efb03842bb108c5 i-0c07f9617d46569c5 i-049708d5d94dc64d3 \
 i-05af768c8b053a510 i-0349eb67a265e774c \
--tags Key=owner,Value=jmartinson@hashicorp.com Key=TTL,Value=2880
# --tags lists the tags to set, each as Key=...,Value=... pairs. If a tag key
# already exists on an instance, its value is replaced (create-tags is an
# upsert: it creates the tag if missing, otherwise updates it).


