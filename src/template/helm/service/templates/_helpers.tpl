{{- define "service.name" -}}
{{- .Values.name | default .Release.Name -}}
{{- end -}}

{{- define "service.labels" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
infrax.io/runtime: {{ .Values.runtime | default "none" }}
{{- end -}}

{{- define "service.selector" -}}
app.kubernetes.io/name: {{ include "service.name" . }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "service.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | toString) -}}
{{- end -}}

{{- define "service.pullSecrets" -}}
{{- with .Values.imagePullSecrets -}}
imagePullSecrets:
{{- range . }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{- define "service.podSecurity" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: {{ .Values.user }}
  runAsGroup: {{ .Values.user }}
  fsGroup: {{ .Values.user }}
  seccompProfile:
    type: RuntimeDefault
{{- end -}}

{{- define "service.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
{{- end -}}

{{- define "service.probes" -}}
{{- $values := .root.Values -}}
{{- if and (eq $values.probe "http") $values.health }}
startupProbe:
  httpGet:
    path: {{ $values.health }}
    port: {{ .port }}
  periodSeconds: 5
  failureThreshold: 36
readinessProbe:
  httpGet:
    path: {{ $values.health }}
    port: {{ .port }}
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: {{ $values.health }}
    port: {{ .port }}
  periodSeconds: 20
{{- else if eq $values.probe "grpc" }}
startupProbe:
  grpc:
    port: {{ .port }}
  periodSeconds: 5
  failureThreshold: 36
readinessProbe:
  grpc:
    port: {{ .port }}
  periodSeconds: 10
livenessProbe:
  grpc:
    port: {{ .port }}
  periodSeconds: 20
{{- else }}
readinessProbe:
  tcpSocket:
    port: {{ .port }}
  periodSeconds: 10
livenessProbe:
  tcpSocket:
    port: {{ .port }}
  periodSeconds: 20
{{- end }}
{{- end -}}

{{- define "service.env" -}}
- name: INFRAX_SERVICE
  value: {{ include "service.name" .root | quote }}
- name: INFRAX_PROCESS
  value: {{ .process | quote }}
- name: INFRAX_RELEASE
  value: {{ .root.Values.image.tag | quote }}
- name: PORT
  value: {{ .port | quote }}
{{- end -}}

{{- define "service.responseHeaders" -}}
{{- if or .set .remove -}}
filters:
  - type: ResponseHeaderModifier
    responseHeaderModifier:
    {{- with .set }}
      set:
      {{- range $name, $value := . }}
        - name: {{ $name }}
          value: {{ $value | quote }}
      {{- end }}
    {{- end }}
    {{- with .remove }}
      remove:
      {{- range . }}
        - {{ . }}
      {{- end }}
    {{- end }}
{{- end -}}
{{- end -}}
