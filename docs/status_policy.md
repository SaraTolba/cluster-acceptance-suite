# Acceptance policy

Blocking failures:

- Scheduler cannot submit a tiny job.
- Test account/group is rejected.
- Required filesystem path is not writable.
- Required modules cannot load.
- MPI, OpenMP, or hybrid workloads fail.

Warnings:

- Known issue pattern is still present.
- Optional application example is missing.
- Scheduler accounting is incomplete after a job finishes.
- Example folder exists but no job script is found.

Optional tests may report `SKIP` without blocking acceptance.
