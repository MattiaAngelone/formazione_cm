# Step 2 — Build di container SSH con Ansible e Podman

Playbook Ansible che automatizza la build di due container con OS differenti, con
queste caratteristiche:

- Essere sempre in ascolto sulla porta 22 del container
- Avere attivo il servizio ssh
- Avere un utente abilitato a collegarsi tramite ssh key e poter fare sudo

Ansible esegue le operazioni sulla macchina locale; Podman costruisce le immagini
e gestisce i container.

| Sistema | Immagine | Container | Porta host → container |
|---|---|---|---|
| Ubuntu 24.04 | `ssh-ubuntu:<hash>` | `ssh-ubuntu` | `127.0.0.1:2201 → 22` |
| Rocky Linux 9 | `ssh-rocky:<hash>` | `ssh-rocky` | `127.0.0.1:2202 → 22` |

Il tag non è fisso: è calcolato dal contenuto del contesto di build, come spiegato
sotto.

---

## Logica del playbook

`step2-build-container/build-playbook.yml` svolge cinque operazioni in ordine.

**1. Prepara le chiavi SSH.** Genera una coppia Ed25519 in
`~/.ssh/formazione_cm/`, fuori dall'albero versionato. Il parametro `creates`
rende idempotente un comando che di suo non lo è: se la chiave esiste, il task
viene saltato.

**2. Prepara il contesto di build.** Copia la chiave pubblica come
`authorized_keys` e rende `sshd_hardening.conf` dal template `.j2`, sostituendo
il nome utente.

**3. Calcola il tag dal contenuto.** Prende il checksum di ogni file del contesto
— i due Containerfile, `authorized_keys`, `sshd_hardening.conf` — e li riduce a
un'unica impronta, che diventa il tag delle immagini.

**4. Costruisce le immagini.** Un ciclo sulla lista `images` richiama
`containers.podman.podman_image` per entrambi i Containerfile, i file generati sono condivisi nello stesso contesto di build; il nome utente viene passato tramite SSH_USER.

**5. Avvia i container.** Un secondo ciclo usa
`containers.podman.podman_container` per portarli nello stato `started` e
pubblicare le porte sul loopback.

---

## Il tag calcolato dal contenuto

Con un tag fisso come `latest`, il nome dell'immagine non cambia mai. Ansible
guarda solo quel nome, quindi con una chiave nuova sul disco, container che gira ancora con quella vecchia.

Con il tag derivato dal contenuto, l'impronta cambia insieme ai file, e se non cambia nulla, l'impronta è identica e il playbook resta a `changed=0`.

In questo modo l'idempotenza diventa corretta. Prima riportava "nulla è
cambiato" anche quando qualcosa era cambiato.

---

## Funzionamento dei container

`Containerfile.ubuntu` e `Containerfile.rocky` installano OpenSSH e sudo, creano
l'utente `devops` e gli consentono `sudo` **senza password**.

La chiave pubblica viene installata in `.ssh/authorized_keys`

La configurazione SSH permette l’accesso con chiave pubblica all’utente previsto e disabilita l’accesso diretto come root e l’autenticazione tramite password. Le chiavi host del server SSH vengono generate durante la build con ssh-keygen -A

all'avvio viene eseguito:

```
/usr/sbin/sshd -D -e
```

- `-D` mantiene sshd in primo piano: se si mettesse in background il container si
  chiuderebbe subito, perché per Podman il processo principale sarebbe finito
- `-e` invia i log su standard error, consultabile con `podman logs`

---

## Esecuzione

Servono Ansible, Podman e la collection `containers.podman`.

Dalla radice della repo, così `ansible.cfg` viene letto:

```bash
ansible-playbook step2-build-container/build-playbook.yml
```

Alla seconda esecuzione: `changed=0`.

Non serve forzare nulla. Modificando un Containerfile, la configurazione sshd o
la chiave SSH, il tag cambia e build e ricreazione dei container partono da sole.

---

## Verifica

```bash
podman ps
```

La colonna IMAGE mostra il tag corrente.

```bash
ssh -i ~/.ssh/formazione_cm/id_devops -p 2201 \
    -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
    devops@127.0.0.1
```

Per Rocky, porta `2202`. Dentro il container, `sudo whoami` deve restituire
`root` e `cat /etc/os-release` confermare la distribuzione.
