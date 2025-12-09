# Base CUDA pura, sem conda
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    # Limita jobs de compilação caso alguma lib resolva compilar algo
    MAX_JOBS=1 \
    NINJA_NUM_JOBS=1

WORKDIR /app

# 1. Dependências de sistema
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-venv python-is-python3 \
    git ffmpeg libgl1-mesa-glx libglib2.0-0 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Atualiza pip
RUN python -m pip install --upgrade pip

# 2. PyTorch + CUDA 12.1 (wheels oficiais)
RUN pip install --no-cache-dir \
    "torch==2.1.2+cu121" \
    "torchvision==0.16.2+cu121" \
    --index-url https://download.pytorch.org/whl/cu121

# 2.5 Patch no torchvision.write_video para não quebrar com PyAV
RUN python - << 'PY'
import pathlib

video_py = pathlib.Path("/usr/local/lib/python3.10/dist-packages/torchvision/io/video.py")
text = video_py.read_text()

old = '        frame.pict_type = "NONE"\\n'
new = (
    '        # patched: compat PyAV (pict_type string removida)\\n'
    '        # frame.pict_type = "NONE"\\n'
)

if old in text:
    text = text.replace(old, new)
    video_py.write_text(text)
    print("✅ Patched torchvision.io.video.write_video (removido frame.pict_type).")
else:
    print("⚠️ Linha frame.pict_type = \"NONE\" não encontrada; nada foi alterado.")
PY

# 3. xFormers (wheels cu121)
RUN pip install --no-cache-dir xformers --index-url https://download.pytorch.org/whl/cu121

# 4. Clona o Open-Sora v1.1
RUN git clone --branch opensora/v1.1 https://github.com/hpcaitech/Open-Sora.git /app/Open-Sora
WORKDIR /app/Open-Sora

# 5. Instala dependências do projeto, MAS sem torch/xformers/flash-attn/apex
RUN sed -i '/torch/d;/torchvision/d;/xformers/d;/flash-attn/d;/apex/d' requirements.txt && \
    pip install --no-cache-dir -r requirements.txt

# 6. psutil compatível
RUN pip install --no-cache-dir --force-reinstall "psutil==5.9.8"

# 7. Rotary embeddings (era o erro anterior)
RUN pip install --no-cache-dir rotary-embedding-torch

# 8. Gradio + Spaces para UI
RUN pip install --no-cache-dir gradio spaces

# 9. Variáveis de ambiente
ENV PYTHONPATH=/app/Open-Sora \
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:128 \
    HF_HOME=/root/.cache/huggingface \
    HUGGINGFACE_HUB_CACHE=/root/.cache/huggingface

EXPOSE 7860

# 10. Script de entrada: faz a cirurgia no app.py e sobe o Gradio
RUN cat << 'EOF' > /app/entrypoint.sh
#!/usr/bin/env bash
set -e

cd /app/Open-Sora

# Cirurgia: manda o T5 pra CPU em vez de GPU
if grep -q 'text_encoder.t5.model = text_encoder.t5.model.cuda()' gradio/app.py; then
  sed -i 's/text_encoder\.t5\.model = text_encoder\.t5\.model\.cuda()/text_encoder.t5.model = text_encoder.t5.model.to("cpu")/' gradio/app.py
fi

# Sobe o Gradio
exec python gradio/app.py \
  --model-type v1.1-stage3 \
  --host 0.0.0.0 \
  --port 7860
EOF

RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
