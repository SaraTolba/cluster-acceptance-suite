# Cluster Acceptance Suite

A starter acceptance-test suite for validating PBS and SLURM clusters after maintenance.

This suite is designed around one shared codebase and separate cluster configuration files. The old one-off scripts in `prototypes/` are kept only as examples of prior test ideas. They are not treated as current acceptance results.

## Supported schedulers

- PBS / OpenPBS
- SLURM

## Test account

The generated job scripts use the shared test project/account values from the selected cluster config file.

The cluster key passed to `--cluster` must match a file in `config/clusters/`, for example `prime-pbs-cluster.env` or `thunder-slurm-cluster.env`.

```bash
#SBATCH --account=x-ccast-prj-
#PBS -W group_list=x-ccast-prj-
```

Edit the cluster config if the exact account/group string changes.

## Quick start

From the repository root on the target cluster:

```bash
chmod +x runners/*.sh sanity/*.sh workloads/*/*.sh

# PBS cluster sanity checks
./runners/run_all.sh --cluster prime-pbs-cluster --mode sanity

# SLURM cluster sanity checks
./runners/run_all.sh --cluster thunder-slurm-cluster --mode sanity
```

For a dry run that creates job files but does not submit them:

```bash
./runners/run_all.sh --cluster prime-pbs-cluster --mode all --dry-run
./runners/run_all.sh --cluster thunder-slurm-cluster --mode all --dry-run
```

Run a specific workload case:

```bash
./runners/run_all.sh --cluster prime-pbs-cluster --mode examples --dry-run
./runners/run_all.sh --cluster prime-pbs-cluster --mode mpi-hello
./runners/run_all.sh --cluster prime-pbs-cluster --mode module-heavy
```

### PBS GPU template

A GPU-specific PBS job template is now available at `templates/pbs/gpu_job.pbs.template`. It uses the `PBS_SELECT_GPU` setting from the cluster config to request `ngpus=1` and the correct GPU node resources.

## Main folders

- `config/` - per-cluster settings, expected limits, required modules, known issue rules, and example-folder lists.
- `lib/` - shared shell helpers for reporting, modules, and scheduler actions.
- `templates/` - PBS and SLURM job templates.
- `sanity/` - quick health checks such as scheduler submit, modules, limits, env vars, and filesystems.
- `workloads/` - representative user-style jobs such as MPI, OpenMP, hybrid MPI/OpenMP, module-stack tests, and example-folder smoke tests.
- `runners/` - orchestration scripts for running the suite.
- `reports/` - generated run outputs. These are ignored by Git except for `.gitkeep`.
- `prototypes/` - historical scripts copied from earlier tests for reference only.

## Result statuses

- `PASS` - completed and matched the expected result.
- `FAIL` - acceptance-blocking failure.
- `WARN` - suspicious or known issue that should be reviewed.
- `SKIP` - intentionally not run.
- `UNKNOWN` - not enough data to classify.
- `KNOWN_FAIL` - known issue still present and explicitly tracked.

## Recommended first use

1. Run sanity mode with `--dry-run`.
2. Review generated jobs in `reports/<cluster>/<run_id>/jobs/`.
3. Run sanity mode without `--dry-run`.
4. Run workloads mode.
5. Enable example submission only after reviewing the example configs.

The example-folder workload is conservative by default: it discovers example folders and job scripts. Set `EXAMPLE_RUN_MODE="submit"` in the cluster config if you want it to copy selected examples from `EXAMPLES_ROOT` into the local run workspace (`reports/<cluster>/<run_id>/work/examples/`) and submit them from there.

This suite does not execute jobs directly in the source `EXAMPLES_ROOT` path; it copies what it needs into scratch first.
