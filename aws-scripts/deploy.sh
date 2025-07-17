#!/bin/bash

# 硬编码配置 - 请根据get-resources.sh的输出填写
VPC_ID="vpc-072194dcb5a3fffe7"  # 修改为你的VPC ID
SUBNET_ID="subnet-0a0fd5a11200a76ce"  # 填写ap-southeast-2b的Subnet ID
SECURITY_GROUP_ID="sg-01648b9589c269323"  # 填写Security Group ID (使用default)
KEY_NAME="LinuxSydneyKP"  # 填写Key Pair名称

# 固定配置
REGION="ap-southeast-2"
AVAILABILITY_ZONE="ap-southeast-2b"
EBS_VOLUME_ID="vol-0b11fdfff6eb47a94"
ELASTIC_IP_ALLOC_ID="eipalloc-0f826806bd3938d95"
INSTANCE_TYPE="g4dn.xlarge"
AMI_ID="ami-01e4eae0ef72572e5"  # Deep Learning Base OSS Nvidia Driver GPU AMI (Amazon Linux 2023) x86_64

echo "=== Chat2SVG AWS EC2 部署 ==="
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo "Security Group: $SECURITY_GROUP_ID"
echo "Key: $KEY_NAME"
echo ""

# 编码user-data脚本
USER_DATA=$(base64 -i user-data.sh)

echo "1. 创建Spot实例请求..."
SPOT_REQUEST_ID=$(aws ec2 request-spot-instances \
    --spot-price "1.0" \
    --launch-specification "{
        \"ImageId\": \"$AMI_ID\",
        \"InstanceType\": \"$INSTANCE_TYPE\",
        \"KeyName\": \"$KEY_NAME\",
        \"SecurityGroupIds\": [\"$SECURITY_GROUP_ID\"],
        \"SubnetId\": \"$SUBNET_ID\",
        \"UserData\": \"$USER_DATA\",
        \"Placement\": {
            \"AvailabilityZone\": \"$AVAILABILITY_ZONE\"
        }
    }" \
    --query 'SpotInstanceRequests[0].SpotInstanceRequestId' \
    --output text)

if [ "$SPOT_REQUEST_ID" = "None" ] || [ -z "$SPOT_REQUEST_ID" ]; then
    echo "错误：创建Spot实例请求失败"
    exit 1
fi

echo "Spot请求ID: $SPOT_REQUEST_ID"

# 等待实例创建
echo "2. 等待实例创建..."
while true; do
    INSTANCE_ID=$(aws ec2 describe-spot-instance-requests \
        --spot-instance-request-ids $SPOT_REQUEST_ID \
        --query 'SpotInstanceRequests[0].InstanceId' \
        --output text)
    
    if [ "$INSTANCE_ID" != "None" ] && [ ! -z "$INSTANCE_ID" ]; then
        break
    fi
    
    echo "等待中..."
    sleep 10
done

echo "实例ID: $INSTANCE_ID"

# 等待实例启动
echo "3. 等待实例启动..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "实例已启动"

# 挂载EBS卷
echo "4. 挂载EBS卷..."
aws ec2 attach-volume \
    --volume-id $EBS_VOLUME_ID \
    --instance-id $INSTANCE_ID \
    --device /dev/xvdf
echo "EBS挂载命令已发送"

# 关联弹性IP
echo "5. 关联弹性IP..."
aws ec2 associate-address \
    --instance-id $INSTANCE_ID \
    --allocation-id $ELASTIC_IP_ALLOC_ID
echo "弹性IP关联完成"

# 等待user-data完成初始化
echo "6. 等待初始化完成..."
echo "user-data将检验EBS挂载并完成环境配置..."
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
echo "初始化完成"

# 检查user-data日志
echo "7. 检查初始化日志..."
if ! ssh -i ~/.ssh/$KEY_NAME.pem -o StrictHostKeyChecking=no ec2-user@13.236.0.80 "tail -20 /var/log/user-data.log" 2>/dev/null; then
    echo "注意：无法获取初始化日志，可能还在进行中"
    echo "请稍后手动检查：ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@13.236.0.80"
fi

# 保存实例信息
echo "8. 保存部署信息..."
cat > instance-info.txt << EOF
INSTANCE_ID=$INSTANCE_ID
SPOT_REQUEST_ID=$SPOT_REQUEST_ID
PUBLIC_IP=13.236.0.80
DEPLOY_TIME=$(date)
EOF

echo ""
echo "=== 部署完成 ==="
echo "实例ID: $INSTANCE_ID"
echo "公网IP: 13.236.0.80"
echo "SSH连接: ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@13.236.0.80"
echo ""
echo "实例信息已保存到 instance-info.txt"
echo "使用 ./cleanup.sh 清理资源" 