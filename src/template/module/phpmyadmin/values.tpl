name: ${SEED_NAME}
image: ${SEED_IMAGE}
port: ${SEED_PORT}
user: ${SEED_USER}
caps: ${SEED_CAPS}
health: ${SEED_HEALTH}
target: ${SEED_TARGET}

env:
  PMA_HOST: "${SEED_TARGET}"
  PMA_PORT: "${SEED_TARGET_PORT}"
  APACHE_PORT: "${SEED_PORT}"
  PMA_ABSOLUTE_URI: "${SEED_URL}"
  UPLOAD_LIMIT: 64M

secretEnv: {}

files: {}
filesPath: /config

writable: []

resources:
  requests: { cpu: ${SEED_CPU}, memory: ${SEED_MEMORY} }
  limits: { memory: ${SEED_MEMORY_LIMIT} }

route:
  enabled: ${SEED_ROUTE}
  gateway: gateway
  gatewayNamespace: ${SEED_GATEWAY_NAMESPACE}
  sectionName: ${SEED_SECTION}
  hostnames: ${SEED_HOSTS}
  auth: ${SEED_AUTH}
  cidrs: ${SEED_CIDRS}

proxyNamespace: ${SEED_PROXY_NAMESPACE}
