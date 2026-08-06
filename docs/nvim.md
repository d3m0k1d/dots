# Neovim Snippets

---

## 📁 ansible.lua

### `ans-play`

```yaml
---
- name: Deploy app
  hosts: all
  become: 
  tasks:
    - name: Install package
      apt:
        name: nginx
        state: present
```

---

### `ans-task`
```yaml
- name: Do something
  ansible.builtin.debug:
    msg: Hello World
```

---

### `ans-inventory`
```yaml
---
all:
  children:
    web:
      hosts:
        server-01:
          ansible_host: 192.168.1.10
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

---

### `ans-template`
```yaml
- name: Render template
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/app/app.conf
    owner: root
    group: root
    mode: '0644'
```

---

## 📁 compose.lua

### `cmp-start-build`
```yaml
services:
  app:
    build: .
    ports:
      - 8080:8080
    depends_on:
      - db
    env_file:
      - .env
    environment:
      - ENV=dev
    restart: unless-stopped
    networks:
      - app-net

networks:
  app-net:
    driver: bridge

volumes:
  app-data:
```

---

### `cmp-start-image`

```yaml
services:
  app:
    image: nginx:alpine
    ports:
      - 8080:80
    depends_on:
      - db
    env_file:
      - .env
    environment:
      - ENV=dev
    restart: unless-stopped
    networks:
      - app-net

networks:
  app-net:
    driver: bridge

volumes:
  app-data:
```

---

### `cmp-start`
```yaml
services:




networks:
  app-net:
    driver: bridge

volumes:
  app-data:
```

---

### `cmp-serv-image`
```yaml
  app:
    image: nginx:alpine
    container_name: my-container
    ports:
      - 80:80
    environment:
      - KEY=value
    env_file:
      - .env
    volumes:
      - ./data:/data
      - app-data:/var/lib/data
    networks:
      - app-net
    depends_on:
      - db
    restart: unless-stopped
```

---

### `cmp-serv-build`
```yaml
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: my-container
    ports:
      - 8080:8080
    environment:
      - KEY=value
    env_file:
      - .env
    volumes:
      - ./data:/data
      - app-data:/var/lib/data
    networks:
      - app-net
    depends_on:
      - db
    restart: unless-stopped
```

---

### `cmp-health`
```yaml
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

---

### `cmp-deploy`
```yaml
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
```

---

### `cmp-vol`
```yaml
  app-data:
    driver: local
```

---

### `cmp-net`
```yaml
  app-net:
    driver: bridge
```

---

## 📁 dockerfile.lua

### `d-multi`
```dockerfile
FROM golang as builder

FROM alpine:3.23.0

COPY --from=builder /app /app
```

---

### `go-cache`
```dockerfile
FROM golang:1.23-alpine as builder

WORKDIR /app

COPY go.mod go.sum .
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY .
ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -ldflags='-s -w' -o /app

FROM alpine:3.23.0

COPY --from=builder /app /app

ENTRYPOINT ["/app"]
```

---

### `d-node`
```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json .
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=0 /app/dist /usr/share/nginx/html
```

---

### `d-python`
```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
CMD ["python", "main.py"]
```

---

## 📁 github-actions.lua

### `gha-start`
```yaml
name: ci
on:
  push:
  pull_request:
    branches: master

jobs:
  build
      runs-on: ubuntu-latest
```

---

## 📁 k8s.lua

Kubernetes snippets. Manifest snippets insert the `# yaml-language-server: $schema=...` modeline pointing at a per-resource yannh schema (v1.36.0), so yamlls provides both validation and `apiVersion`/`kind` suggestions.

### `k8s-m` — schema modeline

```yaml
# yaml-language-server: $schema=.../<resource>.json
```

Scans the first 40 buffer lines for `apiVersion`/`kind` and inserts the modeline for the matching schema (`deployment-apps-v1.json`, `service-v1.json`, …). Empty file or no `kind` → `all.json`. Insert at the top of the file (or re-insert after adding a kind).

### `k8s-av` — apiVersion picker

```yaml
apiVersion: v1
```

Choice node, cycles with Tab. Available: `v1`, `apps/v1`, `batch/v1`, `networking.k8s.io/v1`, `rbac.authorization.k8s.io/v1`, `autoscaling/v2`, `policy/v1`, `storage.k8s.io/v1`, `apiextensions.k8s.io/v1`.

### `k8s-kind` — kind matching the current apiVersion

```yaml
kind: Deployment
```

Reads `apiVersion` from the buffer and offers only compatible kinds:

| apiVersion | kinds |
|---|---|
| `v1` | `Pod`, `Service`, `ConfigMap`, `Secret`, `Namespace`, `ServiceAccount`, `PersistentVolumeClaim`, `PersistentVolume`, `Endpoints`, `LimitRange`, `ResourceQuota`, `ReplicationController`, `Node` |
| `apps/v1` | `Deployment`, `StatefulSet`, `DaemonSet`, `ReplicaSet` |
| `batch/v1` | `Job`, `CronJob` |
| `networking.k8s.io/v1` | `Ingress`, `IngressClass`, `NetworkPolicy` |
| `rbac.authorization.k8s.io/v1` | `Role`, `ClusterRole`, `RoleBinding`, `ClusterRoleBinding` |
| `autoscaling/v2` | `HorizontalPodAutoscaler` |
| `policy/v1` | `PodDisruptionBudget` |
| `storage.k8s.io/v1` | `StorageClass`, `VolumeAttachment`, `CSIDriver` |
| `apiextensions.k8s.io/v1` | `CustomResourceDefinition` |

Missing or unknown `apiVersion` → all kinds are offered.

### How to use

1. In an empty file: `k8s-av` → pick the version (`apps/v1`), Enter.
2. On the next line `k8s-kind` → pick the kind (`Deployment`), Enter.
3. `k8s-m` → insert the schema modeline — yamlls then validates and suggests fields (`replicas`, `containers`, …).
   Or jump straight to one of the manifest snippets below (modeline already included).

### Manifest snippets (modeline already included)

#### `k8s-deploy`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  labels:
    app: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: app
          image: nginx:alpine
          ports:
            - containerPort: 80
```

---

#### `k8s-svc`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: app
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

---

#### `k8s-cm`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app
data:
  key: value
```

---

#### `k8s-secret`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app
type: Opaque
data:
  key: dmFsdWU=
```

---

#### `k8s-ing`
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app
                port:
                  number: 80
```

---

#### `k8s-ns`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app
```

---

#### `k8s-pod`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
    - name: app
      image: nginx:alpine
```

---

#### `k8s-job`
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: job
          image: busybox
```

---

#### `k8s-cronjob`
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cron
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: cron
              image: busybox
```

---

#### `k8s-sts`
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: app
spec:
  serviceName: app
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: app
          image: postgres:16
```

---

## 📁 nginx.lua

### `nginx-start`
```nginx
server {
    listen 80;
    server_name localhost.local;
    root /var/www/html;
    location / {
        try_files $uri $uri/index.html;
    }
    server_tokens off;
}
```

---

### `nginx-tls`
```nginx
listen 443 ssl;
ssl_certificate /etc/ssl/cert.pem;
ssl_certificate_key /etc/ssl/key.pem;
ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5:!3DES;
```

---

### `nginx-cache`
```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
    expires 30d;
    add_header Cache-Control public, immutable;
    access_log off;
}
```

---

## 📁 go.lua

### `fn`
```go
func name() 
{
	
}
```

---

### `main`
```go
func main() {
	
}
```

---

### `iferr`

```go
if err != nil {
	return err
}
```

---

### `for`
```go
for i := 0; i < 10; i++ 
{
	
}
```

---

### `struct`
```go
type Name struct {
	
}
```

---

