#!/bin/bash

# Chat2SVG EC2 初始化脚本
LOG_FILE="/var/log/user-data.log"
EBS_VOLUME_ID="vol-0b11fdfff6eb47a94"
MOUNT_POINT="/opt/chat2svg-env"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "=== 开始初始化 ==="

# 等待EBS卷attach完成（deploy.sh异步执行）
log "1. 检验EBS卷attach状态..."
mkdir -p ${MOUNT_POINT}

RETRY_COUNT=0
MAX_RETRIES=12  # 12次 * 5秒 = 60秒最大等待时间
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if [ -b /dev/xvdf ]; then
        log "✅ EBS卷已成功attach: /dev/xvdf"
        break
    fi
    log "⏳ 等待EBS卷attach... ($((RETRY_COUNT + 1))/$MAX_RETRIES) - 5秒后重试"
    sleep 5
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log "❌ ERROR: EBS卷在60秒内未成功attach"
    log "❌ 可能原因：deploy.sh的attach命令失败，或EBS卷已被其他实例使用"
    log "❌ 请手动检查EBS卷状态：aws ec2 describe-volumes --volume-ids $EBS_VOLUME_ID"
    exit 1
fi

# 挂载EBS卷到指定目录
if mount /dev/xvdf ${MOUNT_POINT}; then
    log "EBS卷挂载成功: ${MOUNT_POINT}"
    UUID=$(blkid -s UUID -o value /dev/xvdf)
    if [ -n "$UUID" ] && ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=${UUID} ${MOUNT_POINT} ext4 defaults,nofail 0 2" >> /etc/fstab
        log "已添加到fstab"
    fi
else
    log "❌ ERROR: EBS卷挂载失败"
    exit 1
fi

# 2. 修复文件权限
log "2. 修复文件权限..."
EC2_USER_UID=$(id -u ec2-user)
EC2_USER_GID=$(id -g ec2-user)
log "修复文件权限 UID:$EC2_USER_UID GID:$EC2_USER_GID"

if [ -d "${MOUNT_POINT}" ]; then
    find ${MOUNT_POINT} -uid 1000 -exec chown $EC2_USER_UID:$EC2_USER_GID {} \; 2>/dev/null || true
    
    # 修复特定目录权限
    for dir in .ssh projects miniconda3; do
        if [ -d "${MOUNT_POINT}/$dir" ]; then
            chown -R $EC2_USER_UID:$EC2_USER_GID ${MOUNT_POINT}/$dir
            log "修复 $dir 权限"
        fi
    done
    
    # SSH权限
    if [ -d "${MOUNT_POINT}/.ssh" ]; then
        chmod 700 ${MOUNT_POINT}/.ssh
        chmod 600 ${MOUNT_POINT}/.ssh/id_rsa 2>/dev/null || true
        chmod 644 ${MOUNT_POINT}/.ssh/id_rsa.pub 2>/dev/null || true
    fi
fi

# 3. 创建软链接
log "3. 创建软链接..."
sudo -u ec2-user bash << 'EOF'
create_link() {
    local src="$1"
    local dst="$2"
    local desc="$3"
    
    if [ -e "$src" ]; then
        rm -rf "$dst" 2>/dev/null || true
        ln -s "$src" "$dst"
        echo "✅ 创建 $desc 软连接"
    fi
}

create_link "/opt/chat2svg-env/miniconda3" "/home/ec2-user/miniconda3" "Miniconda3"
create_link "/opt/chat2svg-env/projects/Chat2SVG" "/home/ec2-user/Chat2SVG" "项目"
create_link "/opt/chat2svg-env/.gitconfig" "/home/ec2-user/.gitconfig" "Git配置"

# 处理SSH配置 - 不做软连接，而是复制EBS上的密钥到标准.ssh目录
log "处理SSH配置..."
if [ -d "/opt/chat2svg-env/.ssh" ]; then
    # 确保标准.ssh目录存在且权限正确
    mkdir -p /home/ec2-user/.ssh
    chmod 700 /home/ec2-user/.ssh
    
    # 从EBS复制Git等需要的私钥（保持authorized_keys不变）
    if [ -f "/opt/chat2svg-env/.ssh/id_rsa" ]; then
        cp /opt/chat2svg-env/.ssh/id_rsa /home/ec2-user/.ssh/
        chmod 600 /home/ec2-user/.ssh/id_rsa
        log "✅ 复制SSH私钥"
    fi
    
    if [ -f "/opt/chat2svg-env/.ssh/id_rsa.pub" ]; then
        cp /opt/chat2svg-env/.ssh/id_rsa.pub /home/ec2-user/.ssh/
        chmod 644 /home/ec2-user/.ssh/id_rsa.pub
        log "✅ 复制SSH公钥"
    fi
    
    # 复制其他可能需要的SSH配置文件
    if [ -f "/opt/chat2svg-env/.ssh/config" ]; then
        cp /opt/chat2svg-env/.ssh/config /home/ec2-user/.ssh/
        chmod 600 /home/ec2-user/.ssh/config
        log "✅ 复制SSH配置文件"
    fi
    
    # 设置所有者
    chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    log "✅ SSH配置完成 - 保持authorized_keys，复制EBS密钥"
else
    log "⚠️  EBS上未找到.ssh目录"
fi

# 配置conda环境
if [ -f "/home/ec2-user/miniconda3/etc/profile.d/conda.sh" ]; then
    if ! grep -q "conda initialize" /home/ec2-user/.bashrc; then
        cat >> /home/ec2-user/.bashrc << 'CONDA_INIT'

# >>> conda initialize >>>
__conda_setup="$('/home/ec2-user/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/ec2-user/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/ec2-user/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/ec2-user/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
CONDA_INIT
        echo "✅ 配置conda环境"
    fi
fi
EOF

# 5. 创建快速启动脚本
log "5. 创建快速启动脚本..."
sudo -u ec2-user cat > /home/ec2-user/start-chat2svg.sh << 'SCRIPT'
#!/bin/bash
echo "🚀 Chat2SVG Environment Quick Start"
echo "======================================"

# 检查EBS挂载
if ! mountpoint -q /opt/chat2svg-env; then
    echo "❌ EBS未挂载"
    exit 1
fi

# 激活conda环境
if [ -f "/home/ec2-user/miniconda3/etc/profile.d/conda.sh" ]; then
    source /home/ec2-user/miniconda3/etc/profile.d/conda.sh
    conda activate chat2svg
    echo "✅ Conda环境: chat2svg"
else
    echo "❌ Conda未找到"
    exit 1
fi

# 进入项目目录
if [ -d "/home/ec2-user/Chat2SVG" ]; then
    cd /home/ec2-user/Chat2SVG
    echo "✅ 项目目录: $(pwd)"
else
    echo "❌ 项目未找到"
    exit 1
fi

# 显示状态
echo "✅ Git: $(git config user.name) <$(git config user.email)>"
echo "✅ GPU状态:"
nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "GPU未就绪"

echo ""
echo "🎯 可运行命令:"
echo "   git status"
echo "   nvidia-smi"
echo "   conda env list"
SCRIPT

chmod +x /home/ec2-user/start-chat2svg.sh

# 6. 安装系统依赖
log "6. 安装系统依赖..."
dnf update -y
dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) mesa-libGL mesa-libGL-devel

# 7. GPU驱动配置
log "7. GPU驱动配置..."
if lspci | grep -i nvidia > /dev/null; then
    log "配置NVIDIA驱动..."
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
    dnf install -y nvidia-driver nvidia-driver-cuda cuda-toolkit-12-6
    echo 'export PATH=/usr/local/cuda-12.6/bin:$PATH' >> /home/ec2-user/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH' >> /home/ec2-user/.bashrc
fi

# 8. 完成标记
log "8. 完成标记..."
echo "Chat2SVG initialized at $(date)" > /opt/chat2svg-env/.setup_complete
chown ec2-user:ec2-user /opt/chat2svg-env/.setup_complete

log "=== 初始化完成 ==="
log "实例类型: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
log "实例ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)" 