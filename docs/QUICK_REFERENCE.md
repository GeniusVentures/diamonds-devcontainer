# Quick Reference: DevContainer Environment Variables

## TL;DR

```bash
# On your HOST machine (before opening DevContainer):
source .devcontainer/set-host-env.sh

# Then in VS Code:
# Command Palette → "Dev Containers: Rebuild Container"
```

## Environment Variables

| Variable | Default | Purpose | When Set | Needs Rebuild? |
|----------|---------|---------|----------|----------------|
| `WORKSPACE_NAME` | `diamonds_project` | Workspace directory name | Build-time (host env) | Yes |
| `DIAMOND_NAME` | `ExampleDiamond` | Diamond contract name | Runtime (.env or containerEnv) | No |

## Critical: Build-Time vs Runtime Variables

### Build-Time (WORKSPACE_NAME)
- **Must** be set on HOST before building container
- Creates directory structure during Docker build
- **Cannot** read from .env during build (architectural limitation)
- Use helper script to export from .env to host

### Runtime (DIAMOND_NAME)
- **Can** read from .env file (no rebuild needed)
- Used by scripts after container is running
- Fallback chain: containerEnv → .env → graceful skip

## Three Ways to Set Variables

### 1. Helper Script (Easiest for WORKSPACE_NAME)
```bash
# On HOST, reads WORKSPACE_NAME from .env and exports to host
source .devcontainer/set-host-env.sh
# Then rebuild container in VS Code
```

### 2. Manual Export (For WORKSPACE_NAME)
```bash
# On HOST
export WORKSPACE_NAME=my_workspace
# Then rebuild container
```

### 3. Edit .env (For DIAMOND_NAME - No Rebuild!)
```bash
# Just edit .env file
DIAMOND_NAME=MyDiamond
# Restart terminal or re-run script - no rebuild needed!
```

## Common Issues

### ❌ "DIAMOND_NAME: unbound variable"
**Fixed!** Script now handles missing variables gracefully.

### ❌ Wrong workspace directory
**Solution**: Set `WORKSPACE_NAME` on HOST before rebuilding.
**Why**: Build-time variable, can't read from .env during Docker build.

### ❌ .env changes not reflected
**For WORKSPACE_NAME**: .env is for runtime, not build. Use helper script to export to host, then rebuild.
**For DIAMOND_NAME**: Just restart terminal - no rebuild needed!

## Files to Know

- **ENV_VARS.md** - Detailed documentation
- **set-host-env.sh** - Helper script to export .env to host
- **devcontainer.json** - Container configuration
- **.env** - Application configuration (Hardhat, scripts)

## When to Rebuild

**Rebuild Required:**
- Changing `WORKSPACE_NAME` (affects directory structure created during build)
- Modifying `devcontainer.json` settings
- Changing `Dockerfile`
- Adding VS Code extensions

**No Rebuild Needed:**
- Changing `DIAMOND_NAME` in `.env` (runtime variable)
- Editing source code files
- Running `yarn install` for new dependencies
- Modifying Hardhat configuration
