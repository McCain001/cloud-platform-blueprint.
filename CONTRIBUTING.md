# Contributing

## Workflow

1. Branch from `main`: `feat/<topic>`, `fix/<topic>`, `infra/<topic>`.
2. Install hooks once: `pip install pre-commit && pre-commit install`.
3. Make changes; run `make app-test`, `make tf-fmt`, `make helm-lint`, `make policy-test` as relevant.
4. Open a PR. CI posts a Terraform plan for infra changes — review it for unexpected `destroy`s.
5. Squash-merge once checks pass and a CODEOWNER approves.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `ci:`, `infra:`.

## Terraform conventions

- Modules are environment-agnostic; environments only compose modules and set variables.
- Every variable has a `type` and `description`; validate inputs where mistakes are costly.
- No hard-coded account IDs or regions in modules.
- Run `terraform fmt -recursive` before committing.

## Kubernetes conventions

- All workload changes go through the Helm chart and Git — no `kubectl apply` of app manifests.
- New containers must pass `policies/conftest` (non-root, read-only FS, limits, probes, pinned tags).
