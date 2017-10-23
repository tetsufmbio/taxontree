# TaxOnTree: Including taxonomic information in phylogenetic trees

*Sakamoto T.* and *J. M. Ortega*

## About TaxOnTree and this document

[TaxOnTree](http://biodados.icb.ufmg.br/taxontree) is a bioinformatics tool that embeds taxonomic information from [NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/taxonomy) into phylogenetic trees. Trees generated by TaxOnTree allow users to easily access the taxonomic information of the entities comprising a tree. This could be performed either by colorizing the tree according to a taxonomic data or by adding/changing labels to evidence a taxonomic data on the tips, branches or nodes.

This document is a guide for users to understand TaxOnTree features and to explore all resources provided by TaxOnTree to make you an expert in taxonomy. 

## TaxOnTree features

### Phylogenetic pipeline

### Determining the lowest common ancestor (LCA)

LCA of two or more organisms represents the most recent ancestor that all organisms in a set have in common. Determining LCA is a way to measure the taxonomic relationship among the organisms in the analysis. 

To determine it, TaxOnTree takes advantage of the hierarchical structure from NCBI Taxonomy. To illustrate this, a short taxonomic lineages of human, dog and frog from NCBI Taxonomy are represented in the **Figure S2**. Walking through the human taxonomic lineage, beginning from the root (level 0), we could observe that several taxa comprising the human lineage are shared with the other two species. However, in different point of the human lineage, frog and dog lineages take different route. The frog lineage diverge from the human lineage after the level 17 (Amniota), while, in dog lineage, this occur at level 21 (Boreoeutheria). Those taxa, which are the last taxa shared between the pairs of lineages human X dog and human X frog, are what we denominate as LCA. The higher the LCA level, more recent was the first divergence between the species in comparison. So, for instance, by comparing the LCA level, we could claim that human is more closely related to dog than to frog.  

<img src="/img/lca_frog.png" width=650px/>

**Figure S2**: Determining LCA. Taxonomic lineage of human, dog and frog are shown. LCA between human and dog is Boreoeutheria, while LCA between human and frog is Amniota.

### Missing ranks and Taxallnomy database

 Whenever we are querying for a taxonomic rank from NCBI Taxonomy, two issues have to be considered :
 * Some taxonomic ranks are absent in a taxonomic lineage, e.g. there is no taxon for subclass, superclass, and subphylum in the human lineage (**Figure S3A**);
 * Some taxa found in a taxonomic lineage do not have a taxonomic rank. These taxa are referred as *no rank*, e.g. Theria, Eutheria, Boroeutheria and others are taxa without rank in the human lineage (**Figure S3A**).  
  
 To handle these issues, we use [Taxallnomy](http://biodados.icb.ufmg.br/taxallnomy), a taxonomic database which provides a taxonomic lineage with all ranks for all taxa comprising the NCBI Taxonomy. Taxallnomy provides a balanced version of the taxonomic tree from NCBI Taxonomy which its hierarchical levels are correspondent to the taxonomic ranks. **Figure S3B** shows the human taxonomic lineage retrieved from Taxallnomy database. Ranks that are originally missing in the human taxonomic lineage are filled by this data.  
<img src="/img/taxontree_taxsimple.png" width=650px/>
  
**Figure S3**: Human taxonomic lineage from (A) NCBI Taxonomy and from (B) Taxallnomy. Taxa with a taxonomic rank assigned are in blue and taxa exclusive from Taxallnomy are in red.

## Command-line version

Here we describe how to execute TaxOnTree in a local machine.

### Prerequisites:

* Unix Platform;
* PERL;
* Internet connection and/or TaxOnTree MySQL database;
* PERL module IO::Socket::SSL (only for accessing info from NCBI via internet);
* [FigTree](http://tree.bio.ed.ac.uk/software/figtree/)
* Third-party software (only for phylogenetic pipeline).

### Installation

Download the compressed file of TaxOnTree source code from our [sourceforge page](https://sourceforge.net/projects/taxontree/) in a UNIX platform. Then, decompress the file by the following command:

```bash
tar -zxf TaxOnTree.XXX.tgz
```

TaxOnTree is ready to use  in  most  of  Unix  Platform. If you enter the TaxOnTree folder and execute it by the following command: 

```
cd taxontree
./taxontree
```
It should display a message like this:

```
        TaxOnTree  Copyright (C) 2015-2017  Tetsu Sakamoto
        This program comes with ABSOLUTELY NO WARRANTY.
        This is free software, and you are welcome to redistribute it under
        certain conditions. See GNU general public license v.3 for details.

ERROR: No input was provided.
Usage:
    ./taxontree -singleID <sequence_ID>

    ./taxontree -seqFile <FASTA_file>

    ./taxontree -listFile <list_file>

    ./taxontree -treeFile <tree_file> -queryID <query_id>

    Inputs:
        [-seqFile FASTA_file] [-listFile list_file] [-singleID sequence_ID]
        [-treeFile tree_file] [-blastFile blast_file] [-mfastaFile
        mfasta_file] [-alignFile align_file]

    Blast options:
        [-db database_name] [-evalue] [-threshold] [-maxTarget int_value]
        [-maxTargetBlast int_value]

    Alignment options:
        [-aligner] [-trimming]

    Tree options:
        [-treeProg] [-treeTable table_file] [-printLeaves] [-treeRoot]
        [-leafFmt]

    Filter options:
        [-showIsoform] [lcaLimit] [taxFilter] [taxFilterCat] [restrictTax]

    Other parameters:
        [-out file_name] [-queryID query_id] [-queryTax tax_id] [-txidMap
        tax_id] [-position] [-delimiter] [-numThreads] [-mysql]
        [-taxRepFormat] [-forceNoTxid] [-version]

    Help:
        [-help] [-man]

        Use -man for a detailed help.
```

But it only works if the folders lib/ and bin/ that follow this script are  in  the same location. If you want to freely run TaxOnTree  in  other  location,  add the TaxOnTree folder into the environment variable  by  using,  for 	example, the following commands:
	
 ```bash
	> echo "export PATH=$PATH:/path/to/program/taxontree/" >> ~/.bash_profile
	> source ~/.bash_profile
```
### PERL module [IO::Socket::SSL](http://search.cpan.org/~sullr/IO-Socket-SSL-2.052/lib/IO/Socket/SSL.pod)

This module is required only if you are using accession from NCBI and if TaxOnTree needs to retrieve the accession info from NCBI server. The simple way to install this module is to use the CPAN. 

### MySQL database configuration

### Blast sequence database

### Third-party software

### Parameters

### Outputs

## Opening and exploring the Nexus tree on FigTree

After running TaxOnTree from [web interface](http://biodados.icb.ufmg.br/taxontree/) or from [command line](https://sourceforge.net/projects/taxontree/), TaxOnTree will generate a **Nexus file** structured to be opened in [FigTree](http://tree.bio.ed.ac.uk/software/figtree/) software. FigTree is a free graphical viewer of phylogenetic trees developed in Java by Andrew Rambaut group. There are versions for Mac, UNIX and Windows. So, once you have the Nexus file, just download FigTree and open the Nexus file in it. In this manual, we will use a [tree sample]() available in TaxOnTree website.

### Exploring the taxonomic relationship by LCA

After opening the Nexus file in FigTree, you will see your phylogenetic tree with the branches colored according to the LCA (Lowest Common Ancestor) between the query species (in red) and the other species in the tree (**Figure S3**). LCA of two or more organisms represents the most recent ancestor that all organisms in the set have in common (see **Box 1** for mor details). There will have also a legend for the colors used in the tree. 

> **Note**: Some taxon names in the legend are followed by an asterisk. This indicates that there is no organism in the tree that has this taxon as the LCA with the query organism.

### Exploring the taxonomic diversity by ranks

Did you ever asked yourself how many distinct class, order or family are in your tree? You can answer this in a few seconds with a tree generated by TaxOnTree in hand. TaxOnTree also embeds in the tree the taxonomic lineage data of all taxa comprising the phylogenetic tree, allowing you to colorize the tree according to a taxonomic rank. Take the following steps in the FigTree software and, if you are curious about how missing ranks in some lineages are filled in TaxOnTree, check the **Box 2**.

1. In the FigTree side menu, go to *Appearance*;
1.	Click on *Colour by*, and choose a taxonomic rank to be used to color the branches. By choosing *12-family*, for example (**Figure S4**), the tree will be colored according to the family rank. You can setup the branch colors by clicking in *Colours*;
1.	Branch color will change immediately. To make the color legend concordant to the branch color, go to *Legend* in the FigTree side menu and, in *Attribute*, set the same taxonomic rank that you selected in the previous step (**Figure S5**).

### Adding or changing labels in the tree

Taxonomic data can also be evidenced on tip, node and/or branch labels in the tree. For instance, to change the tip label, go to *Tip labels*, on FigTree side menu; and on *Display* select a taxonomic rank to be diplayed at the tip of the tree.

To evidence the taxonomic data on the nodes and/or on branches of the tree, use the same procedure but at *Node label* and/or *Branch label*, respectively.

### Checking branch statistic support value

By default, the statistic support of a branch are evidenced by the size of the nodes, i.e. The bigger the node size, the higher the support. If you want to know their values go to *Node label* on FigTree side menu and choose *BOOT* on *Display*.

### Evidencing duplication nodes

TaxOnTree also annotates those nodes that represent duplication event. To evidence by node size, on FigTree side menu, go to *Node shapes* and choose *dup* on *Size by*. Set also an appropriate value for *Max size* and *Min size* parameters.

## Sample tree images

## Contact

If you have troubles or suggestions to improve our work, please contact us by the following email address:

* tetsufmbio@gmail.com (Tetsu Sakamoto)
* miguel@ufmg.br (J. Miguel Ortega)

_**Laboratório de Biodados**  
Instituto de Ciências Biológicas (ICB)  
Universidade Federal de Minas Gerais (UFMG)  
Belo Horizonte - Minas Gerais – BRAZIL  
Zip code: 31270-010_
