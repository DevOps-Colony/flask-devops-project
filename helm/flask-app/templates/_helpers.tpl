{{/*
Expand the name of the chart.
*/}}
{{- define "flask-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flask-app.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flask-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flask-app.labels" -}}
helm.sh/chart: {{ include "flask-app.chart" . }}
{{ include "flask-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.project_name | default "flask-auth-system" }}
environment: {{ .Values.environment }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flask-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flask-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flask-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flask-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "flask-app.secretName" -}}
{{- if .Values.secrets.create }}
{{- default (include "flask-app.fullname" .) .Values.secrets.name }}
{{- else }}
{{- required "A secret name is required when secrets.create is false" .Values.secrets.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap to use
*/}}
{{- define "flask-app.configMapName" -}}
{{- if .Values.configMap.create }}
{{- default (include "flask-app.fullname" .) .Values.configMap.name }}
{{- else }}
{{- required "A configMap name is required when configMap.create is false" .Values.configMap.name }}
{{- end }}
{{- end }}
