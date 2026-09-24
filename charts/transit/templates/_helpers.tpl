{{- define "transit.name" -}}
{{- $settings := index .root.Values .component -}}
{{- default (printf "%s-%s" .root.Release.Name (.component | kebabcase) | trunc 63 | trimSuffix "-") $settings.nameOverride -}}
{{- end -}}

{{- define "transit.labels" -}}
app.kubernetes.io/name: transit
app.kubernetes.io/instance: {{ .root.Release.Name | quote }}
app.kubernetes.io/component: {{ .component | quote }}
app: {{ include "transit.name" . | quote }}
{{- end -}}

{{- define "transit.nodeConfig" -}}
{{- $config := deepCopy .Values.node.config -}}
{{- $_ := required "node.config.genesis is required" $config.genesis -}}
{{- if .Values.ursula.enabled -}}
{{- $_ := set $config "ursula_url" (printf "http://%s:8080" (include "transit.name" (dict "root" . "component" "ursula"))) -}}
{{- else -}}
{{- $_ := required "node.config.ursula_url is required with external Ursula" $config.ursula_url -}}
{{- end -}}
{{- $_ := set $config "listen" "0.0.0.0" -}}
{{- $_ := set $config "port" 8080 -}}
{{- toJson $config -}}
{{- end -}}

{{- define "transit.boardConfig" -}}
{{- $config := deepCopy .Values.board.config -}}
{{- $_ := required "board.config.public_origin is required" $config.public_origin -}}
{{- $_ := set $config "upstream" (printf "http://%s:8080" (include "transit.name" (dict "root" . "component" "node"))) -}}
{{- $_ := set $config "listen" "0.0.0.0" -}}
{{- $_ := set $config "port" 8080 -}}
{{- $_ := set $config "seed_file" "/secrets/seed" -}}
{{- $_ := set $config "credential_file" "/secrets/access" -}}
{{- toJson $config -}}
{{- end -}}

{{- define "transit.config" -}}
{{- if eq .component "node" -}}
{{- include "transit.nodeConfig" .root -}}
{{- else if eq .component "maintenance" -}}
{{- $config := include "transit.nodeConfig" .root | fromJson -}}
{{- $maintenance := deepCopy .root.Values.maintenance.config -}}
{{- $_ := set $maintenance "seed_file" "/secrets/seed" -}}
{{- $_ := set $config "maintenance" $maintenance -}}
{{- toJson $config -}}
{{- else if eq .component "board" -}}
{{- include "transit.boardConfig" .root -}}
{{- else if eq .component "controller" -}}
{{- $config := deepCopy .root.Values.controller.config -}}
{{- $_ := required "controller.config.provider is required" $config.provider -}}
{{- $_ := set $config "url" (printf "http://%s:8080" (include "transit.name" (dict "root" .root "component" "node"))) -}}
{{- $_ := set $config "seed_file" "/secrets/seed" -}}
{{- $_ := set $config.provider "kubeconfig" "/config/kubeconfig" -}}
{{- $_ := set $config.provider "context" "controller" -}}
{{- $_ := set $config.provider "endpoint" .root.Values.controller.providerEndpoint -}}
{{- $_ := set $config.provider "token_file" "/provider/token" -}}
{{- $_ := set $config.provider "egress_policy_file" "/config/egress.json" -}}
{{- toJson $config -}}
{{- else -}}
[server]
listen = "0.0.0.0:8080"
admin_listen = "0.0.0.0:8081"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "/data/wal"
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
{{- end -}}
{{- end -}}
