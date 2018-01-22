// There should be two running ec2 instances
def listInstancesCmd = "aws --profile ${memory.awsProfile} --region ${memory.awsRegion} ec2 describe-instances --filters 'Name=tag:Context,Values=${memory.context}' 'Name=instance-state-name,Values=running' |jq -r '.Reservations[].Instances[].InstanceId'"
memory.awsCmd(listInstancesCmd)
def instances = memory.lastResponse?.split()
assert instances?.size() == 1