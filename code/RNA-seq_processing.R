#RNA-seq processing
#This is the differential expression analysis from the total RNA sequencing experiment performed
#on postmortem hippocampus obtained from Down syndrome and control individuals.

#First, we will load all the packages required to perform this analysis
library(dplyr)
library(edgeR)
library(openxlsx)
library(ggrepel)
library(DBI)
library(org.Hs.eg.db)
library("pcaExplorer")
library(TxDb.Hsapiens.UCSC.hg38.knownGene)
library(rtracklayer)
library(ggbio)
library(clusterProfiler)
library(enrichplot)
library(ggridges)
library(karyoploteR)
library(tidyverse)
library(forcats)
library(pathview)
library(ComplexHeatmap)
library(circlize)
library(kableExtra)
library(DT)

#Read the raw count matrix for hippocampus samples
#The count matrix consists of 11 control samples (C1-C11) and 9 Down syndrome samples (Ds1-Ds9)

count_human_total_hippocampus_coding<- read.table(file= "data/raw_counts_human_hippo_matrix_coding.txt", header=T, row.names=1)
head(count_human_total_hippocampus_coding)
meta_counts_human_total_hippocampus_coding<-data.frame(row.names = colnames(count_human_total_hippocampus_coding),
                                                       condition_human_total_hippocampus_coding=
                                                         c("Cont","Cont","Cont","Cont","Cont","Cont","Cont",
                                                           "Cont","Cont","Cont","Cont","DS","DS","DS","DS","DS",
                                                           "DS","DS","DS","DS"))

#Define the groups
group_human_total_hippocampus_coding<-relevel(factor(meta_counts_human_total_hippocampus_coding$condition_human_total_hippocampus_coding),ref="Cont")
group_human_total_hippocampus_coding

#Design the model for performing differential expression analysis
design_human_total_hippocampus_coding = model.matrix(~group_human_total_hippocampus_coding)
y_human_total_hippocampus_coding<-DGEList(count_human_total_hippocampus_coding,group = group_human_total_hippocampus_coding)

#Calculate counts per million in log
cpm_log_human_total_hippocampus_coding<-cpm(y_human_total_hippocampus_coding,log=TRUE)

#### Visualize the log counts per million (cpm) as a heatmap
heatmap(cor(cpm_log_human_total_hippocampus_coding))

#### Perform PCA after loading the sample information
sample_hippo<- read.xlsx("data/human_hippo_samplesheet.xlsx", sheet=1)
row.names(sample_hippo)<-sample_hippo$SampleName
all(colnames(cpm_log_human_total_hippocampus_coding) == rownames(sample_hippo))
p <- PCAtools::pca(cpm_log_human_total_hippocampus_coding, metadata = sample_hippo, removeVar = 0.1)
PCAtools::screeplot(p)
PCAtools::biplot(p)

#### Filter the data based on heatmap, PCA and RIN values
#Looking at the clustering and PCA plots, we remove few samples which look like outliers:
#C6,C7,C8,C9,C10,Ds2,Ds6,Ds7

count_hth_filt_coding2<-count_human_total_hippocampus_coding[,-c(6,7,8,9,10,13,17,18)]
head(count_hth_filt_coding2)
meta_counts_hth_filt_coding2<-data.frame(row.names = colnames(count_hth_filt_coding2),condition_hth_filt_coding2=c("Cont","Cont","Cont","Cont","Cont","Cont","DS","DS","DS","DS","DS","DS"))

####Perform hierarchical clsutering and PCA on the filtered samples
group_hth_filt_coding2<-relevel(factor(meta_counts_hth_filt_coding2$condition_hth_filt_coding2),ref="Cont")
group_hth_filt_coding2
design_hth_filt_coding2 = model.matrix(~group_hth_filt_coding2)
y_hth_filt_coding2<-DGEList(count_hth_filt_coding2,group = group_hth_filt_coding2)
cpm_log_hth_filt_coding2<-cpm(y_hth_filt_coding2,log=TRUE)
heatmap(cor(cpm_log_hth_filt_coding2))
sample_hippo<- read.xlsx("data/human_hippo_samplesheet.xlsx", sheet=2)
row.names(sample_hippo)<-sample_hippo$SampleName
all(colnames(cpm_log_hth_filt_coding2) == rownames(sample_hippo))
p <- PCAtools::pca(cpm_log_hth_filt_coding2, metadata = sample_hippo, removeVar = 0.1)
PCAtools::screeplot(p)
PCAtools::biplot(p)

#### Filter the genes based on their expression in n-1 samples
cpm_y_hth_filt_coding2<-cpm(y_hth_filt_coding2)
keep_hth_filt_coding2<-rowSums((cpm_y_hth_filt_coding2)>1)>5
table(keep_hth_filt_coding2)

#### Perform normalization using TMM
y_hth_filt_coding2<-DGEList(count_hth_filt_coding2,group = group_hth_filt_coding2)
y_hth_filt_coding2 <- y_hth_filt_coding2[keep_hth_filt_coding2, , keep.lib.sizes=FALSE]
y_hth_filt_coding2 <- calcNormFactors(y_hth_filt_coding2)
y_hth_filt_coding2$samples

#### Estimate differential expression using GLM
y_hth_filt_coding2 <- estimateGLMRobustDisp(y_hth_filt_coding2,design_hth_filt_coding2, verbose = TRUE)
fit_hth_filt_coding2 <- glmFit(y_hth_filt_coding2, design_hth_filt_coding2)
lrt_hth_filt_coding2<-glmLRT(fit_hth_filt_coding2,coef = 2)
de_hth_filt_coding2 <- decideTestsDGE(lrt_hth_filt_coding2, adjust.method="BH", p.value = 0.05)

#### Number of differentially expressed genes in the hippocampus
summary(de_hth_filt_coding2)

#### Counts per million (CPM) values for all the genes considered in the differential expression analysis
cpm_y_hth_filt_coding22<-cpm(y_hth_filt_coding2)
cpm_y_hth_filt.dt <- DT::datatable(cpm_y_hth_filt_coding22, rownames=TRUE, class="white-space: nowrap", escape=FALSE)
cpm_y_hth_filt.dt

#### Here, we annotated the data from the previous using ENSEMBL information for each gene and mapped the DEGs onto their chromosomal location.
OrgDb <- org.Hs.eg.db
results_edgeR_hth_filt_coding2<- topTags(lrt_hth_filt_coding2, n = nrow(count_hth_filt_coding2), sort.by = "none")
k<-row.names(results_edgeR_hth_filt_coding2)
ann_hth_filt_coding2<-AnnotationDbi::select(org.Hs.eg.db,keys=k,keytype = "ENSEMBL",columns=c("ENTREZID","SYMBOL","GENENAME","CHR","UNIPROT","ALIAS","GENENAME"))
idx<-match(row.names(results_edgeR_hth_filt_coding2),ann_hth_filt_coding2$ENSEMBL)
results_rna_annotated_hth_filt_coding2<-cbind(results_edgeR_hth_filt_coding2,ann_hth_filt_coding2[idx,])
detags <- rownames(y_hth_filt_coding2)[as.logical(de_hth_filt_coding2)]
sigGenes <- results_rna_annotated_hth_filt_coding2[detags,]
tx<-TxDb.Hsapiens.UCSC.hg38.knownGene
exo <- exonsBy(tx,"gene")
exoRanges <- unlist(range(exo))
sigRegions <- exoRanges[na.omit(match(sigGenes$ENTREZID, names(exoRanges)))]
mcols(sigRegions) <- sigGenes[match(names(sigRegions), sigGenes$ENTREZID),]
sigRegions[order(sigRegions$LR,decreasing = TRUE)]
sigRegions <- keepSeqlevels(sigRegions, value = c("chr1","chr2","chr3","chr4","chr5","chr6","chr7",
                                                  "chr8","chr9","chr10","chr11","chr12","chr13","chr14",
                                                  "chr15","chr16","chr17","chr18","chr19","chr20",
                                                  "chr21","chr22","chrX","chrY"),pruning.mode="tidy")
#seqlevels(sigRegions)
Score <- -log10(sigRegions$FDR)
rbPal <-colorRampPalette(c("blue", "red"))
logfc <- pmax(sigRegions$logFC, -5)
logfc <- pmin(logfc , 5)
Col <- rbPal(10)[as.numeric(cut(logfc, breaks = 10))]
mcols(sigRegions)$score <- Score
mcols(sigRegions)$itemRgb <- Col
#export(sigRegions , con = "topHitshuman_hippo.bed")
top200 <- sigRegions[order(sigRegions$LR,decreasing = TRUE)]
plotGrandLinear(top200 , aes(y = logFC))
mcols(top200)$UpRegulated <- mcols(top200)$logFC > 0
mcols(top200)$DownRegulated <- mcols(top200)$logFC < 0
autoplot(top200,layout="karyogram",aes(color=DownRegulated,fill=DownRegulated))
results_hippo_RNA<-as_tibble(results_rna_annotated_hth_filt_coding2)
row.names(results_hippo_RNA)<-results_hippo_RNA$ENSEMBL
saveRDS(results_hippo_RNA, file = "output/results_hippo_RNA.rds")
saveRDS(sigGenes,file="output/sigGenes_hippo.rds")

#### Results from differential expression analysis for hippocampus samples
results_rna_annotated_hth_filt_coding2.dt <- DT::datatable(results_rna_annotated_hth_filt_coding2, rownames=TRUE, class="white-space: nowrap", escape=FALSE)
results_rna_annotated_hth_filt_coding2.dt

# Read the raw count matrix for cortex samples
#The count matrix consists of 12 control samples (C12-C23) and 10 Down syndrome samples (Ds10-Ds19)
count_human_total_cortex_coding<- read.table(file= "data/raw_counts_human_cortex_matrix_coding.txt", header=T, row.names=1)
head(count_human_total_cortex_coding)
meta_counts_human_total_cortex_coding<-data.frame(row.names = colnames(count_human_total_cortex_coding),condition_human_total_cortex_coding=c("Cont","Cont","Cont","Cont","Cont","Cont","Cont","Cont","Cont","Cont","Cont","Cont","DS","DS","DS","DS","DS","DS","DS","DS","DS","DS"))

#Define the groups
group_human_total_cortex_coding<-relevel(factor(meta_counts_human_total_cortex_coding$condition_human_total_cortex_coding),ref="Cont")
group_human_total_cortex_coding

#Design the model for performing differential expression analysis
design_human_total_cortex_coding = model.matrix(~group_human_total_cortex_coding)
y_human_total_cortex_coding<-DGEList(count_human_total_cortex_coding,group = group_human_total_cortex_coding)

#Calculate counts per million in log
cpm_log_human_total_cortex_coding<-cpm(y_human_total_cortex_coding,log=TRUE)

#### Visualize the log counts per million (cpm) as a heatmap
heatmap(cor(cpm_log_human_total_cortex_coding))

#### Perform PCA after loading the sample information
sample_cortex<- read.xlsx("data/human_cortex_samplesheet.xlsx", sheet=1)
row.names(sample_cortex)<-sample_cortex$SampleName
all(colnames(cpm_log_human_total_cortex_coding) == rownames(sample_cortex))
p <- PCAtools::pca(cpm_log_human_total_cortex_coding, metadata = sample_cortex, removeVar = 0.1)
PCAtools::screeplot(p)
PCAtools::biplot(p)

#### Filter the data based on heatmap, PCA and RIN values
#Looking at the clustering and PCA plots, we remove few samples which look like outliers: C12,C15,C16,C18,Ds10,Ds14

count_cth_filt_coding2<-count_human_total_cortex_coding[,-c(1,4,5,7,13,17)]
head(count_cth_filt_coding2)
meta_counts_cth_filt_coding2<-data.frame(row.names = colnames(count_cth_filt_coding2),condition_cth_filt_coding2=c("Cont","Cont","Cont","Cont","Cont","Cont","Cont","Cont","DS","DS","DS","DS","DS","DS","DS","DS"))

####Perform hierarchical clsutering and PCA on the filtered samples
group_cth_filt_coding2<-relevel(factor(meta_counts_cth_filt_coding2$condition_cth_filt_coding2),ref="Cont")
group_cth_filt_coding2
design_cth_filt_coding2 = model.matrix(~group_cth_filt_coding2)
y_cth_filt_coding2<-DGEList(count_cth_filt_coding2,group = group_cth_filt_coding2)
cpm_log_cth_filt_coding2<-cpm(y_cth_filt_coding2,log=TRUE)
heatmap(cor(cpm_log_cth_filt_coding2))
sample_cortex<- read.xlsx("data/human_cortex_samplesheet.xlsx", sheet=2)
row.names(sample_cortex)<-sample_cortex$SampleName
all(colnames(cpm_log_cth_filt_coding2) == rownames(sample_cortex))
p <- PCAtools::pca(cpm_log_cth_filt_coding2, metadata = sample_cortex, removeVar = 0.1)
PCAtools::screeplot(p)
PCAtools::biplot(p)

#### Filter the genes based on their expression in n-1 samples
cpm_y_cth_filt_coding2<-cpm(y_cth_filt_coding2)
keep_cth_filt_coding2<-rowSums((cpm_y_cth_filt_coding2)>1)>7
table(keep_cth_filt_coding2)

#### Perform normalization using TMM
y_cth_filt_coding2<-DGEList(count_cth_filt_coding2,group = group_cth_filt_coding2)
y_cth_filt_coding2 <- y_cth_filt_coding2[keep_cth_filt_coding2, , keep.lib.sizes=FALSE]
y_cth_filt_coding2 <- calcNormFactors(y_cth_filt_coding2)
y_cth_filt_coding2$samples

#### Estimate differential expression using GLM
y_cth_filt_coding2 <- estimateGLMRobustDisp(y_cth_filt_coding2,design_cth_filt_coding2, verbose = TRUE)
fit_cth_filt_coding2 <- glmFit(y_cth_filt_coding2, design_cth_filt_coding2)
lrt_cth_filt_coding2<-glmLRT(fit_cth_filt_coding2,coef = 2)
de_cth_filt_coding2 <- decideTestsDGE(lrt_cth_filt_coding2, adjust.method="BH", p.value = 0.05)

#### Number of differentially expressed genes in the cortex
summary(de_cth_filt_coding2)

#### Counts per million (CPM) values for all the genes considered in the differential expression analysis
cpm_y_cth_filt_coding22<-cpm(y_cth_filt_coding2)
cpm_y_cth_filt.dt <- DT::datatable(cpm_y_cth_filt_coding22, rownames=TRUE, class="white-space: nowrap", escape=FALSE)
cpm_y_cth_filt.dt

#### Here, we annotated the data from the previous using ENSEMBL information for each gene and mapped the DEGs onto their chromosomal location.
OrgDb <- org.Hs.eg.db
results_edgeR_cth_filt_coding2<- topTags(lrt_cth_filt_coding2, n = nrow(count_cth_filt_coding2), sort.by = "none")
k<-row.names(results_edgeR_cth_filt_coding2)
ann_cth_filt_coding2<-AnnotationDbi::select(org.Hs.eg.db,keys=k,keytype = "ENSEMBL",columns=c("ENTREZID","SYMBOL","GENENAME","CHR","UNIPROT","ALIAS","GENENAME"))
idx<-match(row.names(results_edgeR_cth_filt_coding2),ann_cth_filt_coding2$ENSEMBL)
results_rna_annotated_cth_filt_coding2<-cbind(results_edgeR_cth_filt_coding2,ann_cth_filt_coding2[idx,])
detags <- rownames(y_cth_filt_coding2)[as.logical(de_cth_filt_coding2)]
sigGenes <- results_rna_annotated_cth_filt_coding2[detags,]
tx<-TxDb.Hsapiens.UCSC.hg38.knownGene
exo <- exonsBy(tx,"gene")
exoRanges <- unlist(range(exo))
sigRegions <- exoRanges[na.omit(match(sigGenes$ENTREZID, names(exoRanges)))]
mcols(sigRegions) <- sigGenes[match(names(sigRegions), sigGenes$ENTREZID),]
sigRegions[order(sigRegions$LR,decreasing = TRUE)]
sigRegions <- keepSeqlevels(sigRegions, value = c("chr1","chr2","chr3","chr4","chr5","chr6","chr7",
                                                  "chr8","chr9","chr10","chr11","chr12","chr13","chr14",
                                                  "chr15","chr16","chr17","chr18","chr19","chr20",
                                                  "chr21","chr22","chrX","chrY"),pruning.mode="tidy")
#seqlevels(sigRegions)
Score <- -log10(sigRegions$FDR)
rbPal <-colorRampPalette(c("blue", "red"))
logfc <- pmax(sigRegions$logFC, -5)
logfc <- pmin(logfc , 5)
Col <- rbPal(10)[as.numeric(cut(logfc, breaks = 10))]
mcols(sigRegions)$score <- Score
mcols(sigRegions)$itemRgb <- Col
#export(sigRegions , con = "topHitshuman_cortex.bed")
top200 <- sigRegions[order(sigRegions$LR,decreasing = TRUE)]
plotGrandLinear(top200 , aes(y = logFC))
mcols(top200)$UpRegulated <- mcols(top200)$logFC > 0
mcols(top200)$DownRegulated <- mcols(top200)$logFC < 0
autoplot(top200,layout="karyogram",aes(color=DownRegulated,fill=DownRegulated))
results_cortex_RNA<-as_tibble(results_rna_annotated_cth_filt_coding2)
row.names(results_cortex_RNA)<-results_cortex_RNA$ENSEMBL
saveRDS(results_cortex_RNA, file = "output/results_cortex_RNA.rds")
saveRDS(sigGenes,file="output/sigGenes_cortex.rds")

#### Results from differential expression analysis for cortex samples
results_rna_annotated_cth_filt_coding2.dt <- DT::datatable(results_rna_annotated_cth_filt_coding2, rownames=TRUE, class="white-space: nowrap", escape=FALSE)
results_rna_annotated_cth_filt_coding2.dt



