# Тестовое окружение для Ansible: официальный Ubuntu 24.04 + openssh-server.
# systemd запущен как PID 1 -> модули service/systemd и хендлеры restart работают
# как на реальной VM (иначе рестарт sshd/nginx в контейнере пришлось бы хакать).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

# python3 нужен Ansible на управляемом узле; sudo - для become; остальное по заданию.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd systemd-sysv \
        openssh-server \
        sudo \
        python3 \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Чистим systemd-юниты, которые в контейнере только мешают/падают.
RUN find /etc/systemd/system /lib/systemd/system \
        -path '*.wants*' \
        \( -name '*systemd-tmpfiles*' \
        -o -name '*systemd-update-utmp*' \) \
        -exec rm -f {} + \
    && systemctl mask \
        systemd-logind.service \
        getty.target \
        console-getty.service \
        systemd-udevd.service \
    || true

# Ubuntu 24.04 по умолчанию активирует ssh через сокет; для предсказуемости
# используем обычный ssh.service.
RUN ssh-keygen -A \
    && systemctl disable ssh.socket 2>/dev/null || true \
    && systemctl enable ssh.service

# Пользователь, под которым подключается Ansible (root-логин запрещаем ролью ssh).
ARG DEPLOY_USER=deploy
RUN useradd -m -s /bin/bash ${DEPLOY_USER} \
    && usermod -aG sudo ${DEPLOY_USER} \
    && echo "${DEPLOY_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${DEPLOY_USER} \
    && chmod 0440 /etc/sudoers.d/90-${DEPLOY_USER} \
    && mkdir -p /home/${DEPLOY_USER}/.ssh \
    && chmod 700 /home/${DEPLOY_USER}/.ssh

# Тестовый публичный ключ (пара генерится локально scripts/setup.sh, в git не коммитится).
COPY docker/keys/id_ed25519.pub /home/${DEPLOY_USER}/.ssh/authorized_keys
RUN chmod 600 /home/${DEPLOY_USER}/.ssh/authorized_keys \
    && chown -R ${DEPLOY_USER}:${DEPLOY_USER} /home/${DEPLOY_USER}/.ssh

EXPOSE 22 80

# Корректное завершение systemd по сигналу Docker.
STOPSIGNAL SIGRTMIN+3

CMD ["/lib/systemd/systemd"]
