#!/bin/bash
#SBATCH --account=project_465001063
##SBATCH --reservation=AI_workshop_2   # uncomment this to use the reservation during day 2 of the course
#SBATCH --partition=standard-g
#SBATCH --nodes=2
#SBATCH --gpus-per-node=8
#SBATCH --ntasks-per-node=1    # we start a single torchrun process per node, which will take care of spawning more
#SBATCH --cpus-per-task=56     # 7 cores per GPU
#SBATCH --mem-per-gpu=60G
#SBATCH --time=0:15:00


# Set up the software environment
# NOTE: these modules will be available from the LUMI system stack after July 2024 and the "module use" line will no longer work
module purge
module use /appl/local/training/modules/AI-20241126/
module load singularity-userfilesystems singularity-CPEbits

CONTAINER=/scratch/project_465001063/containers/pytorch_transformers.sif

# Some environment variables to set up cache directories
SCRATCH="/scratch/${SLURM_JOB_ACCOUNT}"
FLASH="/flash/${SLURM_JOB_ACCOUNT}"
export TORCH_HOME=$SCRATCH/torch-cache
export HF_HOME=$FLASH/hf-cache
mkdir -p $TORCH_HOME $HF_HOME

# Disable internal parallelism of huggingface's tokenizer since we
# want to retain direct control of parallelism options.
export TOKENIZERS_PARALLELISM=false

# Path to where the trained model and logging data will go
export OUTPUT_DIR=$SCRATCH/$USER/data/
export LOGGING_DIR=$SCRATCH/$USER/runs/
export MODEL_NAME=gpt-imdb-model-multinode

set -xv # print the command so that we can verify setting arguments correctly from the logs

# Ensure that RCCL uses the high-speed interconnect instead of something slow like TCP
export NCCL_SOCKET_IFNAME=hsn

# For multi-node runs we need to specify torchrun rendezvous address
export RDZV_ADDR=$(hostname)
export RDZV_PORT=25900

# Since we start only one task with slurm which then starts subprocesses, we cannot use slurm to configure CPU binds.
# Therefore we need to set them up in the Python code itself.

srun singularity exec $CONTAINER \
    torchrun --nnodes=${SLURM_NNODES} \
             --nproc-per-node=${SLURM_GPUS_PER_NODE} \
             --rdzv-id=${SLURM_JOBID} \
             --rdzv-backend=c10d \
             --rdzv-endpoint=$RDZV_ADDR:$RDZV_PORT \
             GPT-neo-IMDB-finetuning.py \
             --model-name $MODEL_NAME \
             --output-path $OUTPUT_DIR \
             --logging-path $LOGGING_DIR \
             --num-workers $(( SLURM_CPUS_PER_TASK / SLURM_GPUS_PER_NODE )) \
             --set-cpu-binds  # enable setting of the CPU binds in the training script (can only be used with full node runs (standard-g or small-g with slurm argument `--exclusive`))
