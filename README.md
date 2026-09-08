# Registry locale con Ansible e Podman

Il progetto `formazione_cm` automatizza la creazione di un container registry: un servizio per caricare (`push`) e scaricare (`pull`) immagini.

Il laboratorio utilizza una VM Rocky Linux 9 con Vagrant e VirtualBox. Ansible e Podman vengono eseguiti nella stessa VM; Podman lavora in modalità **rootless**, quindi con l'utente normale, senza `sudo`.

## File del progetto

| File | Funzione |
| --- | --- |
| `ansible.cfg` | Imposta l'inventory e il rilevamento dell'interprete Python. |
| `inventory.ini` | Definisce `localhost` con connessione locale, senza SSH. |
| `container-playbook.yml` | Crea e verifica il registry. |

## Preparazione

All'interno della VM si installano i programmi necessari e la collection che contiene i moduli Ansible per Podman:

```bash
sudo dnf install -y ansible-core podman git
ansible-galaxy collection install containers.podman
```

Questi prerequisiti vengono installati manualmente, non dal playbook.

## Logica del playbook

Il playbook esegue in ordine queste operazioni:

1. **Scarica l'immagine** `docker.io/library/registry:2` tramite `podman_image`.
2. **Crea il volume** `registry_data` tramite `podman_volume`, per conservare le immagini caricate nel registry.
3. **Avvia il container** `registry` tramite `podman_container`, pubblicando la porta `5000` e montando il volume in `/var/lib/registry`.
4. **Configura il client Podman** creando `~/.config/containers/registries.conf.d/localhost-5000.conf`: `insecure = true` permette di utilizzare il registry locale in HTTP, senza TLS.
5. **Verifica il servizio** interrogando `/v2/_catalog`. Se non è ancora pronto, ripete la richiesta; infine mostra i repository presenti.

Nome, immagine, tag, porta e volume sono definiti in `vars`, per poterli modificare senza riscrivere i task. La raccolta dei fatti è disabilitata (`gather_facts: false`) perché non viene utilizzata.

`state: present` assicura che immagine e volume esistano; `state: started` assicura che il container sia avviato con la configurazione richiesta.

Il playbook è **idempotente**: interviene solo quando lo stato attuale non corrisponde a quello dichiarato. A configurazione invariata, una seconda esecuzione dovrebbe riportare `changed=0`.

## Esecuzione

Dalla directory del repository, nella VM:

```bash
ansible-playbook container-playbook.yml
```

Eseguire il comando senza `sudo`, per utilizzare lo stesso ambiente Podman rootless.

## Verifica

Controllare il container e il catalogo del registry:

```bash
podman ps
curl http://localhost:5000/v2/_catalog
```

Un registry vuoto restituisce `{"repositories":[]}`.

Per provare il caricamento e il download di un'immagine:

```bash
podman pull docker.io/library/alpine:3.20
podman tag docker.io/library/alpine:3.20 localhost:5000/alpine:test
podman push localhost:5000/alpine:test
podman pull localhost:5000/alpine:test
curl http://localhost:5000/v2/alpine/tags/list
```

Il comando `tag` assegna all'immagine un nome che indica il registry di destinazione; `push` la carica e `pull` la recupera. L'ultima richiesta deve mostrare il repository `alpine` con il tag `test`.

## Persistenza e limiti

- Il volume conserva i dati anche quando il container viene ricreato, purché venga riutilizzato e non eliminato. Un semplice riavvio del container non cancella i dati.
- `restart_policy: always` non configura, da sola, l'avvio automatico del container rootless al boot della VM. Questo aspetto richiede una configurazione aggiuntiva.
- Il registry non usa TLS né autenticazione: è destinato esclusivamente al laboratorio. La mappatura `5000:5000` non limita l'ascolto a `localhost`; altre macchine potrebbero raggiungerlo se rete e firewall lo consentono.
