FROM docker.io/library/docker:dind

ARG SSH_USER=devops

RUN apk add --no-cache openssh-server sudo shadow bash python3 py3-pip && \
    pip3 install --break-system-packages docker

RUN ssh-keygen -A

RUN useradd --create-home --shell /bin/bash "${SSH_USER}" && \
    usermod -p '*' "${SSH_USER}" && \
    echo "${SSH_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${SSH_USER}" && \
    chmod 0440 "/etc/sudoers.d/90-${SSH_USER}"

COPY authorized_keys /tmp/authorized_keys
RUN install -d -m 0700 -o "${SSH_USER}" -g "${SSH_USER}" "/home/${SSH_USER}/.ssh" && \
    install -m 0600 -o "${SSH_USER}" -g "${SSH_USER}" \
        /tmp/authorized_keys "/home/${SSH_USER}/.ssh/authorized_keys" && \
    rm /tmp/authorized_keys

COPY sshd_hardening.conf /etc/ssh/sshd_config.d/10-formazione.conf
RUN grep -q '^Include /etc/ssh/sshd_config.d' /etc/ssh/sshd_config || \
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config

RUN mkdir -p /etc/docker && \
    echo '{"insecure-registries":["registry:5000"]}' > /etc/docker/daemon.json

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
