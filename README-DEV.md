# 开发环境配置

## Git和SSH持久化配置（基于EBS）

为了在使用Spot实例时保持Git和SSH配置，我们将这些配置保存在EBS上。

### 首次配置（已完成）

```bash
# 设置Git全局用户信息
git config --global user.name "huanbasara"
git config --global user.email "huanbasara@gmail.com"

# 在EBS上生成SSH密钥（持久化保存）
mkdir -p /opt/chat2svg-env/.ssh
ssh-keygen -t rsa -b 4096 -C "huanbasara@gmail.com" -f /opt/chat2svg-env/.ssh/id_rsa -N ""

# 设置正确权限
chmod 700 /opt/chat2svg-env/.ssh
chmod 600 /opt/chat2svg-env/.ssh/id_rsa
chmod 644 /opt/chat2svg-env/.ssh/id_rsa.pub

# 创建符号链接到home目录
rm -rf ~/.ssh && ln -s /opt/chat2svg-env/.ssh ~/.ssh
mv ~/.gitconfig /opt/chat2svg-env/ && ln -s /opt/chat2svg-env/.gitconfig ~/.gitconfig
```

### SSH公钥（添加到GitHub）

```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCt25q3MYSS4+CjIIG9weGq9mXYv86Ff4gEGricH6OUKjDJ4qpt4OakU26ZjOrqpNwfcR4WqDBbs1/pETMioxZnjDRji193pcEwjJcUHBi0YPErZXivVne7RJBjRp4H3vF8LwFrvsRa6cy3McRUx/zVL1oqbW2GkY1VbRbgou96Y10+c91jVOc4Nka9BvdzCGO9BYar/FRpw5SnH6ExCAKilHvuiAASt7DdXtZvupA/WXTvyBlRInV9zDqtZN20V8BAzaQIqvXJta+b4i5t8edhm9oCL8Q9NLP0CIAPz1LJgcSW+f3uDziytNboFqJ5kl3a6KgCYgYYydICRWmsrz/ayMTF0DcfWffFpCZvufn6s7XR8R7cG9iQg2AvnApjQLIDjX13D3cMhZhXWRxk0dEaqZRaJzYD30Bi+kO/nY2rXbnwPuz5wQElH6Y0qsdtSY35R1+Pf0nStfXCeaN55XzlHr4VsGv1bwTxQjgGiebYlkaNJF4+bFGOjnOwtN76shoCJ4L7+HtQiQWiwrx5uLKRbV77S4DjPAxCVq3+daEX1Sjrn9vXrfqhgvjeOp3b7SShr+BOIthXuVe2CIF/Id/STp551DaUT0319uQmvfvdtbFrOPAxumEi4XYAGPlJ3l5OVElcHmEFxyMpzo7UJhKgAiHvUBGwNvgDedl2AdK2LQ== huanbasara@gmail.com
```

请将此公钥添加到GitHub：https://github.com/settings/keys

### 新Spot实例初始化

当启动新的Spot实例时，运行以下自动配置脚本：

```bash
# 挂载EBS后，运行自动配置脚本
/opt/chat2svg-env/setup-git-ssh.sh
```

这个脚本会：
1. 创建SSH和Git配置的符号链接
2. 设置正确的文件权限
3. 启动SSH agent并添加密钥
4. 显示当前配置状态

## 仓库配置

```bash
# 更改远程URL为SSH格式
git remote set-url origin git@github.com:huanbasara/Chat2SVG.git

# 验证远程仓库
git remote -v
```

## 分支操作

```bash
# 获取远程分支信息
git fetch origin

# 切换到dev分支
git checkout -b dev origin/dev

# 查看分支状态
git branch -vv

# 推送到当前分支
git push
```

## 环境配置

### 1. 安装Miniconda

```bash
# 下载并安装Miniconda
cd ~
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3

# 初始化conda
$HOME/miniconda3/bin/conda init bash
source ~/.bashrc
```

### 2. 创建项目环境

```bash
# 创建Python 3.10环境
conda create --name chat2svg python=3.10 -y
conda activate chat2svg

# 安装PyTorch (CPU版本)
conda install pytorch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 cpuonly -c pytorch -y

# 安装SAM
pip install git+https://github.com/facebookresearch/segment-anything.git

# 安装其他依赖
pip install -r requirements.txt
```

### 3. 编译工具和系统依赖

```bash
# 安装编译工具
sudo yum groupinstall -y "Development Tools"

# 安装OpenCV依赖（解决libGL.so.1缺失问题）
sudo yum install -y mesa-libGL mesa-libGL-devel

# 安装cmake和ffmpeg
conda install -y -c anaconda cmake
conda install -y -c conda-forge ffmpeg
```

### 4. 安装diffvg

```bash
# 克隆并安装diffvg
git clone https://github.com/BachiLi/diffvg.git
cd diffvg
git submodule update --init --recursive
pip install svgwrite svgpathtools cssutils torch-tools
python setup.py install
cd ..
```

### 5. 安装picosvg

```bash
# 克隆并安装picosvg
git clone https://github.com/googlefonts/picosvg.git
cd picosvg
pip install -e .
cd ..
```

### 6. 配置API密钥

```bash
# 创建.env文件并配置API密钥
cat > .env << 'EOF'
OPENAI_API_KEY=your_anthropic_api_key_here
BACKEND=Claude
EOF
```

### 7. GPU支持配置 (G4DN实例)

#### 7.1 检查GPU硬件

```bash
# 检查NVIDIA GPU设备
lspci | grep -i nvidia
# 预期输出: 00:1e.0 3D controller: NVIDIA Corporation TU104GL [Tesla T4] (rev a1)
```

#### 7.2 安装NVIDIA驱动和CUDA

```bash
# 安装kernel开发包
sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)

# 添加NVIDIA CUDA repository
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo

# 清理并重建dnf缓存
sudo dnf clean all && sudo dnf makecache

# 安装NVIDIA驱动和CUDA集成包
sudo dnf install -y nvidia-driver nvidia-driver-cuda

# 安装CUDA工具包12.6版本
sudo dnf install -y cuda-toolkit-12-6
```

#### 7.3 配置CUDA环境变量

```bash
# 添加CUDA路径到环境变量
echo 'export PATH=/usr/local/cuda-12.6/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

# 重新加载环境变量
source ~/.bashrc
```

#### 7.4 重启实例激活驱动

**重要：** 需要通过AWS控制台重启EC2实例以激活NVIDIA内核模块：
1. 进入AWS EC2控制台
2. 选择实例 → 实例状态 → 重启实例
3. 等待实例重启完成后重新连接

#### 7.5 验证NVIDIA驱动和CUDA安装

```bash
# 检查NVIDIA驱动状态
nvidia-smi

# 预期输出显示Tesla T4 GPU信息和驱动版本

# 检查CUDA版本
nvcc --version

# 预期输出显示CUDA编译器版本信息
```

#### 7.6 重新安装PyTorch CUDA版本

```bash
# 激活conda环境
conda activate chat2svg

# 卸载CPU版本的PyTorch
pip uninstall torch torchvision torchaudio -y

# 安装CUDA版本的PyTorch
conda install pytorch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 pytorch-cuda=11.8 -c pytorch -c nvidia -y

# 验证CUDA支持
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}'); print(f'GPU count: {torch.cuda.device_count()}')"
```

#### 7.7 恢复GPU优化代码

如果之前为了CPU兼容性修改过代码，需要恢复GPU优化设置：
- 恢复 `load_model()` 函数中的float16精度
- 启用 `enable_model_cpu_offload()` 
- 确保模型使用GPU加速

## 项目结构

### 8. EBS存储优化配置 (为Spot实例做准备)

#### 8.1 创建和挂载EBS卷

**目的：** 将所有依赖安装在可分离的EBS卷上，以便在Spot实例之间复用，降低成本。

```bash
# 1. 在AWS控制台创建EBS卷
# - 大小: 70GB
# - 类型: gp3 (通用SSD)
# - 可用区: 与EC2实例相同
# - 记录卷ID (例如: vol-0b4324ee9a710179f)

# 2. 挂载EBS卷到EC2实例
# 在AWS控制台: EC2 → 卷 → 操作 → 附加卷
# - 实例: 选择你的EC2实例
# - 设备名: /dev/sdf

# 3. 格式化和挂载EBS卷
# 检查新设备
lsblk

# 格式化为ext4文件系统
sudo mkfs -t ext4 /dev/nvme2n1

# 创建挂载点
sudo mkdir -p /opt/chat2svg-env

# 挂载EBS卷
sudo mount /dev/nvme2n1 /opt/chat2svg-env

# 修改权限
sudo chown -R ec2-user:ec2-user /opt/chat2svg-env
```

#### 8.2 配置自动挂载

```bash
# 获取UUID
sudo blkid /dev/nvme2n1
# 输出例如: /dev/nvme2n1: UUID="084d9ec5-9a93-4137-83b2-c5f5e9322981" TYPE="ext4"

# 配置自动挂载 (使用你的实际UUID)
echo "UUID=084d9ec5-9a93-4137-83b2-c5f5e9322981 /opt/chat2svg-env ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# 验证自动挂载配置
sudo mount -a
```

#### 8.3 在EBS上安装Miniconda

```bash
# 下载并安装Miniconda到EBS卷
cd /opt/chat2svg-env
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/chat2svg-env/miniconda3

# 初始化conda (添加到PATH)
echo 'export PATH="/opt/chat2svg-env/miniconda3/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 初始化conda
/opt/chat2svg-env/miniconda3/bin/conda init bash
source ~/.bashrc
```

#### 8.4 创建项目环境

```bash
# 创建Python 3.10环境
conda create --name chat2svg python=3.10 -y
conda activate chat2svg

# 安装PyTorch (CUDA版本)
conda install pytorch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 pytorch-cuda=11.8 -c pytorch -c nvidia -y
```

#### 8.5 移动项目到EBS

```bash
# 创建项目目录
mkdir -p /opt/chat2svg-env/projects

# 移动Chat2SVG项目到EBS
mv /home/ec2-user/Chat2SVG /opt/chat2svg-env/projects/

# 创建软连接到原位置 (保持访问路径不变)
ln -s /opt/chat2svg-env/projects/Chat2SVG /home/ec2-user/Chat2SVG

# 验证连接
ls -la /home/ec2-user/Chat2SVG
cd /home/ec2-user/Chat2SVG
pwd -P  # 应该显示实际路径: /opt/chat2svg-env/projects/Chat2SVG
```

#### 8.6 验证EBS配置

```bash
# 检查EBS使用情况
df -h /opt/chat2svg-env

# 检查环境是否正常
conda activate chat2svg
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# 确认项目路径
cd /home/ec2-user/Chat2SVG
pwd -P
```

#### 8.7 Spot实例使用流程

**优势：** 通过EBS分离存储，可以：
- 停止当前实例，启动更便宜的Spot实例
- 分离EBS卷，重新挂载到新实例
- 所有环境和依赖都保留，无需重新安装

**流程：**
1. 停止当前实例
2. 分离EBS卷 (vol-0b4324ee9a710179f)  
3. 启动Spot实例
4. 挂载EBS卷到新实例
5. 配置自动挂载和环境变量
6. 继续开发工作

## 常见问题解决

### Stage 2测试时遇到的OpenCV导入错误

**场景：** 在运行Stage 2 Detail Enhancement时

**错误信息：**
```
Traceback (most recent call last):
  File "/home/ec2-user/Chat2SVG/2_detail_enhancement/main.py", line 13, in <module>
    import cv2
  File "/home/ec2-user/miniconda3/envs/chat2svg/lib/python3.10/site-packages/cv2/__init__.py", line 181, in <module>
    bootstrap()
  File "/home/ec2-user/miniconda3/envs/chat2svg/lib/python3.10/site-packages/cv2/__init__.py", line 153, in bootstrap
    native_module = importlib.import_module("cv2")
  File "/home/ec2-user/miniconda3/envs/chat2svg/lib/python3.10/importlib/__init__.py", line 126, in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
ImportError: libGL.so.1: cannot open shared object file: No such file or directory
```

**原因：** AWS Linux服务器环境中缺少OpenGL库依赖，导致OpenCV无法正常导入

**解决方案：**
```bash
sudo yum install -y mesa-libGL mesa-libGL-devel
```

**说明：** 这个问题通常出现在无头Linux服务器上，OpenCV需要OpenGL库支持。安装mesa-libGL后问题即可解决。

### 编译错误：缺少C++编译器

**场景：** 在pip install某些包时需要编译C++代码

**错误信息：**
```
error: Microsoft Visual C++ 14.0 is required
```

**解决方案：**
```bash
sudo yum groupinstall -y "Development Tools"
```

## 常用开发命令

```bash
# 查看状态
git status

# 提交代码
git add .
git commit -m "feat: 功能描述"
git push

# 拉取最新代码
git pull origin dev

# 激活conda环境
conda activate chat2svg

# 运行测试
cd 1_template_generation
python main.py --target "apple" --output_path "../output" --output_folder "test_generation/apple"
```

## 项目结构

```
Chat2SVG/
├── 1_template_generation/     # Stage 1: SVG模板生成
├── 2_detail_enhancement/      # Stage 2: 细节增强
├── 3_svg_optimization/        # Stage 3: SVG优化
├── utils/                     # 工具函数
├── output/                    # 输出结果 (gitignore)
├── diffvg/                    # diffvg库 (gitignore)
├── picosvg/                   # picosvg库 (gitignore)
├── .env                       # API配置 (gitignore)
├── README.md                  # 项目主文档
└── README-DEV.md              # 开发环境配置
```

## 测试流程

1. **Stage 1测试**：
   ```bash
   cd 1_template_generation
   python main.py --target "apple" --output_path "../output" --output_folder "test_generation/apple"
   ```

2. **Stage 2测试**：
   ```bash
   cd 2_detail_enhancement
   bash download_models.sh
   python main.py --target "apple" --output_path "../output" --output_folder "test_generation/apple"
   ```

3. **Stage 3测试**：
   ```bash
   cd 3_svg_optimization
   bash download_models.sh
   python main.py --target "apple" --output_path "../output" --output_folder "test_generation/apple"
   ```

## AWS Spot实例自动化配置

### User Data脚本

为了让新的Spot实例能够自动配置所有必要的环境，我们需要在创建实例时添加以下User Data脚本。这个脚本会自动：

1. 挂载EBS卷
2. 创建所有必要的软连接
3. 设置正确的权限
4. 初始化开发环境

**创建Spot实例时的User Data配置：**

```bash
#!/bin/bash

# AWS EC2 User Data Script for Chat2SVG Environment
# 自动配置EBS挂载和环境初始化

# 日志记录
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting Chat2SVG environment setup..."

# 等待EBS卷可用
sleep 30

# 挂载EBS卷 (请根据实际的卷ID调整)
EBS_VOLUME_ID="vol-0b4324ee9a710179f"
MOUNT_POINT="/opt/chat2svg-env"

# 确保挂载点存在
mkdir -p ${MOUNT_POINT}

# 检查设备是否存在
if [ -b /dev/xvdf ]; then
    # 挂载EBS卷
    mount /dev/xvdf ${MOUNT_POINT}
    echo "EBS volume mounted successfully"
    
    # 设置自动挂载 (如果不存在)
    if ! grep -q "UUID=" /etc/fstab | grep -q "${MOUNT_POINT}"; then
        UUID=$(blkid -s UUID -o value /dev/xvdf)
        echo "UUID=${UUID} ${MOUNT_POINT} ext4 defaults,nofail 0 2" >> /etc/fstab
        echo "Added EBS volume to fstab"
    fi
else
    echo "Warning: EBS volume /dev/xvdf not found"
fi

# 切换到ec2-user用户执行后续操作
sudo -u ec2-user bash << 'EOF'

# 创建软连接 - Miniconda3
if [ -d "/opt/chat2svg-env/miniconda3" ] && [ ! -L "/home/ec2-user/miniconda3" ]; then
    ln -s /opt/chat2svg-env/miniconda3 /home/ec2-user/miniconda3
    echo "Created miniconda3 symlink"
fi

# 创建软连接 - Chat2SVG项目
if [ -d "/opt/chat2svg-env/projects/Chat2SVG" ] && [ ! -L "/home/ec2-user/Chat2SVG" ]; then
    ln -s /opt/chat2svg-env/projects/Chat2SVG /home/ec2-user/Chat2SVG
    echo "Created Chat2SVG project symlink"
fi

# 创建软连接 - SSH配置
if [ -d "/opt/chat2svg-env/.ssh" ] && [ ! -L "/home/ec2-user/.ssh" ]; then
    rm -rf /home/ec2-user/.ssh
    ln -s /opt/chat2svg-env/.ssh /home/ec2-user/.ssh
    echo "Created SSH symlink"
fi

# 创建软连接 - Git配置
if [ -f "/opt/chat2svg-env/.gitconfig" ] && [ ! -L "/home/ec2-user/.gitconfig" ]; then
    rm -f /home/ec2-user/.gitconfig
    ln -s /opt/chat2svg-env/.gitconfig /home/ec2-user/.gitconfig
    echo "Created Git config symlink"
fi

# 设置正确的权限
if [ -d "/home/ec2-user/.ssh" ]; then
    chmod 700 /home/ec2-user/.ssh
    chmod 600 /home/ec2-user/.ssh/id_rsa 2>/dev/null || true
    chmod 644 /home/ec2-user/.ssh/id_rsa.pub 2>/dev/null || true
    echo "Set SSH permissions"
fi

# 添加conda到PATH (如果存在)
if [ -f "/home/ec2-user/miniconda3/etc/profile.d/conda.sh" ]; then
    # 添加conda初始化到.bashrc (如果不存在)
    if ! grep -q "conda initialize" /home/ec2-user/.bashrc; then
        echo "" >> /home/ec2-user/.bashrc
        echo "# >>> conda initialize >>>" >> /home/ec2-user/.bashrc
        echo ". /home/ec2-user/miniconda3/etc/profile.d/conda.sh" >> /home/ec2-user/.bashrc
        echo "# <<< conda initialize <<<" >> /home/ec2-user/.bashrc
        echo "Added conda initialization to .bashrc"
    fi
fi

# 创建一个快速启动脚本
cat > /home/ec2-user/start-chat2svg.sh << 'SCRIPT'
#!/bin/bash
echo "🚀 Chat2SVG Environment Quick Start"
echo "======================================"

# 激活conda环境
source /home/ec2-user/miniconda3/etc/profile.d/conda.sh
conda activate chat2svg

# 进入项目目录
cd /home/ec2-user/Chat2SVG

# 显示环境状态
echo "✅ Current directory: $(pwd)"
echo "✅ Conda environment: $(conda info --envs | grep '*' | awk '{print $1}')"
echo "✅ Git user: $(git config user.name) <$(git config user.email)>"
echo "✅ GPU status:"
nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader,nounits

echo ""
echo "🎯 Ready to run Chat2SVG pipeline!"
echo "   - Stage 1: cd 1_template_generation && bash run.sh"
echo "   - Stage 2: cd 2_detail_enhancement && bash run.sh"  
echo "   - Stage 3: cd 3_svg_optimization && bash run.sh"
SCRIPT

chmod +x /home/ec2-user/start-chat2svg.sh
echo "Created quick start script: ~/start-chat2svg.sh"

EOF

echo "Chat2SVG environment setup completed!"
echo "User can run: ~/start-chat2svg.sh to get started"
```

### 使用说明

1. **创建Spot实例时**：
   - 在"Advanced details" -> "User data"中粘贴上述脚本
   - 确保选择正确的安全组和密钥对
   - 确保EBS卷(`vol-0b4324ee9a710179f`)在同一可用区

2. **实例启动后**：
   ```bash
   # SSH连接到实例后，运行快速启动脚本
   ~/start-chat2svg.sh
   
   # 或者手动激活环境
   conda activate chat2svg
   cd Chat2SVG
   ```

3. **验证环境**：
   ```bash
   # 检查挂载
   df -h | grep chat2svg-env
   
   # 检查软连接
   ls -la ~ | grep -E "(Chat2SVG|miniconda3|\.ssh|\.gitconfig)"
   
   # 检查Git配置
   git config --global --list
   
   # 检查conda环境
   conda env list
   ```

### 注意事项

- **EBS卷ID**：确保User Data脚本中的`vol-0b4324ee9a710179f`是正确的卷ID
- **可用区**：新Spot实例必须与EBS卷在同一可用区
- **第一次启动**：可能需要等待1-2分钟让User Data脚本完成执行
- **SSH密钥**：确保已将SSH公钥添加到GitHub，这样就可以直接推送代码

这样配置后，每次创建新的Spot实例都会自动完成所有环境配置，真正实现了"开箱即用"！

## 实例类型兼容性指南

### ✅ 支持的实例切换

基于当前的EBS配置（Amazon Linux 2023.8, x86_64），以下实例类型可以互相切换：

#### 开发/调试用实例（成本优化）
```bash
# 适合查看代码、Git操作、轻量开发
- t3.micro ($6.1/月, 1 vCPU, 1GB RAM)
- t3.small ($12.2/月, 2 vCPU, 2GB RAM)  
- t3.medium ($24.3/月, 2 vCPU, 4GB RAM)
- t2.micro ($8.5/月) # 免费套餐
```

#### GPU计算实例（模型运行）
```bash
# 适合运行Chat2SVG pipeline
- g4dn.xlarge ($0.526/小时, 4 vCPU, 16GB RAM, Tesla T4)
- g4dn.2xlarge ($0.752/小时, 8 vCPU, 32GB RAM, Tesla T4)
- g5.xlarge ($1.006/小时, 4 vCPU, 16GB RAM, A10G) # 更强GPU
```

### ❌ 不兼容的实例类型

```bash
# 不同架构 - 会导致软件无法运行
- c7g.*, m7g.*, r7g.* (ARM64 Graviton)

# 不同操作系统 - 完全不兼容  
- Windows 实例
- Ubuntu/CentOS AMI (需要相同的Amazon Linux 2023)
```

### 🔄 实例切换最佳实践

#### 1. **开发模式** (t3.small + Spot实例)
```bash
# 日常开发：启动便宜的t3.small实例
aws ec2 run-instances \
  --image-id ami-0abcdef1234567890 \  # Amazon Linux 2023
  --instance-type t3.small \
  --user-data file://user-data.sh

# 运行训练：启动GPU Spot实例
aws ec2 request-spot-instances \
  --instance-count 1 \
  --type "one-time" \
  --launch-specification '{
    "ImageId": "ami-0abcdef1234567890",
    "InstanceType": "g4dn.xlarge",
    "UserData": "$(base64 -w 0 user-data.sh)"
  }'
```

#### 2. **环境验证**
每次切换实例后运行：
```bash
# 检查环境兼容性
/opt/chat2svg-env/check-gpu-compatibility.sh

# 快速启动
~/start-chat2svg.sh
```

#### 3. **GPU vs CPU 使用策略**

**非GPU实例（t3.*）适合的操作**：
- ✅ 代码开发和查看
- ✅ Git操作（commit, push, pull）
- ✅ 文档编写
- ✅ Stage 1: Template Generation (LLM调用)
- ✅ 轻量级测试

**GPU实例（g4dn.*）必需的操作**：
- 🔥 Stage 2: Detail Enhancement (SDXL + SAM)
- 🔥 Stage 3: SVG Optimization (VAE模型)
- 🔥 模型训练和推理

### 🚨 注意事项

1. **可用区一致性**：
   ```bash
   # EBS卷和实例必须在同一可用区
   # 当前EBS: ap-southeast-2a (请根据实际情况调整)
   ```

2. **AMI选择建议**：
   ```bash
   # 推荐AMI (保持兼容性)
   - Deep Learning Base OSS Nvidia Driver GPU AMI (Amazon Linux 2023)
   - Amazon Linux 2023 AMI (x86_64)
   ```

3. **成本优化策略**：
   ```bash
   # 开发时段：使用t3.small常规实例 (~$12/月)
   # 训练时段：使用g4dn.xlarge Spot实例 (~$0.15/小时，节省70%)
   # 平均成本：开发20天 + 训练10小时 ≈ $13.5/月
   ```

这种混合使用模式可以大幅降低成本，同时保持开发效率！ 