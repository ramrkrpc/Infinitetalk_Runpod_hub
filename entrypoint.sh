#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# rviv: fetch models onto the persistent network volume on first boot,
# then symlink them into ComfyUI's model folders.
MODELS_DIR="${MODELS_DIR:-/runpod-volume/models}"

fetch() {
    local sub="$1" url="$2" name="$3"
    mkdir -p "$MODELS_DIR/$sub" "/ComfyUI/models/$sub"
    local dst="$MODELS_DIR/$sub/$name"
    if [ ! -f "$dst" ]; then
        echo "Downloading $name ..."
        wget -q "$url" -O "$dst.part.$$" && mv "$dst.part.$$" "$dst"
    fi
    ln -sf "$dst" "/ComfyUI/models/$sub/$name"
}

fetch diffusion_models "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" "Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"
fetch diffusion_models "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Multi_fp8_e4m3fn_scaled_KJ.safetensors" "Wan2_1-InfiniteTalk-Multi_fp8_e4m3fn_scaled_KJ.safetensors"
fetch diffusion_models "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" "Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"
fetch loras "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" "lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"
fetch vae "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" "Wan2_1_VAE_bf16.safetensors"
fetch text_encoders "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors" "umt5-xxl-enc-fp8_e4m3fn.safetensors"
fetch clip_vision "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" "clip_vision_h.safetensors"
fetch diffusion_models "https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors" "MelBandRoformer_fp16.safetensors"

echo "All models present."

# Start ComfyUI in the background
# rviv: --use-sage-attention removed — SageAttention kernels crash on
# 4090/A40/A6000 serverless workers (upstream issue #15); default SDPA works.
echo "Starting ComfyUI in the background..."
python /ComfyUI/main.py --listen &

# Wait for ComfyUI to be ready
echo "Waiting for ComfyUI to be ready..."
max_wait=120  # 최대 2분 대기
wait_count=0
while [ $wait_count -lt $max_wait ]; do
    if curl -s http://127.0.0.1:8188/ > /dev/null 2>&1; then
        echo "ComfyUI is ready!"
        break
    fi
    echo "Waiting for ComfyUI... ($wait_count/$max_wait)"
    sleep 2
    wait_count=$((wait_count + 2))
done

if [ $wait_count -ge $max_wait ]; then
    echo "Error: ComfyUI failed to start within $max_wait seconds"
    exit 1
fi

# Start the handler in the foreground
# 이 스크립트가 컨테이너의 메인 프로세스가 됩니다.
echo "Starting the handler..."
exec python handler.py
