name: ${SEED_NAME}
image: ${SEED_IMAGE}
port: ${SEED_PORT}
user: ${SEED_USER}
caps: ${SEED_CAPS}
health: ${SEED_HEALTH}
target: ${SEED_TARGET}

env:
  PGADMIN_LISTEN_PORT: "${SEED_PORT}"
  PGADMIN_DEFAULT_EMAIL: "${SEED_EMAIL}"
  PGADMIN_SERVER_JSON_FILE: /config/servers.json
  PGADMIN_DISABLE_POSTFIX: "true"

secretEnv:
  PGADMIN_DEFAULT_PASSWORD: PASSWORD

files:
  servers.json: |
    {"Servers": {"1": {"Name": "${SEED_TARGET}", "Group": "${SEED_PROJECT}", "Host": "${SEED_TARGET}", "Port": ${SEED_TARGET_PORT}, "MaintenanceDB": "postgres", "Username": "${SEED_TARGET_USER}", "SSLMode": "prefer"}}}
filesPath: /config

writable: [/var/lib/pgadmin, /tmp]

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
