
__author__ = "Taavi Päll"
__copyright__ = "Copyright 2018, Avilab"
__email__ = "taavi.pall@ut.ee"
__license__ = "MIT"

## Load libraries
import os
import json
import glob
import pandas as pd
from snakemake.remote.FTP import RemoteProvider as FTPRemoteProvider
from snakemake.utils import validate
shell.executable("bash")

## Load configuration file with sample and path info
configfile: "config.yaml"
validate(config, "schemas/config.schema.yaml")
SAMPLES = pd.read_table(config["samples"], sep = "\s+").set_index("sample", drop=False)
validate(SAMPLES, "schemas/samples.schema.yaml")
SAMPLE_IDS = SAMPLES.index.values.tolist()
N_FILES = config["split_fasta"]["n_files"]
N = list(range(1, N_FILES + 1, 1))

## Create slurm logs dir
if not os.path.exists("logs/slurm"):
    os.makedirs("logs/slurm")

## Main output files and target rules
RESULTS = ["phages", "phages-viruses", "non-viral"]
OUTPUTS = expand("results/{sample}_{result}_{n}.csv", sample = SAMPLE_IDS, n = N, result = RESULTS) + expand("results/{sample}_unassigned_{n}.fa", sample = SAMPLE_IDS, n = N) + expand("taxonomy/{file}.csv", file = ["names", "nodes", "division"])

rule all:
    input:
        OUTPUTS, expand("results/{sample}_{result}.csv.tar.gz", sample = SAMPLE_IDS, result = RESULTS), expand("results/{sample}_unassigned.fa.tar.gz", sample = SAMPLE_IDS) if config["zenodo"]["deposition_id"] else OUTPUTS

## Modules
include: "rules/munge.smk"
include: "rules/cd-hit.smk"
include: "rules/mask.smk"
include: "rules/refgenomefilter.smk"
include: "rules/blast.smk"
