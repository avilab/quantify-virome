
## Extract unmapped reads [12a]
rule unmapped_reads:
    input:
      os.path.join(config["outdir"], dynamic("{sample}/11_bwa_mem/mapped.{n}.bam"))
    output:
      bam = os.path.join(config["outdir"], dynamic("{sample}/12a_unmapped_reads/RefGenome_unmapped.{n}.bam")),
      fq = os.path.join(config["outdir"], dynamic("{sample}/12a_unmapped_reads/RefGenome_unmapped.{n}.fq")),
      fa = os.path.join(config["outdir"], dynamic("{sample}/12a_unmapped_reads/RefGenome_unmapped.{n}.fa"))
    shell:
      """
        samtools view -b -f 4 {input} > {output.bam}
        bedtools bamtofastq -i {output.bam} -fq {output.fq}
        cat {output.fq} | sed -n '1~4s/^@/>/p;2~4p' > {output.fa}
      """

## Subset repeatmasker maskes reads using unmaped ids [12b]
rule unmapped_masked:
    input:
      os.path.join(config["outdir"], dynamic("{sample}/12a_unmapped_reads/RefGenome_unmapped.{n}.fa")),
      os.path.join(config["outdir"], dynamic("{sample}/10_repeatmasker_good/masked.{n}.fa"))
    output:
      os.path.join(config["outdir"], dynamic("{sample}/12b_unmapped_masked/RefGenome_unmapped.{n}.masked.fa"))
    script:
      "../scripts/unmapped_masked_ids.py"

## MegaBlast against reference genome to remove more host sequences [13]
rule megablast_ref_genome:
    input:
      db = config["ref_genome"],
      query = os.path.join(config["outdir"], dynamic("{sample}/12b_unmapped_masked/RefGenome_unmapped.{n}.masked.fa"))
    output:
      os.path.join(config["outdir"], dynamic("{sample}/13_megablast/megablast.{n}.xml"))
    params:
      perc_ident = config["megablast_ref_genome"]["perc_identity"],
      evalue = config["megablast_ref_genome"]["evalue"],
      word_size = config["megablast_ref_genome"]["word_size"],
      num_desc = config["megablast_ref_genome"]["num_descriptions"],
      num_align = config["megablast_ref_genome"]["num_alignments"]
    threads: 8
    run:
      from Bio.Blast.Applications import NcbiblastnCommandline

      blastn_cline = NcbiblastnCommandline(query = input.query,
                                      db = input.db,
                                      num_threads = threads,
                                      perc_identity = params.perc_ident,
                                      evalue = params.evalue,
                                      word_size = params.word_size,
                                      num_descriptions = params.num_desc,
                                      num_alignments = params.num_align,
                                      outfmt = 5,
                                      out = output)
      stdout, stderr = blastn_cline()

# Filter megablast records for the cutoff value
rule parse_megablast:
    input:
      os.path.join(config["outdir"], dynamic("{sample}/13_megablast/megablast.{n}.xml"))
    output:
      os.path.join(config["outdir"], dynamic("{sample}/14_megablast_parsed/megablast_parsed.{n}.out"))
    params:
      e_cutoff = 1e-10
    run:
      from Bio.Blast import NCBIXML
      result_handle = open(input[0])
      blast_records = NCBIXML.parse(result_handle)

      with open(output[0], "w") as out:
          for blast_record in blast_records:
             for alignment in blast_record.alignments:
                   for hsp in alignment.hsps:
                      if hsp.expect < params.e_cutoff:
                           out.write("****Alignment****" + "\n")
                           out.write("sequence:", alignment.title + "\n")
                           out.write("length:", alignment.length + "\n")
                           out.write("e value:", hsp.expect + "\n")
                           out.write(hsp.query[0:75] + "...\n")
                           out.write(hsp.match[0:75] + "...\n")
                           out.write(hsp.sbjct[0:75] + "...\n")


