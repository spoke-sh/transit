{{- define "transit.name" -}}
{{- printf "%s-server" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "transit.labels" -}}
app.kubernetes.io/name: transit
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/component: server
{{- end -}}
{{- define "transit.config" -}}
version: 1
installation: /data/.transit
startup:
  require_existing: {{ if eq .Values.requireExisting nil }}{{ or .Release.IsUpgrade (ne .Values.persistence.existingClaim "") }}{{ else }}{{ .Values.requireExisting }}{{ end }}
logging:
  format: json
  level: info
board: null
sql:
  native:
    local: true
    http:
      address: 0.0.0.0
      port: 19109
      tls: true
      certificate_file: /secrets/tls.crt
      key_file: /secrets/tls.key
  accounts:
    - name: {{ .Values.account | quote }}
      role: local_owner
      authentication: password
      password_file: /secrets/password
      bootstrap_owner: true
{{- end -}}
