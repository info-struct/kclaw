{{/*
Resolve auto-generated secrets. On first install these are generated with randAlphaNum;
on upgrade the existing Secret is looked up and its values reused, so secrets are stable.
*/}}
{{- define "kclaw.secrets" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace "kclaw-generated-secrets" -}}
{{- $encKey   := ternary (index $existing.data "encryption-key"   | b64dec) (randAlphaNum 32)     (and (not (empty $existing)) (hasKey $existing.data "encryption-key")) -}}
{{- $jwtSec   := ternary (index $existing.data "jwt-secret"       | b64dec) (randAlphaNum 48)     (and (not (empty $existing)) (hasKey $existing.data "jwt-secret")) -}}
{{- $admTok   := ternary (index $existing.data "admin-token"      | b64dec) (randAlphaNum 32)     (and (not (empty $existing)) (hasKey $existing.data "admin-token")) -}}
{{- $litKey   := ternary (index $existing.data "litellm-key"      | b64dec) (printf "sk-litellm-%s" (randAlphaNum 24))  (and (not (empty $existing)) (hasKey $existing.data "litellm-key")) -}}
{{- $pgPass   := ternary (index $existing.data "pg-password"      | b64dec) (randAlphaNum 24)     (and (not (empty $existing)) (hasKey $existing.data "pg-password")) -}}
{{- /* User-supplied values override auto-generated ones */ -}}
{{- if .Values.secrets.encryptionKey  }}{{- $encKey  = .Values.secrets.encryptionKey  -}}{{- end -}}
{{- if .Values.secrets.jwtSecret      }}{{- $jwtSec  = .Values.secrets.jwtSecret      -}}{{- end -}}
{{- if .Values.secrets.adminToken     }}{{- $admTok  = .Values.secrets.adminToken     -}}{{- end -}}
{{- if .Values.secrets.litellmMasterKey }}{{- $litKey = .Values.secrets.litellmMasterKey -}}{{- end -}}
{{- if .Values.secrets.postgresPassword }}{{- $pgPass = .Values.secrets.postgresPassword -}}{{- end -}}
encryption-key: {{ $encKey }}
jwt-secret: {{ $jwtSec }}
admin-token: {{ $admTok }}
litellm-key: {{ $litKey }}
pg-password: {{ $pgPass }}
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
