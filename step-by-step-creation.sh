#!/bin/bash

# 🔧 分步骤创建实例：创建→停止→挂载EBS→启动
# 实现您提到的精确控制流程

set -e

# 配置参数
AMI_ID="ami-0c02fb55956c7d316"
INSTANCE_TYPE="t3.medium"
KEY_NAME="your-key-pair"
SECURITY_GROUP="sg-xxxxxxxxx"
SUBNET_ID="subnet-xxxxxxxxx"
EBS_VOLUME_ID="vol-xxxxxxxxx"  # 现有EBS卷ID

echo "🔧 开始分步骤创建..."

# 步骤1：创建实例（会自动启动）
echo "1️⃣ 创建实例..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP \
    --subnet-id $SUBNET_ID \
    --user-data file://ebs-auto-fix.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Chat2SVG-StepByStep}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "✅ 实例创建: $INSTANCE_ID"

# 步骤2：等待实例启动后立即停止
echo "2️⃣ 等待实例启动后停止..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "⏸️ 停止实例..."
aws ec2 stop-instances --instance-ids $INSTANCE_ID > /dev/null
aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID
echo "✅ 实例已停止"

# 步骤3：挂载EBS卷
echo "3️⃣ 挂载EBS卷..."
aws ec2 attach-volume \
    --volume-id $EBS_VOLUME_ID \
    --instance-id $INSTANCE_ID \
    --device /dev/sdf

# 等待挂载完成
echo "⏳ 等待EBS挂载完成..."
aws ec2 wait volume-in-use --volume-ids $EBS_VOLUME_ID
echo "✅ EBS卷挂载完成"

# 步骤4：启动实例（这时才会执行User Data）
echo "4️⃣ 启动实例..."
aws ec2 start-instances --instance-ids $INSTANCE_ID > /dev/null
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# 获取实例信息
INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "🎉 分步骤创建完成！"
echo "📋 实例信息："
echo "   实例ID: $INSTANCE_ID"
echo "   公网IP: $INSTANCE_IP"
echo "   EBS卷: $EBS_VOLUME_ID"
echo ""
echo "💡 重要说明："
echo "   - 实例在第2次启动时才执行User Data"
echo "   - EBS卷已在启动前挂载，User Data会自动处理权限"
echo ""
echo "🔗 SSH连接:"
echo "   ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$INSTANCE_IP" 