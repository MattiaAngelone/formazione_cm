# Step 2 — Build di container SSH con Ansible e Podman

Playbook Ansible che automatizza la build di due container con OS differenti con queste caratteristiche:

- Essere sempre in ascolto sulla porta 22 del container.
- Avere attivo il servizio ssh.
- Avere un utente abilitato a collegarsi tramite ssh key e poter fare sudo.

Ansible esegue le operazioni sulla macchina locale; Podman costruisce le immagini e gestisce i container.

| Sistema | Immagine | Container | Porta host → container |
| --- | --- | --- | --- |
| Ubuntu 24.04 | `ssh-ubuntu:latest` | `ssh-ubuntu` | `2201 → 22` |
| Rocky Linux 9 | `ssh-rocky:latest` | `ssh-rocky` | `2202 → 22` |

## Logica del playbook

Il file `step2-container-build/build-playbook.yml` svolge queste operazioni:

1. **Prepara le chiavi SSH.** Crea la cartella `keys/` e genera una coppia di chiavi Ed25519. Il parametro `creates` evita di rigenerarle se la chiave privata esiste già.
2. **Prepara i file per la build.** Copia la chiave pubblica in `authorized_keys` e genera `sshd_hardening.conf` dal template `sshd_hardening.conf.j2`. La variabile `ssh_user`, impostata a `devops`, definisce l’utente autorizzato.
3. **Costruisce le immagini.** Un ciclo sulla lista `images` richiama `containers.podman.podman_image` per entrambi i Containerfile. I file generati sono condivisi nello stesso contesto di build; il nome utente viene passato tramite `SSH_USER`.
4. **Avvia i container.** Un secondo ciclo usa `containers.podman.podman_container` per portarli nello stato `started` e pubblicare le porte indicate nella tabella.

## Funzionamento dei container

`Containerfile.ubuntu` e `Containerfile.rocky` installano OpenSSH e sudo, creano l’utente `devops` e gli consentono di usare **sudo senza password**.

La chiave pubblica viene installata nella sua cartella `.ssh` con i permessi corretti; la chiave privata rimane sull’host.

La configurazione SSH permette l’accesso con chiave pubblica all’utente previsto e disabilita l’accesso diretto come root e l’autenticazione tramite password. Le chiavi host del server SSH vengono generate durante la build con `ssh-keygen -A`.

All’avvio viene eseguito:

```bash
/usr/sbin/sshd -D -e
```

- `-D` mantiene SSH in primo piano, lasciando il container in esecuzione.
- `-e` invia i log allo standard error, consultabile con `podman logs`.

Il server ascolta sulla porta **22 interna**; la mappatura di Podman lo rende raggiungibile sulle porte host **2201 e 2202**. `EXPOSE 22` descrive la porta dell’immagine, ma non la pubblica da solo.

## Esecuzione e aggiornamento

Servono Ansible, Podman e la collection `containers.podman`.

```bash
ansible-playbook step2-container-build/build-playbook.yml
```

Le esecuzioni successive riutilizzano chiavi e immagini già presenti. Per applicare modifiche ai Containerfile o ai file copiati nelle immagini, forzare la ricostruzione:

```bash
ansible-playbook step2-container-build/build-playbook.yml -e rebuild=true
```

## Verifica

Collegarsi a Ubuntu dalla macchina host:

```bash
ssh -i step2-container-build/keys/id_devops -p 2201 devops@localhost
```

Per Rocky Linux:

```bash
ssh -i step2-container-build/keys/id_devops -p 2202 devops@localhost
```

Dentro ciascun container:

```bash
sudo whoami
cat /etc/os-release
```

Il primo comando deve restituire `root`; il secondo mostra la distribuzione.
