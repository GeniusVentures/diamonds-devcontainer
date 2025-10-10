# DevContainer Architecture: Build-Time vs Runtime

## The Fundamental Constraint

**The .env file CANNOT be used for Docker build arguments.**

This is not a limitation of our setup - it's a fundamental architectural constraint of how Docker and DevContainers work.

## Why This Happens

```
┌─────────────────────────────────────────────────────────────────┐
│                    DOCKER BUILD TIMELINE                         │
└─────────────────────────────────────────────────────────────────┘

Step 1: Parse devcontainer.json
  ├─ Read build args from HOST environment
  ├─ Apply defaults for missing values
  └─ .env file does NOT exist yet (it's in the workspace)

Step 2: Run Dockerfile instructions
  ├─ Create directories using WORKSPACE_NAME
  ├─ Install packages
  └─ .env file STILL doesn't exist

Step 3: Container image is created
  └─ Image is now built, frozen

Step 4: Start container from image
  └─ NOW the workspace is mounted (including .env file)

Step 5: Post-create scripts run
  └─ NOW .env file is available and can be read
```

**Result**: Variables needed during build (Steps 1-3) CANNOT come from .env (available in Step 4+).

## Variable Classification

### Build-Time Variables (Cannot Use .env)

**WORKSPACE_NAME** - Creates directory structure during build

**Why it's build-time:**
```dockerfile
# In Dockerfile (runs during build, before .env exists)
RUN mkdir -p /workspaces/${WORKSPACE_NAME}
```

**How to set it:**
1. Export on HOST: `export WORKSPACE_NAME=my_name`
2. Use helper script: `source .devcontainer/set-host-env.sh` (reads .env, exports to host)
3. Edit devcontainer.json default

**The helper script is the bridge** that makes .env values available to the build by exporting them to the host environment BEFORE the build starts.

### Runtime Variables (Can Use .env)

**DIAMOND_NAME** - Only used by scripts after container starts

**Why it's runtime-only:**
- Not used in Dockerfile at all
- Only used by post-create.sh and application code
- Available when needed (after .env is mounted)

**How to set it:**
1. Edit .env file (preferred, no rebuild needed)
2. Set in containerEnv in devcontainer.json
3. Export in terminal after container starts

## The Correct Workflow

### For WORKSPACE_NAME (Build-Time)

```bash
# On HOST machine (OUTSIDE the container)
cd /path/to/your/project

# Option A: Use helper script (reads .env, exports to host)
source .devcontainer/set-host-env.sh

# Option B: Manual export
export WORKSPACE_NAME=diamonds_dev_env

# Then build/rebuild container in VS Code
# Command Palette → "Dev Containers: Rebuild Container"
```

### For DIAMOND_NAME (Runtime)

```bash
# Just edit .env file
# No export needed, no rebuild needed!

# In .env:
DIAMOND_NAME=MyCustomDiamond

# Restart terminal or re-run script to pick up changes
```

## Why We Can't "Fix" This

This is not a bug or limitation we can work around. It's how Docker fundamentally works:

1. **Docker build is isolated** - It only has access to:
   - Build context (files explicitly copied)
   - Build args (passed from outside)
   - Base image

2. **Workspace mounts happen after build** - Your workspace (including .env) is mounted to the running container, not during build

3. **No circular dependency allowed** - Can't mount workspace to read .env to determine how to build the container that will mount the workspace

## The Helper Script Solution

The `set-host-env.sh` script is the proper solution:

```bash
#!/bin/bash
# Reads .env from workspace
# Exports values to HOST environment
# Then you rebuild container
# Container build uses HOST environment values
```

This is the **standard pattern** for making .env values available to Docker builds:
1. Source .env to export to host
2. Docker build reads from host environment
3. Success!

## Comparison with Other Tools

### Docker Compose
Docker Compose has the same limitation:
```yaml
# docker-compose.yml
services:
  app:
    build:
      args:
        - WORKSPACE_NAME=${WORKSPACE_NAME}  # Reads from HOST env
```
You still need to export to host environment first.

### Kubernetes
ConfigMaps and Secrets are also runtime-only, not available during image build.

### CI/CD Systems
GitHub Actions, GitLab CI, etc. all require build args to be set in pipeline environment, not in workspace files.

## Best Practices

### DO ✅
- Use helper script to export .env values to host before rebuild
- Understand which variables are build-time vs runtime
- Use .env for runtime variables (DIAMOND_NAME, API keys, etc.)
- Document which variables require rebuild

### DON'T ❌
- Expect .env to be available during Docker build
- Put secrets in devcontainer.json (it might be committed)
- Hardcode values in Dockerfile (use args/env vars)
- Confuse build-time and runtime variables

## Summary Table

| Variable | Type | Source | Rebuild? | How to Set |
|----------|------|--------|----------|------------|
| WORKSPACE_NAME | Build-time | Host env → ARG | Yes | Helper script or export on host |
| DIAMOND_NAME | Runtime | .env or containerEnv | No | Edit .env file |
| NODE_VERSION | Build-time | devcontainer.json | Yes | Edit devcontainer.json |
| HARDHAT_NETWORK | Runtime | containerEnv or .env | No | Edit .env or containerEnv |

## The Bottom Line

**For portability using .env:**

1. **Build-time variables**: Use helper script to bridge .env → host env → build args
2. **Runtime variables**: Just use .env directly (it works perfectly)

This is the **correct architecture** and follows Docker/DevContainer best practices.
