{{/*
Expand the name of the chart.
*/}}
{{- define "mizrahi-apps.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mizrahi-apps.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels for ArgoCD Applications
*/}}
{{- define "mizrahi-apps.labels" -}}
helm.sh/chart: {{ include "mizrahi-apps.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mizrahi-bank
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Sync policy template
*/}}
{{- define "mizrahi-apps.syncPolicy" -}}
automated:
  prune: {{ .Values.global.syncPolicy.automated.prune }}
  selfHeal: {{ .Values.global.syncPolicy.automated.selfHeal }}
syncOptions:
  {{- range .Values.global.syncPolicy.syncOptions }}
  - {{ . }}
  {{- end }}
retry:
  limit: {{ .Values.global.syncPolicy.retry.limit }}
  backoff:
    duration: {{ .Values.global.syncPolicy.retry.backoff.duration }}
    factor: {{ .Values.global.syncPolicy.retry.backoff.factor }}
    maxDuration: {{ .Values.global.syncPolicy.retry.backoff.maxDuration }}
{{- end }}
