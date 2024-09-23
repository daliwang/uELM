# Summit 

## Environments

```
module purge

module load DefApps-2024
module load cmake
module load nvhpc/23.9
module load netcdf-c
module load netcdf-fortran
module load hdf5
module load parallel-netcdf/1.12.2

ulimit -n 102400
ulimit -s 819200
ulimit -c unlimited
```

## uELM Configuration 

### Repo and Branch 
```
git clone git@github.com:daliwang/uELM.git
cd uELM
export uELM_home=$PWD
git checkout elm_datmmode_uELM
git submodule update --init --recursive
```

### Case generation and Compile 
```
cd $uELM_home/case_gene
sh uELM_caseGEN_AKSP.sh
```

Go to the generated case directory. It is usually $uELM_home/e3sm_cases/xxxxx; e.g., $uELM_home/e3sm_cases/uELM_AKSP_I1850uELMCNPRDCTCBC for uELM_caseGEN_AKSP.sh.
```
./case.build
```

Note: uELM_caseGEN_AKSP.sh can be changed other case generators.

### Run
```
./case.submit
```


### Iteractive Run (Optional)

```
bsub -Is -W 2:00 -nnodes 1 -P cli180 $SHELL

module load essl
module load netlib-lapack

python3 .case.run # This need to run ./case.submit once
```
OR, go to the run directory and run the jsrun command directly. For instance,

```
# 1 task
jsrun -X 1 --nrs 1 --rs_per_host 1 --tasks_per_rs 1 -d plane:1 --cpu_per_rs 21 --gpu_per_rs 0 --bind packed:smt:1 -E OMP_NUM_THREADS=1 -E OMP_PROC_BIND=spread -E OMP_PLACES=threads -E OMP_STACKSIZE=256M --latency_priority cpu-cpu --stdio_mode prepended gdb ../bld/e3sm.exe
```

```
# 44 tasks
jsrun -X 1 --nrs 2 --rs_per_host 2 --tasks_per_rs 22 -d plane:22 --cpu_per_rs 21 --gpu_per_rs 0 --bind packed:smt:1 -E OMP_NUM_THREADS=1 -E OMP_PROC_BIND=spread -E OMP_PLACES=threads -E OMP_STACKSIZE=256M --latency_priority cpu-cpu --stdio_mode prepended ../bld/e3sm.exe
```
