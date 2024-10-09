FROM --platform=linux/amd64 quay.io/jupyter/minimal-notebook:latest
LABEL org.opencontainers.image.source https://github.com/SilexDataTeam/ai-workshop-provisioner

USER root

RUN apt-get update; apt-get install -y podman

ADD requirements.txt /tmp/requirements.txt
ADD containers.conf /etc/containers/containers.conf

RUN chown jovyan:users -R /home/jovyan && \
    chmod 644 /etc/containers/containers.conf && \
    chown jovyan /tmp/requirements.txt

RUN echo -e "jovyan:1:999\njovyan:1001:64535" >/etc/subuid && \
    echo -e "jovyan:1:99\njovyan:101:64535" > /etc/subgid

RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list; \
    apt-get update; \
    apt-get install -y nvidia-container-toolkit

USER jovyan

RUN pip install -U nbgitpuller; \
    pip install -r /tmp/requirements.txt; \
    rm /tmp/requirements.txt