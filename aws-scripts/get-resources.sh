#!/bin/bash

echo "=== 获取AWS资源信息 ==="
echo ""

echo "1. 获取VPC列表："
aws ec2 describe-vpcs --output json | jq -r '.Vpcs[] | "\(.VpcId) - \(.Tags[]? | select(.Key=="Name") | .Value // "No Name") - Default: \(.IsDefault)"'

echo ""
echo "2. 获取ap-southeast-2b可用区的Subnet列表："
aws ec2 describe-subnets --filters "Name=availability-zone,Values=ap-southeast-2b" --output json | jq -r '.Subnets[] | "\(.SubnetId) - VPC: \(.VpcId) - AZ: \(.AvailabilityZone)"'

echo ""
echo "3. 获取Security Groups列表："
aws ec2 describe-security-groups --output json | jq -r '.SecurityGroups[] | "\(.GroupId) - \(.GroupName) - VPC: \(.VpcId)"'

echo ""
echo "4. 获取Key Pairs列表："
aws ec2 describe-key-pairs --output json | jq -r '.KeyPairs[] | "\(.KeyName)"'

echo ""
echo "基于以上信息，请提供："
echo "- VPC_ID=vpc-xxxxxx"
echo "- SUBNET_ID=subnet-xxxxxx (必须在ap-southeast-2b)" 
echo "- SECURITY_GROUP_ID=sg-xxxxxx"
echo "- KEY_NAME=your-key-name" 