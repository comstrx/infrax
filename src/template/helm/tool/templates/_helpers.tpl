{{- define "tool.name" -}}
{{- .Values.name | default .Release.Name -}}
{{- end -}}

{{- define "tool.labels" -}}
app.kubernetes.io/name: {{ include "tool.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
infrax.io/module: {{ include "tool.name" . }}
{{- end -}}
