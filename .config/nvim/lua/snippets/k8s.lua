local ls = require "luasnip"
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node

local K8S_BASE = "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/v1.36.0-standalone-strict/"

local API_KINDS = {
  ["v1"] = {
    "Pod",
    "Service",
    "ConfigMap",
    "Secret",
    "Namespace",
    "ServiceAccount",
    "PersistentVolumeClaim",
    "PersistentVolume",
    "Endpoints",
    "LimitRange",
    "ResourceQuota",
    "ReplicationController",
    "Node",
  },
  ["apps/v1"] = { "Deployment", "StatefulSet", "DaemonSet", "ReplicaSet" },
  ["batch/v1"] = { "Job", "CronJob" },
  ["networking.k8s.io/v1"] = { "Ingress", "IngressClass", "NetworkPolicy" },
  ["rbac.authorization.k8s.io/v1"] = { "Role", "ClusterRole", "RoleBinding", "ClusterRoleBinding" },
  ["autoscaling/v2"] = { "HorizontalPodAutoscaler" },
  ["policy/v1"] = { "PodDisruptionBudget" },
  ["storage.k8s.io/v1"] = { "StorageClass", "VolumeAttachment", "CSIDriver" },
  ["apiextensions.k8s.io/v1"] = { "CustomResourceDefinition" },
}

local API_VERSIONS = {
  "v1",
  "apps/v1",
  "batch/v1",
  "networking.k8s.io/v1",
  "rbac.authorization.k8s.io/v1",
  "autoscaling/v2",
  "policy/v1",
  "storage.k8s.io/v1",
  "apiextensions.k8s.io/v1",
}

local function modeline(file)
  return "# yaml-language-server: $schema=" .. K8S_BASE .. file
end

local function detect_kind_api()
  local lines = vim.api.nvim_buf_get_lines(0, 0, math.min(vim.api.nvim_buf_line_count(0), 40), false)
  local kind, api_version
  for _, line in ipairs(lines) do
    if not api_version then api_version = line:match("^%s*apiVersion:%s*([%w./%-]+)") end
    if not kind then kind = line:match("^%s*kind:%s*([%w]+)") end
  end
  return kind, api_version
end

local function k8s_schema_file(kind, api_version)
  if not kind then return "all.json" end
  local slash = api_version and api_version:find "/"
  local group, version
  if slash then
    group = api_version:sub(1, slash - 1)
    version = api_version:sub(slash + 1)
  else
    version = api_version or "v1"
  end
  local group_part = group and group:match "^([%w]+)"
  if group_part then
    return ("%s-%s-%s.json"):format(kind:lower(), group_part:lower(), version:lower())
  end
  return ("%s-%s.json"):format(kind:lower(), version:lower())
end

local function k8s_schema_url()
  local kind, api_version = detect_kind_api()
  return modeline(k8s_schema_file(kind, api_version))
end

local function all_kinds()
  local seen, result = {}, {}
  for _, kinds in pairs(API_KINDS) do
    for _, kind in ipairs(kinds) do
      if not seen[kind] then
        seen[kind] = true
        table.insert(result, kind)
      end
    end
  end
  return result
end

local function kinds_for_api_version()
  local _, api_version = detect_kind_api()
  local kinds = api_version and API_KINDS[api_version] or all_kinds()
  local choices = {}
  for _, kind in ipairs(kinds) do
    table.insert(choices, t(kind))
  end
  return c(1, choices)
end

return {
  s("k8s-m", {
    f(k8s_schema_url, {}),
    i(0),
  }),

  s("k8s-av", {
    t("apiVersion: "),
    c(1, vim.tbl_map(t, API_VERSIONS)),
    i(0),
  }),

  s("k8s-kind", {
    t("kind: "),
    d(1, kinds_for_api_version, {}),
    i(0),
  }),

  s("k8s-deploy", {
    t { modeline "deployment-apps-v1.json", "", "apiVersion: apps/v1", "kind: Deployment", "metadata:", "  name: " },
    i(1, "app"),
    t { "", "  labels:", "    app: " },
    i(2, "app"),
    t { "", "spec:", "  replicas: " },
    i(3, "1"),
    t { "", "  selector:", "    matchLabels:", "      app: " },
    i(4, "app"),
    t { "", "  template:", "    metadata:", "      labels:", "        app: " },
    i(5, "app"),
    t { "", "    spec:", "      containers:", "        - name: " },
    i(6, "app"),
    t { "", "          image: " },
    i(7, "nginx:alpine"),
    t { "", "          ports:", "            - containerPort: " },
    i(8, "80"),
  }),

  s("k8s-svc", {
    t { modeline "service-v1.json", "", "apiVersion: v1", "kind: Service", "metadata:", "  name: " },
    i(1, "app"),
    t { "", "spec:", "  selector:", "    app: " },
    i(2, "app"),
    t { "", "  ports:", "    - port: " },
    i(3, "80"),
    t { "", "      targetPort: " },
    i(4, "80"),
    t { "", "  type: " },
    i(5, "ClusterIP"),
  }),

  s("k8s-cm", {
    t { modeline "configmap-v1.json", "", "apiVersion: v1", "kind: ConfigMap", "metadata:", "  name: " },
    i(1, "app"),
    t { "", "data:", "  " },
    i(2, "key"),
    t { ": " },
    i(3, "value"),
  }),

  s("k8s-secret", {
    t { modeline "secret-v1.json", "", "apiVersion: v1", "kind: Secret", "metadata:", "  name: " },
    i(1, "app"),
    t { "", "type: " },
    i(2, "Opaque"),
    t { "", "data:", "  " },
    i(3, "key"),
    t { ": " },
    i(4, "dmFsdWU="),
  }),

  s("k8s-ing", {
    t { modeline "ingress-networking-v1.json", "", "apiVersion: networking.k8s.io/v1", "kind: Ingress", "metadata:", "  name: " },
    i(1, "app"),
    t { "", "spec:", "  rules:", "    - host: " },
    i(2, "example.com"),
    t { "", "      http:", "        paths:", "          - path: /", "            pathType: Prefix", "            backend:", "              service:", "                name: " },
    i(3, "app"),
    t { "", "                port:", "                  number: " },
    i(4, "80"),
  }),

  s("k8s-ns", {
    t { modeline "namespace-v1.json", "", "apiVersion: v1", "kind: Namespace", "metadata:", "  name: " },
    i(1, "app"),
  }),

  s("k8s-pod", {
    t { modeline "pod-v1.json", "", "apiVersion: v1", "kind: Pod", "metadata:", "  name: " },
    i(1, "app"),
    t { "", "spec:", "  containers:", "    - name: " },
    i(2, "app"),
    t { "", "      image: " },
    i(3, "nginx:alpine"),
  }),

  s("k8s-job", {
    t { modeline "job-batch-v1.json", "", "apiVersion: batch/v1", "kind: Job", "metadata:", "  name: " },
    i(1, "job"),
    t { "", "spec:", "  template:", "    spec:", "      restartPolicy: OnFailure", "      containers:", "        - name: " },
    i(2, "job"),
    t { "", "          image: " },
    i(3, "busybox"),
  }),

  s("k8s-cronjob", {
    t { modeline "cronjob-batch-v1.json", "", "apiVersion: batch/v1", "kind: CronJob", "metadata:", "  name: " },
    i(1, "cron"),
    t { "", "spec:", "  schedule: " },
    i(2, '"*/5 * * * *"'),
    t { "", "  jobTemplate:", "    spec:", "      template:", "        spec:", "          restartPolicy: OnFailure", "          containers:", "            - name: " },
    i(3, "cron"),
    t { "", "              image: " },
    i(4, "busybox"),
  }),

  s("k8s-sts", {
    t { modeline "statefulset-apps-v1.json", "", "apiVersion: apps/v1", "kind: StatefulSet", "metadata:", "  name: " },
    i(1, "app"),
    t { "", "spec:", "  serviceName: " },
    i(2, "app"),
    t { "", "  replicas: " },
    i(3, "1"),
    t { "", "  selector:", "    matchLabels:", "      app: " },
    i(4, "app"),
    t { "", "  template:", "    metadata:", "      labels:", "        app: " },
    i(5, "app"),
    t { "", "    spec:", "      containers:", "        - name: " },
    i(6, "app"),
    t { "", "          image: " },
    i(7, "postgres:16"),
  }),
}
