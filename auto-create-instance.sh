#!/bin/bash

# 🚀 自动创建EC2实例并挂载EBS卷
# 使用AWS CLI实现一键部署

set -e

# 配置参数 - 根据您的需求修改
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2 AMI (根据地区调整)
INSTANCE_TYPE="t3.medium"
KEY_NAME="your-key-pair"  # 替换为您的密钥对名称
SECURITY_GROUP="sg-xxxxxxxxx"  # 替换为您的安全组ID
SUBNET_ID="subnet-xxxxxxxxx"  # 替换为您的子网ID

# EBS配置
EBS_VOLUME_ID="vol-xxxxxxxxx"  # 现有EBS卷ID，如果为空则创建新卷
EBS_SIZE=100  # GB，仅在创建新卷时使用
EBS_DEVICE="/dev/sdf"  # 挂载设备名

echo "🎯 开始自动化部署..."

# 检查是否有现有EBS卷
if [ -z "$EBS_VOLUME_ID" ]; then
    echo "📦 创建新的EBS卷..."
    EBS_VOLUME_ID=$(aws ec2 create-volume \
        --size $EBS_SIZE \
        --volume-type gp3 \
        --availability-zone $(aws ec2 describe-subnets --subnet-ids $SUBNET_ID --query 'Subnets[0].AvailabilityZone' --output text) \
        --query 'VolumeId' --output text)
    
    echo "✅ 创建EBS卷: $EBS_VOLUME_ID"
    
    # 等待卷创建完成
    echo "⏳ 等待EBS卷可用..."
    aws ec2 wait volume-available --volume-ids $EBS_VOLUME_ID
fi

# 方案1：创建实例时直接附加EBS
echo "🖥️ 创建实例并附加EBS卷..."

# 创建block-device-mappings JSON
cat > /tmp/block-devices.json << EOF
[
  {
    "DeviceName": "/dev/xvda",
    "Ebs": {
      "VolumeSize": 20,
      "VolumeType": "gp3",
      "DeleteOnTermination": true
    }
  },
  {
    "DeviceName": "$EBS_DEVICE",
    "Ebs": {
      "VolumeId": "$EBS_VOLUME_ID",
      "DeleteOnTermination": false
    }
  }
]
EOF

# 创建实例
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP \
    --subnet-id $SUBNET_ID \
    --block-device-mappings file:///tmp/block-devices.json \
    --user-data file://ebs-auto-fix.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Chat2SVG-Auto}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ 实例创建成功: $INSTANCE_ID"

# 等待实例启动
echo "⏳ 等待实例启动..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# 获取实例信息
INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "🎉 部署完成！"
echo "📋 实例信息："
echo "   实例ID: $INSTANCE_ID"
echo "   公网IP: $INSTANCE_IP"
echo "   EBS卷: $EBS_VOLUME_ID"
echo ""
echo "🔗 SSH连接:"
echo "   ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$INSTANCE_IP"
echo ""
echo "📝 User Data日志:"
echo "   sudo tail -f /var/log/user-data.log"

# 清理临时文件
rm -f /tmp/block-devices.json

echo "✅ 脚本执行完成！" 