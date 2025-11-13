ARG SCRIPT_NAME=ipregion.sh
ARG WORK_DIR=/app
ARG USER=ipregion

FROM alpine:3.21

ARG SCRIPT_NAME
ARG WORK_DIR
ARG USER

RUN apk add --no-cache \
  curl \
  jq \
  bash \
  util-linux \
  iputils \
  grep

WORKDIR $WORK_DIR

COPY $SCRIPT_NAME .

RUN adduser --disabled-password --home $WORK_DIR $USER && \
  chmod +x $SCRIPT_NAME

USER $USER

ENTRYPOINT ["./ipregion.sh"]
