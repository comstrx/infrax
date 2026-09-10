name: ${SEED_NAME}
mode: ${SEED_MODE}
image: ${SEED_IMAGE}
port: ${SEED_PORT}
user: ${SEED_USER}
address: "${SEED_ADDRESS}"

command: [sh, -c, 'exec redis-server --appendonly yes --requirepass "$REDIS_PASSWORD"']

env: {}

secretEnv:
  REDIS_PASSWORD: ROOT_PASSWORD

dataPath: /data

probe:
  tcpSocket:
    port: ${SEED_PORT}

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
  enabled: false
