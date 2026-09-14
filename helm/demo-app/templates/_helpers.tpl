{{/*
_helpers.tpl
-------------
Funciones/templates parciales reusables por el resto de los templates del
chart. Es la convención estándar de Helm: nombres/labels consistentes
definidos UNA vez acá, en vez de repetir la misma lógica de nombres en
cada archivo de templates/.
*/}}

{{/* Nombre base del chart (o el override si se pasó nameOverride). */}}
{{- define "demo-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Nombre completo del release, usado como prefijo en la mayoría de los
recursos (ej: "demo-app-dev-demo-app"). Se trunca a 63 caracteres porque
es el límite de un label/nombre de recurso en Kubernetes (DNS-1123).
*/}}
{{- define "demo-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Labels "comunes": van en metadata.labels de TODOS los recursos. */}}
{{- define "demo-app.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "demo-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Labels "selector": subconjunto MÍNIMO de labels usado para que el
Deployment sepa qué Pods son suyos (spec.selector) y el Service sepa a
qué Pods enrutar. Deliberadamente NO incluye cosas como la versión: si
esos labels cambiaran en cada release, el selector "perdería" los pods
viejos durante un rolling update.
*/}}
{{- define "demo-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "demo-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Nombre del ServiceAccount a usar (creado por el chart o provisto externamente). */}}
{{- define "demo-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "demo-app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
