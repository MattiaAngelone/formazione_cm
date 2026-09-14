# Step 3 — Ruoli Ansible

Utilizzando i precedenti Step come task, crea più ruoli Ansibile con le seguenti caratteristiche:
- Creazione e configurazione di un registry 
- Build di almeno due container 
- Push delle build sul registry precedentemente creato
- Run dei container in modo che non vadano in conflitto di porte tra loro
- Creare uno o più ruoli che funzionino sia con Docker che con Podman 

Gli Step 1 e 2 vengono organizzati in ruoli parametrizzati, utilizzabili con **Podman o Docker**. Il playbook crea un registry locale, costruisce e pubblica immagini Ubuntu e Rocky Linux, quindi avvia i container su porte distinte.

## Organizzazione

`site.yml` esegue i tre ruoli nell’ordine indicato:

| Ruolo | Funzione |
| --- | --- |
| `container_engine` | Seleziona il motore da utilizzare. |
| `container_registry` | Configura e avvia il registry. |
| `container_images` | Prepara il contesto, costruisce e pubblica le immagini, avvia i container. |

La scelta del motore è separata perché serve agli altri due ruoli. Build, push e run sono raggruppati perché gestiscono il ciclo di vita della stessa lista di immagini.

## Funzionamento

1. **Scelta del motore.** Cerca i comandi con `which` e imposta `container_engine`: preferisce Podman, altrimenti seleziona Docker. Il motore deve essere già installato e utilizzabile.
2. **Preparazione del registry.** Configura l’accesso HTTP (*insecure*), crea un volume persistente e avvia il registry. Attende una risposta HTTP 200 da `/v2/_catalog` prima di procedere.
3. **Gestione delle immagini.** Genera la chiave SSH se manca e prepara il contesto di build con chiave pubblica, configurazione SSH e Containerfile. Questi file devono esistere prima della build perché vengono letti dai `COPY`. Le immagini sono costruite con il riferimento completo, ad esempio `localhost:5000/ssh-ubuntu:latest`, e pubblicate senza aggiungere un altro tag.

I container mantengono SSH sulla porta interna **22**, con accesso tramite chiave per `devops` e sudo senza password. Le porte host seguono la formula `images_base_port + indice + 1`: con base `2200` e indice iniziale zero, Ubuntu usa **2201** e Rocky **2202**. Tutte le porte pubblicate sono associate a `127.0.0.1`.

## Supporto Docker e Podman

I due ruoli operativi mantengono i task comuni in `tasks/main.yml` e selezionano quelli specifici tramite:

```yaml
- name: Carica i task del motore
  ansible.builtin.include_tasks: "{{ container_engine }}.yml"
```

I file `podman.yml` e `docker.yml` usano gli stessi parametri con moduli differenti. Nel percorso Podman build e push condividono un task; in quello Docker sono separati.

## Esecuzione e parametri

I principali parametri sono in `defaults/main.yml`: registry, tag, percorsi, utente SSH e `images_list`. Si possono sovrascrivere con `-e`.

Servono Ansible e la collection del motore scelto (`containers.podman` o `community.docker`); la build Docker richiede anche Buildx.

Dalla radice di `formazione_cm`, nella VM Linux:

```bash
# Selezione automatica
ansible-playbook step3-roles/site.yml

# Forza Docker
ansible-playbook step3-roles/site.yml -e container_engine=docker

# Porte 2401 e 2402: il JSON conserva il tipo numerico
ansible-playbook step3-roles/site.yml -e '{"images_base_port":2400}'
```

## Verifica

Con Podman selezionato:

```bash
curl -s http://127.0.0.1:5000/v2/_catalog
podman ps
ssh -i ~/.ssh/formazione_cm/id_devops -p 2201 devops@127.0.0.1
```

Per Rocky usare `2202`; con Docker sostituire `podman ps` con `docker ps`. Dentro il container, `sudo whoami` deve restituire `root` e `cat /etc/os-release` confermare la distribuzione.
