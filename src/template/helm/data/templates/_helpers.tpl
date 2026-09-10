{{- define "data.name" -}}
{{- .Values.name | default .Release.Name -}}
{{- end -}}

{{- define "data.labels" -}}
app.kubernetes.io/name: {{ include "data.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
infrax.io/module: {{ include "data.name" . }}
{{- end -}}

{{- define "data.security" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: {{ .Values.user }}
  runAsGroup: {{ .Values.user }}
  fsGroup: {{ .Values.user }}
  seccompProfile:
    type: RuntimeDefault
{{- end -}}

{{- define "data.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
{{- end -}}

{{- define "data.probe" -}}
{{- if .Values.probe -}}
{{- toYaml .Values.probe -}}
{{- else -}}
tcpSocket:
  port: tcp
{{- end -}}
{{- end -}}

{{- define "data.root" -}}
- name: ROOT_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "data.name" . }}-secrets
      key: ROOT_USER
- name: ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "data.name" . }}-secrets
      key: ROOT_PASSWORD
{{- end -}}
