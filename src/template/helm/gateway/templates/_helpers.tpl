{{- define "gateway.routeNamespaces" -}}
{{- if .Values.routeNamespaces -}}
from: Selector
selector:
  matchExpressions:
    - key: kubernetes.io/metadata.name
      operator: In
      values: [{{ join ", " (concat .Values.routeNamespaces (list .Release.Namespace) | uniq) }}]
{{- else -}}
from: All
{{- end -}}
{{- end -}}
