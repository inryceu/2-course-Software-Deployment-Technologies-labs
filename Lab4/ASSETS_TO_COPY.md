# Assets to Copy from Lab1 to Lab4

## Overview
Lab4 builds on Lab1's NestJS application. This document lists exactly which files/folders need to be copied from Lab1 to Lab4.

## Directory Structure Reference

```
Lab1/                           Lab4/
├── mywebapp/        ────────►  ├── app/  (or keep as mywebapp/)
├── nginx/           ────────►  ├── nginx/  (templates reference)
├── systemd/         ────────►  ├── systemd/  (templates reference)
├── docker/          ────────►  ├── docker/  (reference for Dockerfile)
├── docker-compose.yml
├── .env
└── README.md
```

## Files to Copy

### 1. NestJS Application (Core)
**Source**: `Lab1/mywebapp/`
**Destination**: `Lab4/app/` (or `Lab4/mywebapp/`)

Copy the entire directory structure:
```
mywebapp/
├── src/                    # Source code
├── test/                   # Test files
├── dist/                   # Build output (optional - will be built on VMs)
├── prisma/                 # Database schema
│   └── schema.prisma       # Database schema
├── package.json            # Dependencies
├── pnpm-lock.yaml         # Lock file
├── tsconfig.json          # TypeScript config
├── nest-cli.json          # NestJS CLI config
├── .prettierrc             # Code formatting
├── .gitignore             # Git ignore rules
└── eslint.config.mjs      # Linting rules
```

**Why**: The application code is needed on the worker VM.

### 2. Nginx Configuration Reference
**Source**: `Lab1/nginx/mywebapp.conf`
**Destination**: `Lab4/ansible/roles/worker/templates/mywebapp.conf` (as Jinja2 template)

**Content to extract**:
- Server block configuration
- Proxy pass directives
- Location blocks with health endpoint restrictions
- Header forwarding rules

**Modifications for template**:
- Change hardcoded IPs to Jinja2 variables where needed
- Ensure reverse proxy points to `127.0.0.1:5200` (app on same VM)

### 3. Systemd Configuration Reference
**Source**: `Lab1/systemd/mywebapp.service` and `Lab1/systemd/mywebapp.socket`
**Destination**: `Lab4/ansible/roles/worker/templates/`

**Files**:
- `Lab1/systemd/mywebapp.service` → `Lab4/ansible/roles/worker/templates/mywebapp.service`
- `Lab1/systemd/mywebapp.socket` → `Lab4/ansible/roles/worker/templates/mywebapp.socket`

**Why**: Systemd unit files define how the application runs as a service.

**Key values to preserve**:
- `User=app`
- `WorkingDirectory=/opt/mywebapp`
- `ExecStart=/usr/bin/node dist/src/main.js`
- `EnvironmentFile=/opt/mywebapp/.env`

### 4. Docker Configuration Reference
**Source**: `Lab1/docker/` (for reference only)
**Destination**: Reference only - not copied to Lab4

**Why**: Docker files not needed for VM deployment, but useful for understanding:
- Dockerfile for build process
- Entry points and runtime setup
- Environment configuration

### 5. Environment Configuration Reference
**Source**: `Lab1/.env`
**Destination**: Template reference for `Lab4/ansible/roles/worker/templates/mywebapp.env`

**Content to extract**:
```
DATABASE_URL=mysql://app:app_secure_pass@127.0.0.1:3306/notes_db
```

**Template version**:
```
DATABASE_URL=mysql://app:app_secure_pass@{{ db_ip }}:3306/notes_db
```

**Key changes for template**:
- `127.0.0.1` → `{{ db_ip }}` (IP of database VM)
- `app_secure_pass` → Keep as is (hardcoded credential)
- `notes_db` → Keep as is

### 6. .env.example
**Source**: `Lab1/mywebapp/.env.example` (if exists)
**Destination**: Reference for creating `.env` template

## Copying Instructions

### Using PowerShell
```powershell
# Copy the entire mywebapp directory
Copy-Item -Path "H:\PROJECTS\UNI\4 семестр\ТРПЗ\Lab1\mywebapp" `
          -Destination "H:\PROJECTS\UNI\4 семестр\ТРПЗ\Lab4\app" -Recurse

# Copy nginx config
Copy-Item -Path "H:\PROJECTS\UNI\4 семестр\ТРПЗ\Lab1\nginx\mywebapp.conf" `
          -Destination "H:\PROJECTS\UNI\4 семестр\ТРПЗ\Lab4\nginx_reference.conf"

# Copy systemd files
Copy-Item -Path "H:\PROJECTS\UNI\4 семестр\ТРПЗ\Lab1\systemd\*" `
          -Destination "H:\PROJECTS\UNI\4 семестр\ТРПЗ\Lab4\systemd_reference" -Recurse
```

### Using Git (if in repository)
```bash
cd Lab4
git checkout Lab1/mywebapp -- app/
git checkout Lab1/nginx -- nginx_reference/
git checkout Lab1/systemd -- systemd_reference/
git checkout Lab1/.env -- .env.reference
```

## Assets NOT to Copy

- **node_modules/**: Will be rebuilt on worker VM with `pnpm install`
- **dist/**: Will be rebuilt on worker VM with `npm run build`
- **coverage/**: Test coverage reports (not needed in production)
- **docker-compose.yml**: Docker-specific, not needed for VMs
- **docker/**: Docker files (reference only for Dockerfile understanding)
- **.github/workflows/**: CI/CD workflows (not applicable to VM deployment)

## Reference Information

### Package.json Key Scripts
The `package.json` defines these scripts used during Ansible deployment:
```json
{
  "scripts": {
    "build": "nest build",              // Compile app
    "start:prod": "node dist/src/main.js", // Start app
    "test": "jest",                     // Run tests
    "lint": "eslint ...",               // Code linting
  }
}
```

Ansible will:
1. Install dependencies: `pnpm install`
2. Generate Prisma client: `prisma generate`
3. Build application: `npm run build` (or included in systemd)
4. Start service via systemd

### Database Schema (Prisma)
Located in `Lab1/mywebapp/prisma/schema.prisma`

This defines:
- Database connection string (will be injected via `.env`)
- Data models (Note, etc.)
- Migrations

Ansible will generate the Prisma client but not run migrations directly.

## Validation Checklist

After copying, verify:
- [ ] `Lab4/app/` contains all NestJS source files
- [ ] `Lab4/app/prisma/schema.prisma` exists
- [ ] `Lab4/app/package.json` readable and has correct scripts
- [ ] `Lab4/app/src/main.ts` defines port from environment
- [ ] Application can be built: `cd Lab4/app && npm run build`
- [ ] Reference configs available for template creation

## Notes

- **Symlinks**: If any files are symlinks in Lab1, copy actual files to Lab4 (don't preserve symlinks)
- **Git submodules**: Check if any dependencies are git submodules; clone them if needed
- **Binary files**: Some dependencies might have platform-specific binaries; these will be rebuilt on target Ubuntu VMs
- **Lock files**: Keep `pnpm-lock.yaml` to ensure consistent dependency versions

## Timeline

This asset copying is part of **phase1-copy** task in the implementation plan.
