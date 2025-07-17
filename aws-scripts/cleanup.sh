#!/bin/bash

# Chat2SVG EC2 资源清理脚本
set -e

# 配置参数
REGION="ap-southeast-2"
EBS_VOLUME_ID="vol-0b11fdfff6eb47a94"
EIP_ALLOCATION_ID="eipalloc-0f826806bd3938d95"

echo "🧹 开始清理Chat2SVG资源..."

# 读取实例信息
INFO_FILE="aws-scripts/.instance_info"
if [ -f "$INFO_FILE" ]; then
    source "$INFO_FILE"
    echo "📄 读取实例信息: $INSTANCE_ID"
else
    echo "❌ 未找到实例信息文件"
    echo "请手动指定实例ID:"
    read -p "Instance ID: " INSTANCE_ID
fi

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ 实例ID为空，退出"
    exit 1
fi

# 检查实例状态
echo "🔍 检查实例状态..."
INSTANCE_STATE=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text \
    --region $REGION 2>/dev/null || echo "not-found")

if [ "$INSTANCE_STATE" = "not-found" ]; then
    echo "❌ 实例不存在: $INSTANCE_ID"
    exit 1
fi

echo "实例状态: $INSTANCE_STATE"

# 解除EIP绑定
echo "🔗 解除EIP绑定..."
ASSOCIATION_ID=$(aws ec2 describe-addresses \
    --allocation-ids $EIP_ALLOCATION_ID \
    --query 'Addresses[0].AssociationId' \
    --output text \
    --region $REGION 2>/dev/null || echo "None")

if [ "$ASSOCIATION_ID" != "None" ] && [ -n "$ASSOCIATION_ID" ]; then
    aws ec2 disassociate-address \
        --association-id $ASSOCIATION_ID \
        --region $REGION
    echo "✅ EIP已解除绑定"
else
    echo "ℹ️  EIP未绑定"
fi

# 分离EBS卷
echo "💾 分离EBS卷..."
EBS_ATTACHMENT=$(aws ec2 describe-volumes \
    --volume-ids $EBS_VOLUME_ID \
    --query 'Volumes[0].Attachments[0].InstanceId' \
    --output text \
    --region $REGION 2>/dev/null || echo "None")

if [ "$EBS_ATTACHMENT" = "$INSTANCE_ID" ]; then
    aws ec2 detach-volume \
        --volume-id $EBS_VOLUME_ID \
        --instance-id $INSTANCE_ID \
        --region $REGION
    
    # 等待分离完成
    echo "⏳ 等待EBS分离..."
    while true; do
        VOLUME_STATE=$(aws ec2 describe-volumes \
            --volume-ids $EBS_VOLUME_ID \
            --query 'Volumes[0].State' \
            --output text \
            --region $REGION)
        
        if [ "$VOLUME_STATE" = "available" ]; then
            break
        fi
        sleep 5
    done
    echo "✅ EBS卷已分离"
else
    echo "ℹ️  EBS卷未挂载到此实例"
fi

# 终止实例
echo "🔄 终止实例..."
if [ "$INSTANCE_STATE" != "terminated" ] && [ "$INSTANCE_STATE" != "shutting-down" ]; then
    aws ec2 terminate-instances \
        --instance-ids $INSTANCE_ID \
        --region $REGION
    
    echo "⏳ 等待实例终止..."
    aws ec2 wait instance-terminated \
        --instance-ids $INSTANCE_ID \
        --region $REGION
    echo "✅ 实例已终止"
else
    echo "ℹ️  实例已终止或正在终止"
fi

# 取消Spot请求（如果存在）
if [ -n "$SPOT_REQUEST_ID" ]; then
    echo "💰 取消Spot请求..."
    SPOT_STATE=$(aws ec2 describe-spot-instance-requests \
        --spot-instance-request-ids $SPOT_REQUEST_ID \
        --query 'SpotInstanceRequests[0].State' \
        --output text \
        --region $REGION 2>/dev/null || echo "not-found")
    
    if [ "$SPOT_STATE" != "not-found" ] && [ "$SPOT_STATE" != "cancelled" ]; then
        aws ec2 cancel-spot-instance-requests \
            --spot-instance-request-ids $SPOT_REQUEST_ID \
            --region $REGION
        echo "✅ Spot请求已取消"
    fi
fi

# 清理本地文件
echo "🗑️  清理本地文件..."
if [ -f "$INFO_FILE" ]; then
    rm -f "$INFO_FILE"
    echo "✅ 删除实例信息文件"
fi

if [ -f "${KEY_NAME}.pem" ]; then
    echo "🔑 密钥文件: ${KEY_NAME}.pem (保留)"
fi

echo ""
echo "🎉 清理完成!"
echo "======================================"
echo "✅ 实例已终止: $INSTANCE_ID"
echo "✅ EIP已释放: $EIP_ALLOCATION_ID"
echo "✅ EBS卷已保留: $EBS_VOLUME_ID"
echo ""
echo "💡 EBS卷中的数据已保留，可重新部署"
echo "💡 重新部署命令: ./aws-scripts/deploy.sh" 