# SAM 图像分割模型速查

## 🎯 核心概念

**SAM = Segment Anything Model**
- 作用：图像分割（把图片分成不同区域）
- 特点：零样本分割，无需训练即可分割任何物体
- 开发：Meta AI，2023年发布

## 🏗️ 模型架构

### **技术栈**
```python
主要架构 = Vision Transformer (ViT) + Attention
不是CNN = 现代Transformer架构，大量使用注意力机制
```

### **三个组件**
- **Image Encoder**: ViT处理图像
- **Prompt Encoder**: 处理点/框/文本提示
- **Mask Decoder**: Transformer生成分割mask

## 📋 模型版本

| 版本 | 参数量 | 文件名模式 | 适用场景 |
|------|--------|------------|----------|
| vit_b | ~90M | sam_vit_b_*.pth | 轻量级应用 |
| vit_l | ~300M | sam_vit_l_*.pth | 平衡性能 |
| vit_h | ~630M | sam_vit_h_*.pth | 最高精度（本项目使用） |

## 🔍 输入输出

### **输入**
```python
必需: 图像 (PNG/JPG)
可选: 提示 (点/框/文本/无提示)
```

### **输出**
```python
masks: 二值化分割图
scores: 每个mask的置信度  
boxes: 边界框坐标
```

## 🎮 工作机制

### **提示驱动**
```python
# SAM需要"提示"才能工作
sam(图像)              # ❌ 不知道分割什么
sam(图像, 点提示)       # ✅ 分割这个点所在区域
```

### **网格点自动化**
```python
# 项目中的自动分割策略
points_per_side = 24   # 生成24×24=576个网格点
每个点 → 询问SAM → 分割对应区域
重叠处理 → 合并相似mask → 输出最终结果
```

## 🔧 项目应用

### **两阶段分割**
```python
# 粗分割：快速找主要区域
coarse_config = {
    "points_per_side": 24,        # 较少网格点
    "min_mask_region_area": 100   # 只保留大区域
}

# 细分割：捕获细节
fine_config = {
    "points_per_side": 48,        # 更多网格点  
    "min_mask_region_area": 30    # 保留小区域
}
```

### **处理流程**
```
Diffusion增强图像 → SAM分割 → 提取mask → 转换SVG路径 → 添加到原SVG
```

## 💡 代码使用

### **核心API**
```python
# 模型加载
sam = sam_model_registry["vit_h"](checkpoint="模型文件.pth")

# 自动化生成器
generator = SamAutomaticMaskGenerator(sam, **config)

# 批量分割
masks = generator.generate(image)
```

### **关键概念**
- **sam**: 分割"大脑"（核心模型）
- **generator**: 自动化"执行器"（批量工具）
- **registry**: 模型"工厂"（按型号生产）

## 📊 业界地位

### **优势**
- ✅ 零样本能力强
- ✅ 社区活跃度高
- ✅ 集成简单
- ✅ 文档丰富

### **定位**
- 🥇 新项目首选（影响力最大）
- 🥈 整体使用量（与传统模型并存）  
- 🥇 原型开发（快速验证想法）

### **竞争对手**
- Mask2Former：精度更高
- FastSAM：速度更快
- MobileSAM：移动端优化

---
*简单说：SAM是目前最流行的"万能分割器"，给张图就能自动找出所有区域！* 