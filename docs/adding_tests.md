# Adding a new test

1. Put fast environment checks under `sanity/`.
2. Put user-style jobs under `workloads/<test_name>/`.
3. Use `lib/reporting.sh` to write result rows.
4. Use the cluster config instead of hardcoding account, queue, partition, or module names.
5. Add the test to `runners/run_sanity.sh` or `runners/run_workloads.sh`.

Every test should produce a row in:

```text
reports/<cluster>/<run_id>/acceptance_results.csv
```
