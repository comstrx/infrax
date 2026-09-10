name: ${SEED_NAME}
mode: ${SEED_MODE}
image: ${SEED_IMAGE}
port: ${SEED_PORT}
user: ${SEED_USER}
address: "${SEED_ADDRESS}"

env:
  POSTGRES_USER: "${SEED_ROOT_USER}"
  POSTGRES_DB: postgres
  PGDATA: /var/lib/postgresql/data/pgdata
  POSTGRES_INITDB_ARGS: "--locale-provider=icu --icu-locale=und --encoding=UTF8"

secretEnv:
  POSTGRES_PASSWORD: ROOT_PASSWORD

dataPath: /var/lib/postgresql/data

probe:
  exec:
    command: [pg_isready, -U, "${SEED_ROOT_USER}", -h, 127.0.0.1]

resources:
  requests: { cpu: ${SEED_CPU}, memory: ${SEED_MEMORY} }
  limits: { memory: ${SEED_MEMORY_LIMIT} }

storage:
  class: ${SEED_VOLUME_CLASS}
  size: ${SEED_SIZE}

clients: ${SEED_CLIENTS}
metricsNamespace: ${SEED_METRICS_NAMESPACE}

scripts:${SEED_SCRIPTS}

init:${SEED_INIT}

backup:
  enabled: ${SEED_BACKUP}
  schedule: "${SEED_BACKUP_SCHEDULE}"
  target: ${SEED_BACKUP_TARGET}
  databases: ${SEED_DATABASES}
  prefix: "${SEED_BACKUP_PREFIX}"
  account: ${SEED_BACKUP_ACCOUNT}
  keepDays: ${SEED_BACKUP_KEEP_DAYS}
  uploader:
    image: ${SEED_UPLOADER_IMAGE}
    command: ${SEED_UPLOADER_COMMAND}
    env: ${SEED_UPLOADER_ENV}
  storage:
    class: ${SEED_VOLUME_CLASS}
    size: ${SEED_BACKUP_SIZE}
