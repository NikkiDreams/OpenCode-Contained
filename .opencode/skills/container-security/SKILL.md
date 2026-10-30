---
name: container-security
description: "Secure Docker and Kubernetes deployments — image hardening, secret management, runtime policies, network policies, and vulnerability scanning in CI/CD."
license: MIT
---

Containers share the host kernel — a vulnerability in one container
can compromise the entire host. Security must be layered: secure the
image, secure the runtime, secure the orchestration.

## Hardened Dockerfile

```dockerfile
# Use distroless or minimal base images
FROM gcr.io/distroless/static-debian12:nonroot

# Don't run as root
USER nonroot:nonroot

# Set read-only filesystem
COPY --from=builder --chown=nonroot:nonroot /app/dist /app

# No shell, no package manager, no attack surface
ENTRYPOINT ["/app/server"]

# Security labels
LABEL org.opencontainers.image.source="https://github.com/your-org/your-app"
LABEL org.opencontainers.image.description="Your app"
```

## Multi-stage build with security scanning

```dockerfile
# Stage 1: Build with pinned versions
FROM node:22.12-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile --prod=false
COPY . .
RUN pnpm build && pnpm prune --prod

# Stage 2: Run with minimal dependencies
FROM gcr.io/distroless/nodejs22-debian12:nonroot
WORKDIR /app
COPY --from=builder --chown=nonroot:nonroot /app/dist ./dist
COPY --from=builder --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /app/package.json ./

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/dist/healthcheck.js"]

ENTRYPOINT ["node", "dist/server.js"]
```

## Image scanning in CI/CD

```yaml
# .github/workflows/security.yml
name: Container Security
on: [push, pull_request]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapp:${{ github.sha }}
          format: sarif
          output: trivy-results.sarif
          severity: CRITICAL,HIGH
          exit-code: 1  # Fail on critical/high vulnerabilities

      - name: Run Hadolint Dockerfile linter
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile
```

## Kubernetes security policies

```yaml
# Pod Security Standards (restricted)
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault

  containers:
    - name: app
      image: myapp:1.0.0@sha256:abc123...
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]

      resources:
        limits:
          cpu: "500m"
          memory: "256Mi"
        requests:
          cpu: "250m"
          memory: "128Mi"

      volumeMounts:
        - name: tmp
          mountPath: /tmp

  volumes:
    - name: tmp
      emptyDir: {}
```

## Network policies

```yaml
# Restrict pod-to-pod communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-network-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - port: 3000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - port: 5432
```

## Secret management

```yaml
# Never store secrets in environment variables or configmaps
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
stringData:
  database-url: "postgresql://user:pass@db:5432/app"
  api-key: "sk-..."

# Reference in pod spec
spec:
  containers:
    - name: app
      env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
```

## Container security checklist

```markdown
## Image
- [ ] Use distroless or minimal base images
- [ ] Pin all image versions with digests
- [ ] Run as non-root user
- [ ] Scan images in CI (Trivy, Snyk, Grype)
- [ ] Sign images with cosign/notation

## Runtime
- [ ] Read-only root filesystem
- [ ] No privilege escalation
- [ ] Drop all capabilities, add only needed ones
- [ ] Set resource limits (CPU, memory)
- [ ] Use seccomp and AppArmor profiles

## Network
- [ ] Default deny all ingress/egress
- [ ] Allow only necessary pod-to-pod communication
- [ ] Use network policies
- [ ] Encrypt service mesh traffic (mTLS)

## Secrets
- [ ] Use Kubernetes Secrets or external vault
- [ ] Never bake secrets into images
- [ ] Rotate secrets regularly
- [ ] Audit secret access
```

## Anti-patterns

- Don't use `latest` tag — pin versions with digests
- Don't run containers as root — always specify `USER`
- Don't store secrets in environment variables — use vaults
- Don't expose Docker socket — it's a container escape vector
- Don't skip image scanning — vulnerabilities accumulate fast
