name: ${SEED_NAME}
runtime: ${SEED_RUNTIME}

image:
  repository: ${SEED_IMAGE}
  tag: "${SEED_TAG}"
  pullPolicy: IfNotPresent

imagePullSecrets: ${SEED_PULL_SECRETS}

user: ${SEED_USER}
port: ${SEED_PORT}
probe: ${SEED_PROBE}
health: "${SEED_HEALTH}"

env:${SEED_ENV}

processes:${SEED_PROCESSES}

autoscaling:
  min: ${SEED_REPLICAS_MIN}
  max: ${SEED_REPLICAS_MAX}
  cpu: ${SEED_CPU_TARGET}

rollout:
  surge: ${SEED_SURGE}
  unavailable: ${SEED_UNAVAILABLE}

storage:
  enabled: ${SEED_VOLUME}
  class: ${SEED_VOLUME_CLASS}
  size: ${SEED_VOLUME_SIZE}
  mount: "${SEED_MOUNT}"

route:
  enabled: ${SEED_ROUTE}
  gateway: gateway
  gatewayNamespace: ${SEED_GATEWAY_NAMESPACE}
  sectionName: ${SEED_SECTION}
  hostnames: ${SEED_HOSTS}

netpol:
  proxyNamespace: ${SEED_PROXY_NAMESPACE}
  metricsNamespace: "${SEED_METRICS_NAMESPACE}"
  callers: ${SEED_CALLERS}

migrate:
  command: ${SEED_MIGRATE}

provision: ${SEED_PROVISION}

metrics:
  path: "${SEED_METRICS}"

serviceAccount:
  annotations: ${SEED_ACCOUNT}
