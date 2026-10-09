# Deployment Pipeline Analysis

## Broken pipeline findings

The original `.github/workflows/deployment.yml` has these gaps:

- **Missing validation stages:** There is no source/ref validation, build artifact boundary, integration-test stage, coverage threshold, dependency audit, secret scan, SAST, staging deployment, staging verification, or rollback stage.
- **Incorrect execution order:** The `deploy` job runs first. Lint and tests depend on it (`lint -> test`), so production can be changed before either validation job has passed.
- **Missing safety gates:** Production is the only environment and is not preceded by staging. There is no manual approval boundary, no required success condition between stages, and no minimum coverage or security threshold.
- **Poor failure isolation:** Build, dependency installation, production deployment, and smoke testing are mixed in one job. The later lint/test jobs repeat setup and do not protect the deployment. A failed smoke test is hidden by `|| echo`, so the job remains green.
- **Rollback gaps:** No previous release is captured, no rollback is triggered by verification failure, and the existing rollback script is only a manually documented command. There is also no post-rollback health check.
- **Operational gaps:** The workflow deploys every branch, uses mutable `npm install`, uses old action versions, and does not consistently expose the commit SHA, release tag, timestamps, or final status.

## Repaired design

`.github/workflows/deployment-pipeline.yml` implements the following ordered gates:

1. `Source` checks out the exact ref and records the commit SHA and timestamp.
2. `Build` runs `npm ci`, lint, build, and uploads a release artifact.
3. `Test` downloads that artifact and requires tests and at least 80% global coverage.
4. `Security` runs dependency audit, secret scanning, and SAST.
5. `Deploy-Staging` runs only after all validation jobs pass.
6. `Deploy-Production` runs only from `main`, uses the protected `production` environment, and therefore requires its configured reviewers.
7. `Verify` runs smoke and health checks. A failed verification blocks completion and enables the rollback job.
8. `Rollback` runs on verification failure when `PREVIOUS_IMAGE_TAG` is configured, then checks service health.
9. `Notify` always records the final status, SHA, and timestamp and reports failures.

The workflow uses immutable `IMAGE_TAG=${GITHUB_SHA}` and passes the build artifact between jobs. Configure the `production` environment in repository settings with required reviewers, and provide `REGISTRY`, `DEPLOY_TOKEN`, `DB_PASS`, `JWT_SECRET`, `STAGING_URL`, `PRODUCTION_URL`, and `PREVIOUS_IMAGE_TAG` as appropriate repository/environment secrets.

## Validation evidence

- Job `needs` forms a single gate chain: source -> build -> test/security -> staging -> production -> verify -> rollback/notify.
- Normal job failure stops all dependent jobs because dependent jobs have no `always()` override.
- The smoke test uses `curl --fail`, so an unhealthy endpoint fails verification instead of being logged and ignored.
- Rollback is conditional on `needs.verify.result == 'failure'` and is followed by a health check.
- `Notify` uses `always()` and includes `github.sha`, `github.run_started_at`, and job results for traceability.
