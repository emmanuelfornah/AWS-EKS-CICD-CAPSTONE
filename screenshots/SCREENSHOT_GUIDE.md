# Screenshot Capture Guide

## Existing Screenshots (Phases 1–4)

| # | Filename | What It Shows |
|---|----------|---------------|
| 01 | `01_ide_workspace_setup.png` | IDE workspace with cloned repository |
| 02 | `02_codecommit_repository.png` | CodeCommit repository in AWS Console |
| 03 | `03_application_initial_launch.png` | Application running — clean homepage |
| 04 | `04_appointment_timeslot_selection.png` | Appointment booking with timeslots visible |
| 05 | `05_unit_test_coverage_100.png` | Test coverage at 100% |
| 06 | `06_coverage_views_module.png` | Coverage report — views module detail |
| 07 | `07_coverage_full_report.png` | Full coverage report |
| 08 | `08_template_update_push.png` | Git push of template changes |
| 09 | `09_codebuild_succeeded.png` | CodeBuild project — build succeeded |
| 10 | `10_pipeline_all_stages_green.png` | CodePipeline — all stages green |

## Screenshots to Capture — Troubleshooting & Rollbacks (Phase 5)

| # | Filename | What to Capture |
|---|----------|-----------------|
| 11 | `11_kubectl_pod_error_logs.png` | Terminal: `kubectl logs` showing the `wrongregion` endpoint error |
| 12 | `12_region_fix_deployed.png` | Terminal: `kubectl apply` output + `curl` returning HTML after region fix |
| 13 | `13_app_orange_background.png` | Browser: application with orange background color |
| 14 | `14_pipeline_orange_build_succeeded.png` | CodePipeline: all stages green after orange background push |
| 15 | `15_app_cadetblue_background.png` | Browser: application with cadetblue background color |
| 16 | `16_rollback_to_orange.png` | Terminal: `kubectl rollout undo` + browser showing orange restored |

## Screenshots — EKS Deploy Pipeline & Rollback (Phase 6)

Located in `screenshots/deploy-pipeline/`:

| # | Filename | What It Shows |
|---|----------|---------------|
| 01 | `01-deploy-buildspec-configuration.png` | CodeBuild DeployPods project buildspec configuration |
| 02 | `02-application-running-verification.png` | Application running via ALB after EKS deployment |
| 03 | `03-pipeline-all-stages-succeeded.png` | Full CI/CD pipeline — all 4 stages succeeded |
| 04 | `04-ui-theme-update-cadetblue.png` | UI theme update to cadetblue triggered via pipeline |
| 05 | `05-ui-cadetblue-deployed.png` | Application displaying cadetblue background |
| 06 | `06-git-revert-rollback-to-original.png` | Git revert rollback — original theme restored |

## Architecture Diagram

Located in `screenshots/architecture/`:

| Filename | What It Shows |
|----------|---------------|
| `cicd-pipeline-eks-architecture.png` | End-to-end CI/CD pipeline and EKS infrastructure architecture |
