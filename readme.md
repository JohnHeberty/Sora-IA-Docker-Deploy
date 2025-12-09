# Sora-IA-Proxmox

Setup em Docker para rodar o **Open-Sora v1.1** com interface **Gradio** dentro de uma VM Proxmox com GPU passthrough.

> ⚠️ **Aviso importante sobre qualidade dos resultados**
>
> Este projeto é **experimental**. Nos testes feitos, a qualidade dos vídeos/imagens gerados ficou **bem abaixo** do Sora original mostrado em demos oficiais (artefatos, baixa nitidez, movimentos estranhos etc.).  
> Use apenas para **estudos, testes e curiosidade**, não espere resultados profissionais.
> Valide por sé mesmo os resultados em /output gerados na data 09/12/2025

---

## 📁 Estrutura do projeto

- `Dockerfile`  
  Imagem baseada em **CUDA 12.1 + Ubuntu 22.04**, com:
  - PyTorch + CUDA
  - xFormers
  - Open-Sora v1.1
  - Gradio
  - Ajustes de memória para não estourar VRAM/RAM
  - Correções para:
    - Erros de device (CPU x GPU) no T5
    - Problemas com gravação de vídeo (`torchvision` + `av`)

- `docker-compose.yml`  
  Sobe o serviço `app-sora` (container `sora-gradio`), expondo a porta **7860** e montando:
  - Cache do Hugging Face
  - Pasta de `outputs` dos vídeos/imagens gerados

---

## 🧱 Requisitos

Na **VM Proxmox** onde o container será executado:

- GPU NVIDIA com suporte a CUDA (e drivers instalados no host)
- GPU passada para a VM (passthrough / virtio-gpu + nvidia, conforme seu setup)
- Docker e Docker Compose instalados
- Pelo menos:
  - **24 GB RAM** (mais é melhor)
  - **20+ GB VRAM** recomendados para conseguir rodar os modelos com menos dor de cabeça

---

## 🚀 Como usar

1. **Clonar o repositório**

   ```bash
   git clone https://github.com/JohnHeberty/Sora-IA-Proxmox.git
   cd Sora-IA-Proxmox
   ````

2. **Ajustar parâmetros (se quiser)**

   * Verifique e edite o `docker-compose.yml` se precisar mudar:

     * Porta padrão (`7860:7860`)
     * Limite de memória
     * Volumes de saída (`./outputs`)
   * Verifique também o `Dockerfile` caso queira:

     * Fixar outras versões de PyTorch/transformers
     * Mudar configs de memória (`PYTORCH_CUDA_ALLOC_CONF`, `MAX_JOBS`, etc.)

3. **Build da imagem**

   ```bash
   docker compose build
   ```

4. **Subir o container**

   ```bash
   docker compose up -d
   ```

5. **Acessar a interface**

   No navegador, acesse:

   ```text
   http://IP_DA_VM:7860
   ```

   * Use os modos disponíveis na interface (Text2Video / Text2Image, etc.)
   * Os arquivos gerados serão salvos na pasta `./outputs` do host (mapeada pelo compose).

---

## ⚙️ Notas técnicas

* O `entrypoint.sh` dentro do container:

  * Aplica patches no `app.py` do Gradio/Open-Sora (por exemplo, ajustes de device para o T5).
  * Inicia o servidor Gradio já pronto em `0.0.0.0:7860`.

* Foram aplicados ajustes para:

  * Evitar alguns erros de **CUDA out of memory**.
  * Reduzir paralelismo de compilação (`MAX_JOBS=1`, `NINJA_NUM_JOBS=1`).
  * Tratar erros de gravação com a lib `av`/`torchvision`.

---

## ⚠️ Limitações e problemas conhecidos

* **Qualidade dos vídeos/imagens**

  * Muito inferior às demos oficiais do Sora.
  * Podem aparecer:

    * Frames tremidos
    * Artefatos visuais
    * Cores e formas estranhas
    * Falta de consistência entre frames

* **Desempenho**

  * Dependente **fortemente** da GPU.
  * Geração de vídeo é lenta, mesmo com 24GB VRAM.
  * Alguns prompts podem falhar ou estourar memória dependendo da resolução/duração escolhida.

* **Estabilidade**

  * O projeto usa uma combinação específica de versões (PyTorch, diffusers, transformers, av, etc.).
  * Atualizações futuras de libs podem quebrar algo.
  * Este repositório não é oficial do time Open-Sora / Sora, é apenas uma montagem de ambiente.

---

## 🧪 Objetivo do projeto

* Facilitar:

  * Testes do Open-Sora v1.1 dentro de VMs Proxmox com GPU.
  * Estudos sobre:

    * Arquitetura do modelo
    * Consumo de recursos
    * Pipeline Text2Video/Text2Image

* **Não** é focado em:

  * Produção
  * Qualidade final de vídeo
  * Uso profissional/comercial
  * Prompts que não usam caracteristica de "realismo"

---

## 📌 Aviso final

> Use por sua conta e risco.
> Este repositório é apenas uma **prova de conceito** de ambiente com Docker + Proxmox (já com lib cuda no "docker-compose.yaml") + GPU para rodar Open-Sora.
> Se quiser resultados realmente impressionantes, considere que o modelo aqui ainda está bem distante do Sora “oficial” mostrado em apresentações.
