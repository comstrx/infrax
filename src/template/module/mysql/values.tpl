name: ${SEED_NAME}
mode: ${SEED_MODE}
image: ${SEED_IMAGE}
port: ${SEED_PORT}
user: ${SEED_USER}
address: "${SEED_ADDRESS}"

env:
  MYSQL_USER: "${SEED_ROOT_USER}"

secretEnv:
  MYSQL_ROOT_PASSWORD: ROOT_PASSWORD
  MYSQL_PASSWORD: ROOT_PASSWORD

dataPath: /var/lib/mysql

probe:
  exec:
    command: [mysqladmin, ping, -h, 127.0.0.1, --silent]

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
