# Name of your executable
EXE = hello_hybrid_omp_mpi

# Source files
SRC = hello_hybrid_omp_mpi.f90

# Compiler
FC = mpiifort

# Compiler flags for OpenMP and optimization
FFLAGS = -qopenmp -O2

all: $(EXE)

$(EXE): $(SRC)
	$(FC) $(FFLAGS) -o $@ $<

clean:
	rm -f $(EXE) *.mod
