#!/bin/bash

# 🎯 EBS权限一键修复 - User Data脚本
# 
# 使用方法：复制此脚本内容到EC2实例的User Data中
# 
# 解决问题：
# ✅ EBS卷在不同实例间迁移的权限问题
# ✅ UID/GID不匹配导致的文件无法访问
# ✅ 脚本文件失去执行权限
# ✅ Conda、Git等工具权限错误
# 
# 使用场景：个人开发环境（会设置较宽松的权限）

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "🚀 开始自动修复EBS权限..."
sleep 30

# 第一步：自动挂载EBS卷
echo "📁 检测并挂载EBS卷..."

# 检测未挂载的EBS卷（排除根卷）
AVAILABLE_DEVICES=$(lsblk -dpno NAME,TYPE | grep disk | grep -v $(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's|/dev/||') | awk '{print $1}')

for DEVICE in $AVAILABLE_DEVICES; do
    echo "发现设备: $DEVICE"
    
    # 检查设备是否已经有文件系统
    if blkid "$DEVICE" > /dev/null 2>&1; then
        echo "$DEVICE 已有文件系统，准备挂载..."
        
        # 创建挂载点
        MOUNT_POINT="/mnt/ebs-$(basename $DEVICE)"
        mkdir -p "$MOUNT_POINT"
        
        # 挂载设备
        if mount "$DEVICE" "$MOUNT_POINT"; then
            echo "成功挂载 $DEVICE 到 $MOUNT_POINT"
            
            # 添加到fstab以便永久挂载
            UUID=$(blkid -s UUID -o value "$DEVICE")
            if [ -n "$UUID" ] && ! grep -q "$UUID" /etc/fstab; then
                echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
                echo "添加到fstab: UUID=$UUID"
            fi
            
            # 立即修复该挂载点的权限
            echo "修复 $MOUNT_POINT 权限..."
            chown -R ec2-user:ec2-user "$MOUNT_POINT" 2>/dev/null || true
            
        else
            echo "挂载 $DEVICE 失败"
        fi
    else
        echo "$DEVICE 没有文件系统，跳过"
    fi
done

# 第二步：修复权限问题
echo "🔧 开始修复权限..."

# 要修复的目录列表
DIRECTORIES_TO_FIX=(
    "/home/ec2-user"
    "/mnt/ebs*"  # 通配符会在下面展开
    "/opt/miniconda3"
    "/opt/conda"
)

# 修复函数
fix_permissions() {
    local DIR="$1"
    if [ -d "$DIR" ]; then
        echo "修复目录权限: $DIR"
        
        # 修复属主
        chown -R ec2-user:ec2-user "$DIR" 2>/dev/null || {
            echo "警告: 无法修改 $DIR 的属主"
        }
        
        # 修复基本权限
        find "$DIR" -type d -exec chmod 755 {} \; 2>/dev/null || true
        find "$DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
        
        # 修复可执行文件
        find "$DIR" -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true
        find "$DIR" -name "*.py" -exec chmod 755 {} \; 2>/dev/null || true
        find "$DIR" -name "run*" -type f -exec chmod 755 {} \; 2>/dev/null || true
        find "$DIR" -path "*/bin/*" -type f -exec chmod 755 {} \; 2>/dev/null || true
        
        echo "完成: $DIR"
    fi
}

# 修复指定目录
for DIR_PATTERN in "${DIRECTORIES_TO_FIX[@]}"; do
    if [[ "$DIR_PATTERN" == *"*"* ]]; then
        # 展开通配符
        for DIR in $DIR_PATTERN; do
            fix_permissions "$DIR"
        done
    else
        fix_permissions "$DIR_PATTERN"
    fi
done

# 第三步：特殊文件处理

# 修复SSH权限
if [ -d "/home/ec2-user/.ssh" ]; then
    echo "修复SSH权限"
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/* 2>/dev/null || true
fi

# 修复conda环境
for CONDA_PATH in "/opt/miniconda3" "/opt/conda" "/home/ec2-user/miniconda3" "/home/ec2-user/anaconda3"; do
    if [ -d "$CONDA_PATH" ]; then
        echo "修复Conda环境: $CONDA_PATH"
        chown -R ec2-user:ec2-user "$CONDA_PATH" 2>/dev/null || true
        find "$CONDA_PATH/bin" -type f -exec chmod 755 {} \; 2>/dev/null || true
    fi
done

# 第四步：创建便捷命令

# 创建权限修复脚本
cat > /home/ec2-user/fix-all-permissions.sh << 'EOF'
#!/bin/bash
echo "🔄 修复所有权限..."

# 修复home目录
sudo chown -R ec2-user:ec2-user /home/ec2-user 2>/dev/null || true

# 修复挂载的EBS卷
for mount_point in /mnt/ebs*; do
    if [ -d "$mount_point" ]; then
        echo "修复: $mount_point"
        sudo chown -R ec2-user:ec2-user "$mount_point" 2>/dev/null || true
        sudo find "$mount_point" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    fi
done

# 修复可执行文件
sudo find /home/ec2-user -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
sudo find /home/ec2-user -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

echo "✅ 权限修复完成！"
EOF

chmod 755 /home/ec2-user/fix-all-permissions.sh
chown ec2-user:ec2-user /home/ec2-user/fix-all-permissions.sh

# 添加便捷别名
cat >> /home/ec2-user/.bashrc << 'EOF'

# EBS权限管理别名 (由User Data自动添加)
alias fixperms='~/fix-all-permissions.sh'
alias fixowner='sudo chown -R ec2-user:ec2-user'
alias fixexec='sudo find . -name "*.sh" -exec chmod +x {} \;'
alias lsebs='df -h | grep /mnt'

EOF

chown ec2-user:ec2-user /home/ec2-user/.bashrc

echo "✅ EBS权限修复完成！登录后可使用以下命令："
echo "   fixperms  - 修复所有权限"
echo "   fixowner  - 修复文件属主" 
echo "   fixexec   - 修复执行权限"
echo "   lsebs     - 查看EBS挂载状态"
echo "📝 详细日志: /var/log/user-data.log" 