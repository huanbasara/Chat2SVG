#!/bin/bash

# 内存监控脚本 - 修复版本
LOG_FILE="memory_monitor.log"
INTERVAL=2  # 每2秒检查一次

echo "=== Memory Monitoring Started at $(date) ===" > $LOG_FILE
echo "Time,CPU_Used_GB,CPU_Available_GB,CPU_Usage_Percent,GPU_Status" >> $LOG_FILE

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 获取CPU内存信息 (使用更可靠的方法)
    MEMORY_INFO=$(free -m | grep "Mem:")
    TOTAL_MEM=$(echo $MEMORY_INFO | awk '{print $2}')
    USED_MEM=$(echo $MEMORY_INFO | awk '{print $3}')
    AVAILABLE_MEM=$(echo $MEMORY_INFO | awk '{print $7}')
    
    # 转换为GB并计算使用百分比
    TOTAL_GB=$(echo "scale=2; $TOTAL_MEM / 1024" | bc -l)
    USED_GB=$(echo "scale=2; $USED_MEM / 1024" | bc -l)
    AVAILABLE_GB=$(echo "scale=2; $AVAILABLE_MEM / 1024" | bc -l)
    
    # 计算内存使用百分比
    CPU_USAGE_PERCENT=$(echo "scale=1; $USED_MEM * 100 / $TOTAL_MEM" | bc -l)
    
    # 简化的GPU检查
    GPU_INFO="N/A"
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            GPU_INFO="GPU_OK"
        else
            GPU_INFO="GPU_Error"
        fi
    else
        GPU_INFO="No_GPU"
    fi
    
    # 记录到日志文件
    echo "$TIMESTAMP,$USED_GB,$AVAILABLE_GB,$CPU_USAGE_PERCENT%,$GPU_INFO" >> $LOG_FILE
    
    # 如果内存使用超过80%，添加警告
    HIGH_MEM_CHECK=$(echo "$CPU_USAGE_PERCENT > 80" | bc -l)
    if [ "$HIGH_MEM_CHECK" -eq 1 ]; then
        echo "$TIMESTAMP,WARNING: High CPU memory usage: ${CPU_USAGE_PERCENT}%" >> $LOG_FILE
    fi
    
    sleep $INTERVAL
done 