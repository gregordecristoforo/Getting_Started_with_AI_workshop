#!/bin/bash
#SBATCH --account=project_465001363
#SBATCH --reservation=AI_workshop   # comment this out if the reservation is no longer available
#SBATCH --partition=small-g
#SBATCH --gpus-per-node=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=7
#SBATCH --mem-per-gpu=60G
#SBATCH --time=0:15:00

# Set up the software environment
# NOTE: the loaded modules make relevant filesystem locations available inside the singularity container
#   singularity-userfilesystems mounts project filesystem locations so that they can be accessed from the container (/scratch, /project, etc)
#   singularity-CPEbits mounts some important system libraries that are optimized for LUMI
# If you are interested, you can check the exact paths being mounted from
#   /appl/local/training/modules/AI-20241126/<module-name>/default.lua
module purge
module use /appl/local/training/modules/AI-20241126/
module load singularity-userfilesystems singularity-CPEbits

CONTAINER=/scratch/project_465001363/containers/pytorch_transformers.sif

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

set -xv # print the command so that we can verify setting arguments correctly from the logs
srun singularity exec $CONTAINER \
    python GPT-neo-IMDB-finetuning.py \
        --model-name gpt-imdb-model \
        --output-path $OUTPUT_DIR \
        --logging-path $LOGGING_DIR \
        --num-workers ${SLURM_CPUS_PER_TASK} \
        --resume  # Comment this for the first run, uncomment to resume in later runs
