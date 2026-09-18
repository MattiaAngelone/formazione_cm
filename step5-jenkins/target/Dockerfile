# Base con docker incluso, per eseguire altri container dentro il target
FROM docker.io/library/docker:dind

# Nome dell'utente per le connessioni SSH
ARG SSH_USER=devops

RUN apk add --no-cache openssh-server sudo shadow bash python3 py3-pip && \
    pip3 install --break-system-packages docker

# Crea le chiavi che identificano il server SSH, diverse dalla chiave dell'utente, generate durante la build, incluse nell'immagine.
RUN ssh-keygen -A

# Crea l'utente SSH e gli permette di usare sudo senza password
# Ansible userà questi privilegi con become: true durante il deploy
RUN useradd --create-home --shell /bin/bash "${SSH_USER}" && \
    usermod -p '*' "${SSH_USER}" && \
    echo "${SSH_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${SSH_USER}" && \
    chmod 0440 "/etc/sudoers.d/90-${SSH_USER}"

# Installa la chiave pubblica autorizzata ad accedere come SSH_USER
# Assegna all'utente la proprietà dei file e limita i permessi di accesso
COPY authorized_keys /tmp/authorized_keys
RUN install -d -m 0700 -o "${SSH_USER}" -g "${SSH_USER}" "/home/${SSH_USER}/.ssh" && \
    install -m 0600 -o "${SSH_USER}" -g "${SSH_USER}" \
        /tmp/authorized_keys "/home/${SSH_USER}/.ssh/authorized_keys" && \
    rm /tmp/authorized_keys

# Copia le regole di accesso SSH e verifica che sshd legga questa directory
# Se manca la direttiva include, la aggiunge alla configurazione principale
COPY sshd_hardening.conf /etc/ssh/sshd_config.d/10-formazione.conf
RUN grep -q '^Include /etc/ssh/sshd_config.d' /etc/ssh/sshd_config || \
    sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config

# Permette al docker interno al target di usare il registry del lab via HTTP
RUN mkdir -p /etc/docker && \
    echo '{"insecure-registries":["registry:5000"]}' > /etc/docker/daemon.json

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

# Esegue lo script che avvia SSH e Docker quando parte il container
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
