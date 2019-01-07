
## Tantan mask of low complexity DNA sequences [6]
rule tantan:
  input: rules.cd_hit.output.repres
  output:
    temp("mask/{sample}_tantan.fasta")
  conda:
      "../envs/tantan.yaml"
  shell:
    """
    tantan -x N {input} > {output}
    """

## Filter tantan output [7]
# 1) Sequences > 50 nt of consecutive sequence without N
# 2) Sequences with >= 40% of total length of being masked
rule tantan_good:
  input:
    masked = rules.tantan.output
  output:
    masked_filt = temp("mask/{sample}_tantangood.fasta")
  params:
    min_length = 50,
    por_n = 40
  wrapper:
    "https://raw.githubusercontent.com/avilab/snakemake-wrappers/master/filter/masked"

## Split reads to smaller chunks for Repeatmasker [8]
rule split_fasta:
  input:
    rules.tantan_good.output
  output:
    temp(expand("mask/{{sample}}_repeatmasker_{n}.fa", n = N))
  params:
    config["split_fasta"]["n_files"]
  conda:
    "../envs/biopython.yaml"
  script:
    "../scripts/split_fasta.py"

os.environ['REPEATMASKER_REPBASE_FILE']=config["repbase_file"]

## Repeatmasker [9]
# Outputs are generated from input file names by RepeatMasker
# must have file extension '.masked'
# If no repetitive sequences were detected syamlink output to input file
rule repeatmasker:
  input:
    fa = "mask/{sample}_repeatmasker_{n}.fa"
  output:
    masked = temp("mask/{sample}_repeatmasker_{n}.fa.masked"),
    out = temp("mask/{sample}_repeatmasker_{n}.fa.out"),
    tbl = "mask/{sample}_repeatmasker_{n}.fa.tbl"
  params:
    outdir = "mask"
  threads: 8
  conda: "../envs/repeatmasker.yaml"
  shell:
    """
    RepeatMasker -qq -pa {threads} {input.fa} -dir {params.outdir}
    if head -n 1 {output.out} | grep -q "There were no repetitive sequences detected"
      then ln -sr {input.fa} {output.masked}
    fi
    """

## Filter repeatmasker output [10]
# 1) Sequences > 50 nt of consecutive sequence without N
# 2) Sequences with >= 40% of total length of being masked
# input, output, and params names must match function arguments
rule repeatmasker_good:
  input:
    masked = rules.repeatmasker.output.masked,
    original = rules.repeatmasker.input.fa
  output:
    masked_filt = "mask/{sample}_repmaskedgood_{n}.fa",
    original_filt = "mask/{sample}_unmaskedgood_{n}.fa"
  params:
    min_length = 50,
    por_n = 40
  wrapper:
    "https://raw.githubusercontent.com/avilab/snakemake-wrappers/master/filter/masked"
