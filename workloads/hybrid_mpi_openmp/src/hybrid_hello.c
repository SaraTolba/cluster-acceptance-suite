#include <mpi.h>
#include <stdio.h>
#include <unistd.h>
#ifdef _OPENMP
#include <omp.h>
#endif

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);
    int rank, size;
    char host[256];
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    gethostname(host, sizeof(host));
#ifdef _OPENMP
    int threads = 0;
#pragma omp parallel
    {
#pragma omp atomic
        threads++;
    }
#else
    int threads = 1;
#endif
    printf("HYBRID_HELLO rank=%d size=%d threads=%d host=%s\n", rank, size, threads, host);
    MPI_Finalize();
    return 0;
}
