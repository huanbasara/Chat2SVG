#!/bin/bash

gpu_id=0

experiment_name="example_generation"
targets=(
    "apple"
    # "bonsai"
    # "daisy"
    # "ice_cream"
    # "lighthouse"
    # "penguin"
)

for target in "${targets[@]}"; do
    output_path="../output"
    output_folder="${experiment_name}/${target}"

    echo "=== 运行Stage 2 (分离版本) for ${target} ==="
    
    # Activate conda environment once
    source $(conda info --base)/etc/profile.d/conda.sh
    conda activate chat2svg
    
    # Stage 2a: SVG Processing
    echo "Running SVG Processing..."
    CUDA_VISIBLE_DEVICES="${gpu_id}" python main.py \
        --target "${target}" \
        --output_path "$output_path" \
        --output_folder "$output_folder" \
        --seed 0 \
        --stage svg_processing
    
    # Stage 2b: Image Diffusion
    echo "Running Image Diffusion..."
    CUDA_VISIBLE_DEVICES="${gpu_id}" python main.py \
        --target "${target}" \
        --output_path "$output_path" \
        --output_folder "$output_folder" \
        --seed 0 \
        --num_images_per_prompt 4 \
        --strength 1.0 \
        --stage image_diffusion
    
    # Stage 2c: SAM Processing
    echo "Running SAM Processing..."
    CUDA_VISIBLE_DEVICES="${gpu_id}" python main.py \
        --target "${target}" \
        --output_path "$output_path" \
        --output_folder "$output_folder" \
        --seed 0 \
        --stage sam_processing
done
