FROM alpine:3.14

ENV DEBIAN_FRONTEND=noninteractive

RUN apk add --update-cache \
    jq curl && \
    rm -rf /var/cache/apk/*

WORKDIR /app

RUN curl --silent --location https://cli.artifactscan.cloudone.trendmicro.com/tmas-cli/latest/tmas-cli_Linux_x86_64.tar.gz -o tmas.tgz && \
    tar xfvz tmas.tgz && \
    rm -rf THIRD-PARTY-LICENSES LICENSE.pdf README.md tmas.tgz

COPY tmas.sh .

ENTRYPOINT [ "/app/tmas.sh" ]
