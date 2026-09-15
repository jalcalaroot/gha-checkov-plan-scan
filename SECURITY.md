# Security Policy

This is a personal composite GitHub Action, not intended for production use beyond this account's own repositories. There are no supported version branches — only `main` is maintained.

## Reporting a Vulnerability

If you find a security issue — an exposed secret, a leaked credential in git history, or a misconfigured workflow — please report it privately using [GitHub's private vulnerability reporting](../../security/advisories/new) instead of opening a public issue.

## Scope

- This repository's `action.yml` and `.github/workflows/`
- The test fixture in `test/`

Out of scope: vulnerabilities in [Checkov](https://github.com/bridgecrewio/checkov) itself or Terraform — please report those to their respective maintainers.
