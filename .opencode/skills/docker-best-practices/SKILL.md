---
name: docker-best-practices
description: Use when writing Dockerfiles, optimizing container images, or managing multi-stage builds for production.
---

# Docker Best Practices

## When to Use This Skill
- Writing a new Dockerfile for a service
- Optimizing image size and build speed
- Setting up multi-stage builds
- Managing container security and secrets

## Workflow
1. Start from a minimal base image: `alpine` or `slim` variants
2. Use multi-stage builds: build in one stage, copy artifacts to a clean runtime stage
3. Order instructions from least to most frequently changing (layer caching)
4. Combine RUN commands to reduce layers: `RUN apt-get update && apt-get install -y ...`
5. Use `.dockerignore` to exclude node_modules, .git, and build artifacts
6. Run as a non-root user: `USER appuser`
7. Set a health check: `HEALTHCHECK CMD curl -f http://localhost/`
8. Scan images with `trivy` or `docker scout` before deploying

## Rules
- Never run containers as root in production
- Don't store secrets in image layers — use runtime environment variables or secret managers
- Pin base image versions, not just `latest`
- Use multi-stage builds to keep final images small
- Clean up package manager caches in the same RUN layer
- Set resource limits: memory and CPU for every container
