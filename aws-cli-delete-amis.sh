#!/usr/bin/env bash

# http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region
TMP_ALL_REGIONS=(us-east-1 us-east-2 us-west-1 us-west-2 ca-central-1 ap-south-1 ap-northeast-2 ap-southeast-1 ap-southeast-2 ap-northeast-1 eu-central-1 eu-west-1 eu-west-2 sa-east-1)
ALL_REGIONS=(us-east-1 us-east-2 us-west-2 ca-central-1 ap-south-1 ap-northeast-2 ap-southeast-1 ap-southeast-2 ap-northeast-1 eu-central-1 eu-west-1 eu-west-2 sa-east-1)

###########################################################
############# Confirm CLI Tools are installed #############
###########################################################

function _installAws
{
	_e "You need to install the AWS CLI library." "" "More information can be found here:" "http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-set-up.html"
}

command -v aws > /dev/null 2>&1 || { _installAws; }

AWS_CMD='aws'
AWS_EC2_CMD="$AWS_CMD ec2"
AWS_RESPONSE_CLEANER=" tr -d '\n'"

for REGION in "${ALL_REGIONS[@]}"; do
	for I in $($AWS_EC2_CMD --region $REGION describe-instances --query "Reservations[*].Instances[*].InstanceId" --output text); do
		echo "Found instance $I in region $REGION"
		$AWS_EC2_CMD --region $REGION modify-instance-attribute --instance-id $I --attribute disableApiTermination --value false
		$AWS_EC2_CMD --region $REGION terminate-instances --instance-ids $I
	done
done

exit 0
