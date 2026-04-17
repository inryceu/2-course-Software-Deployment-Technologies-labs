#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
section() { echo -e "\n${BLUE}==== $1 ====${NC}"; }

PASS=0
FAIL=0

check_pass() {
  ((PASS++))
  log "$1"
}

check_fail() {
  ((FAIL++))
  error "$1"
}

section "Repository Structure"

if [ -d ".github/workflows" ]; then
  check_pass ".github/workflows exists at repo root"
else
  check_fail ".github/workflows missing (must be at repo root, not Lab1/)"
fi

if [ -f ".github/workflows/lint.yml" ]; then
  check_pass ".github/workflows/lint.yml exists"
else
  check_fail ".github/workflows/lint.yml missing"
fi

if [ -f ".github/workflows/tests.yml" ]; then
  check_pass ".github/workflows/tests.yml exists"
else
  check_fail ".github/workflows/tests.yml missing"
fi

if [ -f ".github/workflows/build-publish.yml" ]; then
  check_pass ".github/workflows/build-publish.yml exists"
else
  check_fail ".github/workflows/build-publish.yml missing"
fi

if [ -f ".github/workflows/deploy.yml" ]; then
  check_pass ".github/workflows/deploy.yml exists"
else
  check_fail ".github/workflows/deploy.yml missing"
fi

if [ -f "Lab1/automation/ci/setup_runner.sh" ]; then
  check_pass "Lab1/automation/ci/setup_runner.sh exists"
else
  check_fail "Lab1/automation/ci/setup_runner.sh missing"
fi

if [ -f "Lab1/automation/ci/setup_target_vm.sh" ]; then
  check_pass "Lab1/automation/ci/setup_target_vm.sh exists"
else
  check_fail "Lab1/automation/ci/setup_target_vm.sh missing"
fi

if [ -f "Lab1/automation/ci/deploy_via_ssh.sh" ]; then
  check_pass "Lab1/automation/ci/deploy_via_ssh.sh exists"
else
  check_fail "Lab1/automation/ci/deploy_via_ssh.sh missing"
fi

if [ -f "Lab1/automation/ci/verify_deployment.sh" ]; then
  check_pass "Lab1/automation/ci/verify_deployment.sh exists"
else
  check_fail "Lab1/automation/ci/verify_deployment.sh missing"
fi

section "NestJS Application (Lab1/mywebapp)"

if [ -f "Lab1/mywebapp/package.json" ]; then
  check_pass "Lab1/mywebapp/package.json exists"
  
  if grep -q '"lint:ci"' Lab1/mywebapp/package.json; then
    check_pass "  lint:ci script configured"
  else
    check_fail "  lint:ci script missing in package.json"
  fi
  
  if grep -q '"lint:shell"' Lab1/mywebapp/package.json; then
    check_pass "  lint:shell script configured"
  else
    check_fail "  lint:shell script missing in package.json"
  fi
  
  if grep -q '"lint:yaml"' Lab1/mywebapp/package.json; then
    check_pass "  lint:yaml script configured"
  else
    check_fail "  lint:yaml script missing in package.json"
  fi
  
  if grep -q '"coverageThreshold"' Lab1/mywebapp/package.json; then
    check_pass "  coverageThreshold configured"
  else
    check_fail "  coverageThreshold missing (must enforce 40% minimum)"
  fi
else
  check_fail "Lab1/mywebapp/package.json missing"
fi

if [ -f "Lab1/mywebapp/eslint.config.mjs" ]; then
  check_pass "Lab1/mywebapp/eslint.config.mjs exists"
else
  check_fail "Lab1/mywebapp/eslint.config.mjs missing"
fi

if [ -f "Lab1/.yamllint.yml" ]; then
  check_pass "Lab1/.yamllint.yml exists"
  if grep -q "type: unix" Lab1/.yamllint.yml; then
    check_pass "  Unix line endings enforced"
  else
    check_fail "  Unix line endings not configured"
  fi
else
  check_fail "Lab1/.yamllint.yml missing"
fi

section "Docker Configuration"

if [ -f "Lab1/docker/Dockerfile" ]; then
  check_pass "Lab1/docker/Dockerfile exists"
  if grep -q "FROM" Lab1/docker/Dockerfile; then
    check_pass "  Dockerfile has multi-stage FROM statements"
  fi
else
  check_fail "Lab1/docker/Dockerfile missing"
fi

if [ -f "Lab1/docker-compose.yml" ]; then
  check_pass "Lab1/docker-compose.yml exists"
else
  check_fail "Lab1/docker-compose.yml missing"
fi

section "Test Configuration"

if [ -f "Lab1/mywebapp/src/app.service.spec.ts" ]; then
  check_pass "App service tests exist"
else
  check_fail "App service tests missing"
fi

if [ -f "Lab1/mywebapp/test/app.e2e-spec.ts" ]; then
  check_pass "E2E tests exist"
else
  check_fail "E2E tests missing"
fi

section "Local Linting Verification"

if cd Lab1/mywebapp 2>/dev/null; then
  if pnpm run lint:ci > /dev/null 2>&1; then
    check_pass "ESLint passes locally"
  else
    check_fail "ESLint fails locally (run: cd Lab1/mywebapp && pnpm run lint:ci)"
  fi
  
  if npm run lint:shell > /dev/null 2>&1; then
    check_pass "Shellcheck passes locally"
  else
    check_fail "Shellcheck fails locally (run: npm run lint:shell)"
  fi
  
  if npm run lint:yaml > /dev/null 2>&1; then
    check_pass "Yamllint passes locally"
  else
    check_fail "Yamllint fails locally (run: npm run lint:yaml)"
  fi
else
  check_fail "Could not cd to Lab1/mywebapp"
fi

cd - > /dev/null 2>&1 || true

section "Documentation"

if [ -f "LAB3_SETUP.md" ]; then
  check_pass "LAB3_SETUP.md exists"
else
  check_fail "LAB3_SETUP.md missing"
fi

if [ -f "README.md" ]; then
  check_pass "README.md exists"
  if grep -q "Lab 3" README.md; then
    check_pass "  README mentions Lab3"
  else
    check_fail "  README should document Lab3 CI/CD"
  fi
else
  check_fail "README.md missing"
fi

section "Git Repository"

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  check_pass "Git repository initialized"
else
  check_fail "Not a git repository"
fi

section "Summary"

TOTAL=$((PASS + FAIL))
echo "Passed: ${GREEN}${PASS}${NC}/${TOTAL}"
echo "Failed: ${RED}${FAIL}${NC}/${TOTAL}"

if [ $FAIL -eq 0 ]; then
  echo -e "\n${GREEN}✓ All checks passed! Ready to push to GitHub.${NC}"
  exit 0
else
  echo -e "\n${RED}✗ Some checks failed. Fix the issues above before pushing.${NC}"
  exit 1
fi
