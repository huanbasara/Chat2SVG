#!/bin/bash

# 简单的Chat2SVG完整流程脚本
set -e

# 激活conda环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate chat2svg

echo "清理output目录..."
rm -rf output/*
mkdir -p output

echo "运行Stage 1..."
cd 1_template_generation
bash run.sh
cd ..

echo "运行Stage 2..."
cd 2_detail_enhancement
bash run.sh
cd ..

echo "运行Stage 3..."
cd 3_svg_optimization
bash run.sh
cd ..

echo "完成！" 