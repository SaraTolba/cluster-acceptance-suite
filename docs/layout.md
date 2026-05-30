# Layout explanation

This suite uses one repo for both clusters.

- `config/clusters/` contains one `.env` file per cluster.
- `config/required_modules/` contains modules that should exist and load on each cluster.
- `config/expected_limits/` contains expected shell limits and required filesystem paths.
- `config/known_issues/` contains patterns that should be checked explicitly.
- `config/example_sets/` contains user example directories to discover or submit.
- `lib/` contains reusable functions shared by all scripts.
- `templates/` contains scheduler-specific job headers.
- `sanity/` contains fast checks.
- `workloads/` contains user-style jobs.
- `runners/` contains orchestration scripts.
- `reports/` contains generated outputs.
- `prototypes/` preserves older scripts for reference only.
