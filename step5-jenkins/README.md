# step 5 — jenkins e ansible

Pipeline che costruisce un’immagine web, la pubblica su un registry locale con un **tag progressivo** e la distribuisce tramite Ansible in un container con Docker-in-Docker (DinD).

## Architettura

Jenkins gira come servizio sulla VM e usa il suo Docker per costruire le immagini. Il container `target` esegue un **secondo motore Docker indipendente**, nel quale viene avviata l’applicazione.

| Componente | Funzione | Porta sulla VM |
| --- | --- | --- |
| Jenkins | Esegue la pipeline e richiama Ansible | `8080` |
| `registry` | Conserva le immagini pubblicate | `5000` |
| `target` | Riceve le connessioni SSH e ospita Docker | `2210` → SSH interno `22` |
| `webapp` | Mostra una pagina Nginx con il numero di build | `8081` |

`registry` e `target` condividono la rete Docker `cm-net`. Per raggiungere l’applicazione, la porta viene pubblicata su entrambi i livelli: **VM `8081` → target `8081` → webapp `80`**.

## Come funziona la pipeline

Il file `step5-jenkins/Jenkinsfile` definisce tre fasi:

1. **Build:** costruisce l’immagine Nginx e inserisce `BUILD_NUMBER` nella pagina HTML. Assegna due tag: `registry:5000/webapp:<numero>` e `registry:5000/webapp:latest`. Il numero aumenta a ogni esecuzione dello stesso job.
2. **Push:** pubblica entrambi i tag sul registry. Il tag numerico distingue le build; `latest` viene aggiornato a ogni pubblicazione.
3. **Deploy:** il plugin Ansible esegue `deploy.yml`, passando il numero di build. Ansible entra nel target via SSH, usa `become: true` per operare come root, scarica l’immagine con quel tag e ricrea `webapp` tramite `recreate: true`.

Il deploy usa il **tag numerico**: la versione avviata corrisponde alla build della pipeline.

## Configurazioni importanti

- **Nome del registry:** sulla VM, `registry` risolve a `127.0.0.1` tramite `/etc/hosts`; nel target viene risolto dal DNS di `cm-net`. Entrambi possono così usare `registry:5000`. Poiché il registry usa HTTP, è configurato come *insecure* nei due demoni Docker.
- **Avvio del target:** l’immagine `docker:dind` viene configurata con SSH, Python e l’utente `devops`, autorizzato tramite chiave e abilitato a sudo senza password. L’entrypoint avvia `sshd` in background e passa il controllo a `dockerd-entrypoint.sh` per avviare Docker.
- **Credenziali:** la chiave privata è salvata nelle Jenkins Credentials con ID `dind-ssh-key`. Il plugin la fornisce ad Ansible durante l’esecuzione; repository e inventario non la contengono.
- **Strumenti Jenkins:** l’utente `jenkins` deve poter usare Docker e Ansible e trovare la collection `community.docker`. Il plugin **Ansible** fornisce `ansiblePlaybook`; build e push usano direttamente la CLI Docker.

## Esecuzione e verifica

Con registry e target già avviati, configura un job Jenkins di tipo **Pipeline script from SCM**, indicando repository, branch e percorso `step5-jenkins/Jenkinsfile`. Avvialo con **Build Now**.

Dalla VM:

```bash
# Tag pubblicati sul registry
curl -s http://registry:5000/v2/webapp/tags/list

# Versione effettivamente servita dall’applicazione
curl -s http://127.0.0.1:8081

# Container in esecuzione nel Docker interno al target
docker exec target docker ps
```

Eseguendo nuovamente il job, devono comparire un nuovo tag numerico e lo stesso numero nella pagina web.
