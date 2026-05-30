#include <stdio.h>
#ifdef _OPENMP
#include <omp.h>
#endif

int main(void) {
#ifdef _OPENMP
    int nthreads = 0;
#pragma omp parallel
    {
#pragma omp atomic
        nthreads++;
    }
    printf("OPENMP_HELLO threads=%d\n", nthreads);
#else
    printf("OPENMP_HELLO threads=1 no_openmp\n");
#endif
    return 0;
}
