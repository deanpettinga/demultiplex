#PBS -l walltime=120:00:00
#PBS -l mem=90gb
#PBS -l nodes=1:ppn=8
#PBS -M your.email@vai.org
#PBS -m abe
#PBS -N sc-atac-demux

#Change into the directory the script was launched from
demux_dir=${PBS_O_WORKDIR}/
cd $demux_dir
echo "\\\\ Single-cell ATACseq demultiplexing ////"
echo "Run directory: $demux_dir"

#Export bcl2fastq
export PATH=$PATH:/secondary/projects/genomicscore/tools/bcl2fastq/default/bin # bcl2fastq was also too difficult to install as a module

#Load fastqc module
module load bbc/fastqc/fastqc-0.11.8

#Export multiqc
export PATH=/secondary/projects/genomicscore/tools/miniconda2/bin:$PATH # not the best option but I could not install multiqc as a module

#Load cellranger
module load bbc/cellranger-atac/cellranger-atac-1.1.0

# get the flowcell
flowcell=$(cat RunInfo.xml|grep '<Flowcell>'|sed -e 's/<Flowcell>//'|sed -e 's/<\/Flowcell>//'|sed -e 's/ //g'| sed $'s/\r//' | sed -e 's/\s*//g')

if [ ! -d $flowcell ]; then
	# using a simple samplesheet creates an expanded samplesheet in something like <run directory>/<flowcell?/MAKE_FASTQS_CS/MAKE_FASTQS/PREPARE_SAMPLESHEET/fork0/chnk0-ue95dc1ca02/files/samplesheet.csv
	
	echo "Demultiplexing"
	
	# The first run required this bask mask
	#~ cellranger-atac \
	#~ mkfastq \
	#~ --use-bases-mask=Y50n,I8,Y16,Y49n* \
	#~ --run=${demux_dir} \
	#~ --csv=${demux_dir}SampleSheet.csv \
	#~ --qc
	
	# w/o bases-mask option (worked for second run)
	cellranger-atac mkfastq \
	--run=${demux_dir} \
	--csv=${demux_dir}SampleSheet.csv \
	--qc

else
	echo "Demultiplexing is done. If this is not the case, e.g. there was an error, then delete the ${flowcell} directory and resubmit the job."
fi

# FastQC
#echo "cd ${flowcell}/outs/fastq_path/"
cd ${demux_dir}${flowcell}/outs/fastq_path/
mkdir -p FastQC

if [ ! -f FastQC/Undetermined_S0_L001_I1_001_fastqc.zip ]; then
	fastqc -t 16 Undetermined*
	mv *.zip FastQC
	mv *.html FastQC
fi


cd ${flowcell} 

for sample_dir in `ls`; do
	# do fastqc
	echo "FastQC on ${sample_dir}"
	fastqc -t 16 ${sample_dir}/*.fastq.gz

	mv ${sample_dir}/*.zip ../FastQC/
	mv ${sample_dir}/*.html ../FastQC/
	
done

cd ${demux_dir}${flowcell}/outs/fastq_path/


# Multiqc
echo "MultiQC!"
multiqc FastQC

