# Usa nginx per servire la pagina web dell'esercizio
FROM docker.io/library/nginx:1.31.6-alpine

# Riceve il numero di build da jenkins
ARG BUILD_NUMBER=0

# Scrive il numero nella pagina per riconoscere la versione distribuita
RUN echo "<h1>formazione_cm - build ${BUILD_NUMBER}</h1>" \
    > /usr/share/nginx/html/index.html
