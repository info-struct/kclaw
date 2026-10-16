{{/* Orchestrator Admin API URL used by Admin UI */}}
{{- define "kclaw.orchestratorAdminURL" -}}
http://kubeclaw-admin-api.{{ .Release.Namespace }}.svc.cluster.local:3002
{{- end -}}

{{/* In-cluster DNS for CredRouter */}}
{{- define "kclaw.credRouterURL" -}}
http://credrouter.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}

{{/* In-cluster DNS for LiteLLM */}}
{{- define "kclaw.litellmURL" -}}
http://litellm.{{ .Release.Namespace }}.svc.cluster.local:4000
{{- end -}}

{{/* In-cluster DNS for PostgreSQL */}}
{{- define "kclaw.postgresHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-postgresql.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
{{- else -}}
{{- .Values.postgresql.externalHost -}}
{{- end -}}
{{- end -}}

{{/* Node selector applied to all KClaw components */}}
{{- define "kclaw.nodeSelector" -}}
nodeSelector:
  kubernetes.io/hostname: {{ required "node is required — label a node with: kubectl label node <name> kclaw-node=true" .Values.node | quote }}
{{- end -}}

{{/* Common tolerations for control-plane nodes */}}
{{- define "kclaw.tolerations" -}}
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
{{- end -}}

{{/* Image pull secrets block */}}
{{- define "kclaw.imagePullSecrets" -}}
{{- if .Values.images.pullSecret }}
imagePullSecrets:
  - name: {{ .Values.images.pullSecret }}
{{- end -}}
{{- end -}}

{{/* Common labels */}}
{{- define "kclaw.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: kclaw
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: kclaw
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
