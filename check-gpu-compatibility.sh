#!/bin/bash

# GPU兼容性检查脚本
# 用于在不同类型实例之间切换时确保环境正常工作

echo "🔍 Checking GPU compatibility..."

# 检查是否有GPU
if command -v nvidia-smi &> /dev/null; then
    echo "✅ NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    export GPU_AVAILABLE=true
else
    echo "⚠️  No GPU detected - running in CPU-only mode"
    export GPU_AVAILABLE=false
fi

# 检查CUDA是否可用
python -c "
import sys
import warnings
warnings.filterwarnings('ignore')

try:
    import torch
    if torch.cuda.is_available():
        print('✅ CUDA available:', torch.cuda.get_device_name(0))
        print('✅ CUDA version:', torch.version.cuda)
    else:
        print('⚠️  CUDA not available - PyTorch will use CPU')
        print('💡 This is normal on non-GPU instances')
except ImportError:
    print('❌ PyTorch not installed')
    sys.exit(1)
"

# 检查conda环境
echo ""
echo "🔍 Checking conda environment..."

# 找到正确的conda路径
CONDA_PATH=""
if [ -f "/home/ec2-user/miniconda3/etc/profile.d/conda.sh" ]; then
    CONDA_PATH="/home/ec2-user/miniconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/chat2svg-env/miniconda3/etc/profile.d/conda.sh" ]; then
    CONDA_PATH="/opt/chat2svg-env/miniconda3/etc/profile.d/conda.sh"
fi

if [ -n "$CONDA_PATH" ]; then
    source "$CONDA_PATH"
    
    if conda env list | grep -q "chat2svg"; then
        echo "✅ chat2svg environment exists"
        conda activate chat2svg
        
        # 检查关键包
        echo "📦 Checking key packages:"
        python -c "
packages = [
    ('torch', 'torch'), 
    ('torchvision', 'torchvision'),
    ('transformers', 'transformers'), 
    ('diffusers', 'diffusers'),
    ('cv2', 'opencv-python'),
    ('PIL', 'Pillow'),
    ('numpy', 'numpy')
]
for import_name, pkg_name in packages:
    try:
        __import__(import_name)
        print(f'✅ {pkg_name}')
    except ImportError:
        print(f'❌ {pkg_name} - missing')
"
    else
        echo "❌ chat2svg environment not found"
    fi
else
    echo "❌ conda not found in expected paths"
fi

echo ""
echo "🎯 Environment check completed!"
if [ "$GPU_AVAILABLE" = "false" ]; then
    echo "💡 Note: Running on CPU-only instance - some operations will be slower but functional"
fi
