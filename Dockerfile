FROM alpine:3.17 as xformers
RUN apk add --no-cache aria2
RUN aria2c -x 5 --dir / --out wheel.whl 'https://github.com/AbdBarho/stable-diffusion-webui-docker/releases/download/6.0.0/xformers-0.0.21.dev544-cp310-cp310-manylinux2014_x86_64-pytorch201.whl'


FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1
RUN sed -i s/archive.ubuntu.com/mirrors.aliyun.com/g /etc/apt/sources.list && sed -i s/security.ubuntu.com/mirrors.aliyun.com/g /etc/apt/sources.list

RUN --mount=type=cache,target=/var/cache/apt \
  apt-get update && \
  # we need those
  apt-get install -y fonts-dejavu-core rsync git jq moreutils aria2 \
  # extensions needs those
  ffmpeg libglfw3-dev libgles2-mesa-dev pkg-config libcairo2 libcairo2-dev build-essential


RUN --mount=type=cache,target=/root/.cache/pip \
  git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
  cd stable-diffusion-webui && \
  git reset --hard 5ef669de080814067961f28357256e8fe27544f4 && \
  pip install -r requirements_versions.txt

RUN --mount=type=cache,target=/root/.cache/pip  \
  --mount=type=bind,from=xformers,source=/wheel.whl,target=/xformers-0.0.21.dev544-cp310-cp310-manylinux2014_x86_64.whl \
  pip install /xformers-0.0.21.dev544-cp310-cp310-manylinux2014_x86_64.whl

ENV ROOT=/stable-diffusion-webui

RUN git clone https://github.com/Stability-AI/stablediffusion.git /stable-diffusion-webui/repositories/stable-diffusion-stability-ai
RUN git -C /stable-diffusion-webui/repositories/stable-diffusion-stability-ai checkout cf1d67a6fd5ea1aa600c4df58e5b47da45f6bdbf && rm -rf assets data/**/*.png data/**/*.jpg data/**/*.gif

RUN git clone https://github.com/sczhou/CodeFormer.git /stable-diffusion-webui/repositories/CodeFormer
RUN git -C /stable-diffusion-webui/repositories/CodeFormer checkout c5b4593074ba6214284d6acd5f1719b6c5d739af  && rm -rf assets inputs

RUN git clone https://github.com/salesforce/BLIP.git /stable-diffusion-webui/repositories/BLIP
RUN git -C /stable-diffusion-webui/repositories/BLIP checkout 48211a1594f1321b00f14c9f7a5b4813144b2fb9

RUN git clone https://github.com/crowsonkb/k-diffusion.git /stable-diffusion-webui/repositories/k-diffusion
RUN git -C /stable-diffusion-webui/repositories/k-diffusion checkout ab527a9a6d347f364e3d185ba6d714e22d80cb3c

RUN git clone https://github.com/pharmapsychotic/clip-interrogator /stable-diffusion-webui/repositories/clip-interrogator
RUN git -C /stable-diffusion-webui/repositories/clip-interrogator checkout 2cf03aaf6e704197fd0dae7c7f96aa59cf1b11c9

RUN git clone https://github.com/pharmapsychotic/generative-models /stable-diffusion-webui/repositories/generative-models
RUN git -C /stable-diffusion-webui/repositories/generative-models checkout 45c443b316737a4ab6e40413d7794a7f5657c19f


ENV INDEX_URL https://pypi.tuna.tsinghua.edu.cn/simple
RUN mkdir ~/.pip && echo "[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple\n[install]\ntrusted-host = https://pypi.tuna.tsinghua.edu.cn" > ~/.pip/pip.conf

# COPY --from=download /repositories/ ${ROOT}/repositories/
RUN mkdir ${ROOT}/interrogate && cp ${ROOT}/repositories/clip-interrogator/clip_interrogator/data/* ${ROOT}/interrogate
RUN --mount=type=cache,target=/root/.cache/pip \
  pip install -r ${ROOT}/repositories/CodeFormer/requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
  pip install pyngrok \
  git+https://github.com/TencentARC/GFPGAN.git@8d2447a2d918f8eba5a4a01463fd48e45126a379 \
  git+https://github.com/openai/CLIP.git@d50d76daa670286dd6cacf3bcd80b5e4823fc8e1 \
  git+https://github.com/mlfoundations/open_clip.git@bb6e834e9c70d9c27d0dc3ecedeebeaeb1ffad6b


# Note: don't update the sha of previous versions because the install will take forever
# instead, update the repo state in a later step

# TODO: either remove if fixed in A1111 (unlikely) or move to the top with other apt stuff
RUN apt-get -y install libgoogle-perftools-dev && apt-get clean
ENV LD_PRELOAD=libtcmalloc.so

ARG SHA=5ef669de080814067961f28357256e8fe27544f4
RUN --mount=type=cache,target=/root/.cache/pip \
  cd stable-diffusion-webui && \
  git fetch && \
  git reset --hard ${SHA} && \
  pip install -r requirements_versions.txt


RUN \
  mv ${ROOT}/style.css ${ROOT}/user.css && \
  # one of the ugliest hacks I ever wrote \
  sed -i 's/in_app_dir = .*/in_app_dir = True/g' /usr/local/lib/python3.10/site-packages/gradio/routes.py && \
  git config --global --add safe.directory '*'

WORKDIR ${ROOT}
ENV NVIDIA_VISIBLE_DEVICES=all
ENV CLI_ARGS=""
EXPOSE 7860
CMD python3 -u webui.py --listen --port 7860 ${CLI_ARGS}
