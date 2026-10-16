{{/*
Chart name, release-aware full name, and the chart label.
Same conventions as `helm create`, trimmed to 63 chars for DNS.
*/}}
{{- define "ledger.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "ledger.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "ledger.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels every object gets. Usage: {{ include "ledger.labels" (dict "root" . "component" "backend") }}
*/}}
{{- define "ledger.labels" -}}
helm.sh/chart: {{ include "ledger.chart" .root }}
{{ include "ledger.selectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: {{ include "ledger.name" .root }}
{{- end }}

{{/*
The subset used by selectors - must be stable across upgrades, so no chart
version in here. Usage: {{ include "ledger.selectorLabels" (dict "root" . "component" "backend") }}
*/}}
{{- define "ledger.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ledger.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Full image reference: <registry>/<repository>:<tag>, tag falling back to appVersion.
Usage: {{ include "ledger.image" (dict "root" . "image" .Values.backend.image) }}
*/}}
{{- define "ledger.image" -}}
{{- $tag := default .root.Chart.AppVersion .image.tag -}}
{{- if .root.Values.image.registry -}}
{{- printf "%s/%s:%s" .root.Values.image.registry .image.repository $tag -}}
{{- else -}}
{{- printf "%s:%s" .image.repository $tag -}}
{{- end -}}
{{- end }}

{{/* Object names. Services keep fixed short names because nginx.conf and DATABASE_URL use them. */}}
{{- define "ledger.backend.fullname" -}}
{{ include "ledger.fullname" . }}-backend
{{- end }}
{{- define "ledger.frontend.fullname" -}}
{{ include "ledger.fullname" . }}-frontend
{{- end }}
{{- define "ledger.postgres.fullname" -}}
{{ include "ledger.fullname" . }}-postgres
{{- end }}
{{- define "ledger.configmap.name" -}}
{{ include "ledger.fullname" . }}-config
{{- end }}
{{- define "ledger.secret.name" -}}
{{ include "ledger.fullname" . }}-secret
{{- end }}

{{/* The SQLAlchemy URL the backend and alembic read. */}}
{{- define "ledger.databaseUrl" -}}
{{- printf "postgresql+psycopg://%s:%s@%s:%v/%s" .Values.postgres.auth.username .Values.postgres.auth.password .Values.postgres.service.name .Values.postgres.service.port .Values.postgres.auth.database -}}
{{- end }}
