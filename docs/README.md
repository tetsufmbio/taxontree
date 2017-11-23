# TaxOnTree: Including taxonomic information in phylogenetic trees

*Sakamoto T.* and *J. M. Ortega*

## Summary

[1. About TaxOnTree and this document](#1-about-taxontree-and-this-document)
https://github.com/tetsufmbio/taxontree/tree/docs/docs#2-taxontree-features
https://github.com/tetsufmbio/taxontree/tree/docs/docs#21-taxontree-workflow
https://github.com/tetsufmbio/taxontree/tree/docs/docs#22-lowest-common-ancestor-lca
https://github.com/tetsufmbio/taxontree/tree/docs/docs#23-missing-ranks-and-taxallnomy-database
https://github.com/tetsufmbio/taxontree/tree/docs/docs#3-installation
https://github.com/tetsufmbio/taxontree/tree/docs/docs#31-prerequisites
https://github.com/tetsufmbio/taxontree/tree/docs/docs#32-downloading-and-installing
https://github.com/tetsufmbio/taxontree/tree/docs/docs#33-testing
https://github.com/tetsufmbio/taxontree/tree/docs/docs#4-command-line-parameters
https://github.com/tetsufmbio/taxontree/tree/docs/docs#41-inputs
https://github.com/tetsufmbio/taxontree/tree/docs/docs#411-single-id--singleid-single_id
https://github.com/tetsufmbio/taxontree/tree/docs/docs#412-sequence-file--seqfile-fasta_file
https://github.com/tetsufmbio/taxontree/tree/docs/docs#413-blast-file--blastfile-blast_file
https://github.com/tetsufmbio/taxontree/tree/docs/docs#414-list-file--listfile-list_file
https://github.com/tetsufmbio/taxontree/tree/docs/docs#415-multi-fasta-file--mfastafile-mfasta_file
https://github.com/tetsufmbio/taxontree/tree/docs/docs#416-aligned-multi-fasta-file--alignfile-align_file
https://github.com/tetsufmbio/taxontree/tree/docs/docs#417-tree-file--treefile-tree_file
https://github.com/tetsufmbio/taxontree/tree/docs/docs#42-other-parameters-that-follow-the-input
https://github.com/tetsufmbio/taxontree/tree/docs/docs#421-blast-option
https://github.com/tetsufmbio/taxontree/tree/docs/docs#422-alignment-option
https://github.com/tetsufmbio/taxontree/tree/docs/docs#423-tree-option
https://github.com/tetsufmbio/taxontree/tree/docs/docs#424-filter-option
https://github.com/tetsufmbio/taxontree/tree/docs/docs#425-other-parameters
https://github.com/tetsufmbio/taxontree/tree/docs/docs#43-outputs
https://github.com/tetsufmbio/taxontree/tree/docs/docs#5-exploring-the-nexus-file-on-figtree
https://github.com/tetsufmbio/taxontree/tree/docs/docs#51-exploring-the-taxonomic-relationship-by-lca
https://github.com/tetsufmbio/taxontree/tree/docs/docs#52-exploring-the-taxonomic-diversity-by-ranks
https://github.com/tetsufmbio/taxontree/tree/docs/docs#53-adding-or-changing-labels-in-the-tree
https://github.com/tetsufmbio/taxontree/tree/docs/docs#54-checking-branch-statistic-support-value
https://github.com/tetsufmbio/taxontree/tree/docs/docs#55-evidencing-duplication-nodes
https://github.com/tetsufmbio/taxontree/tree/docs/docs#6-advanced-topics
https://github.com/tetsufmbio/taxontree/tree/docs/docs#61-running-taxontree-without-internet-connection
https://github.com/tetsufmbio/taxontree/tree/docs/docs#62-adding-other-third-party-software-in-the-pipeline
https://github.com/tetsufmbio/taxontree/tree/docs/docs#7-contact

## 1. About TaxOnTree and this document

[TaxOnTree](http://biodados.icb.ufmg.br/taxontree) is a bioinformatics tool that embeds taxonomic information from [NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/taxonomy) into phylogenetic trees allowing users to easily access the taxonomic information of all samples comprising the tree (**Figure 1**).

<img src="/img/taxontree_man_figure1.png" width=800px/>

**Figure 1**: Phylogenetic tree of Angiogenin processed by TaxOnTree. Branches are colored according to the taxonomic classes (left) in the tree and according to the LCA (right).

This document is a guide to understand all TaxOnTree features and resources to make you an expert in taxonomy. 

## 2. TaxOnTree features

This section describes some features and concepts that you should know to work with TaxOnTree.

### 2.1. TaxOnTree workflow

TaxOnTree workflow is schematized in **Figure 2**. TaxOnTree has a phylogenetic pipeline implemented on it that allows several input format.

<img src="/img/taxontree_MM5.png" width=650px/>

**Figure 2**: TaxOnTree workflow. Dashed boxes in phylogenetic pipeline are optional steps.

### 2.2. Lowest Common Ancestor (LCA)

TaxOnTree uses the concept of LCA to determine the taxonomic relationship between the query organism
and the other organisms in the tree. LCA of two or more organisms represents the most recent ancestor
that all organisms in a set have in common. 

To determine it, TaxOnTree takes advantage of the hierarchical structure from NCBI Taxonomy. As illustration, a short taxonomic lineages of human, dog and frog from NCBI Taxonomy are represented in the **Figure 3**. Walking through the human taxonomic lineage, beginning from the root (level 0), we could observe that several taxa comprising the human lineage are shared with the other two species. However, in different point of the human lineage, frog and dog lineages take different route. The frog lineage diverge from the human lineage after the level 17 (Amniota), while, in dog lineage, this occur at level 21 (Boreoeutheria). The last taxa shared between the pairs of lineages human X frog or human X dog are what we denominate as LCA. The higher the LCA level, the more recent the first divergence between the species in comparison and, thus, the more closer they are. So, for instance, by comparing the LCA level of human x frog and human x dog, we could claim that human is more closely related to dog than to frog.  

<img src="/img/lca_frog.png" width=650px/>

**Figure 3**: Determining LCA. Taxonomic lineage of human, dog and frog are shown. LCA between human and dog is Boreoeutheria, while LCA between human and frog is Amniota.

### 2.3. Missing ranks and Taxallnomy database

 Whenever we are querying for a taxonomic rank from NCBI Taxonomy, two issues have to be considered :
 * Some taxonomic ranks are absent in a taxonomic lineage, e.g. there is no taxon for subclass, superclass, and subphylum in the human lineage (**Figure 4A**);
 * Some taxa found in a taxonomic lineage do not have a taxonomic rank. These taxa are referred as *no rank*, e.g. Theria, Eutheria, Boroeutheria and others are taxa without rank in the human lineage (**Figure 4A**).  
  
 To handle these issues, we use [Taxallnomy](http://biodados.icb.ufmg.br/taxallnomy), a taxonomic database which provides a taxonomic lineage with all ranks for all taxa comprising the NCBI Taxonomy. Taxallnomy provides a balanced version of the taxonomic tree from NCBI Taxonomy which its hierarchical levels are correspondent to the taxonomic ranks. **Figure 4B** shows the human taxonomic lineage retrieved from Taxallnomy database. Ranks that are originally missing in the human taxonomic lineage are filled by this data.  
<img src="/img/taxontree_taxsimple.png" width=650px/>
  
**Figure 4**: Human taxonomic lineage from (A) NCBI Taxonomy and from (B) Taxallnomy. Taxa with a taxonomic rank assigned are in blue and taxa exclusive from Taxallnomy are in red.

## 3. Installation

TaxOnTree source code can be dowloaded at its [GitHub page](https://github.com/tetsufmbio/taxontree/). Here we describe how to install it in a local machine.

### 3.1. Prerequisites

Some prerequisites are required to run TaxOnTree. They are:

* Unix Platform;

  TaxOnTree was tested on Ubuntu, CentOS and MacOS, but it should work on
  any Unix platforms.

* Perl;

  Almost all Unix platforms have Perl 5 installed. To verify that, type `perl -v` 
  in a command shell. If not, follow the instructions on [Perl website]
  (https://www.perl.org/get.html) for its installation.

* Internet connection;

  This is required to allow TaxOnTree to retrieve sequence and taxonomic information
  via REST request from NCBI or Uniprot servers.  

* [OpenSSL](https://www.openssl.org/);

  [OpenSSL](https://www.openssl.org/) package is required by TaxOnTree to communicate 
  with NCBI server which uses HTTPS communication protocol. Run the command `openssl version`
  to verify if it is installed in your system. This can be installed using the installation 
  tool of your Unix distribution (`sudo apt-get install libssl-dev` for Debian or 
  `sudo yum install openssl-dev` for RPM based distribution).

* [FigTree](http://tree.bio.ed.ac.uk/software/figtree/).

  A free graphical phylogenetic trees viewer developed in Java by Andrew Rambaut group. 
  TaxOnTree output is made to be visualized in this software. There are versions for MacOS, 
  Linux and Windows. Pick the one that is more convenient for you.

### 3.2. Downloading and installing

In a UNIX terminal, type the following commands:

```bash
> git clone https://github.com/tetsufmbio/taxontree.git
> cd taxontree
> ./install.sh  # Here you'll be asked for your email address.
```

> NOTE: A **valid email address** is required for TaxOnTree execution to request data from
other servers like NCBI and UniProt. The email address is requested by those servers admin
to contact you when necessary. This could happen if you are using TaxOnTree excessively.
To run TaxOnTree without internet connection, refer to the [advanced topics]() of this manual.

This will install all TaxOnTree dependencies at $HOME/.taxontree/ folder and create 
an executable named taxontree. The installation process will also attempt to install 
some third-party software that is in src folder (**Table 1**).

**Table 1**: Third-party software compiled durint TaxOnTree installation.

| third-party software | phylogenetic pipeline step |                    link                 |
|----------------------|----------------------------|-----------------------------------------|
| MUSCLE               | sequence aligner           | http://www.drive5.com/muscle/           |
| Clustal Omega        | sequence aligner           | http://www.clustal.org/omega/           |
| Kalign               | sequence aligner           | http://msa.sbc.su.se/cgi-bin/msa.cgi    |
| trimAl               | sequence trimmer           | http://trimal.cgenomics.org/            |
| FastTree             | tree reconstructor         | http://www.microbesonline.org/fasttree/ |

If some of them could not be installed, you can try to install them manually on your system.

> NOTE: Third-party software is only required when using TaxOnTree phylogenetic pipeline.
If your input is a tree in Newick format, no third-party software is necessary.

### 3.3. Testing

If the installation went well, it should create an executable called `taxontree` and display
the following message after the command `./taxontree -version`.

```
> ./taxontree -version

        TaxOnTree  Copyright (C) 2015-2017  Tetsu Sakamoto
        This program comes with ABSOLUTELY NO WARRANTY.
        This is free software, and you are welcome to redistribute it under
        certain conditions. See GNU general public license v.3 for details.

TaxOnTree v.1.10
```

In sample folder, there is a Newick file to test if TaxOnTree is working. Try the following command:

```bash
> ./taxontree -treefile sample/test.nwk -queryid 544509544
```

This should generate a file called *test_seq_tree.nex*. Try openning this file on **FigTree**.

### 4. Command-line parameters

#### 4.1 Inputs

#### 4.1.1. Single ID (-singleid <single_id>)

Single protein accession number from NCBI (GI or accession number) or UniprotKB (accession number or entry name). 
Example: "P04156" or "4757876" or "PRIO_HUMAN".

#### 4.1.2. Sequence file (-seqFile <fasta_file>)

A file containing a single sequence in FASTA format. You may provide the taxonomy ID of your sequence
by using the parameter `-queryTax` <taxonomy_id> in the command line, or else, TaxOnTree will attribute
the taxonomy ID of the Blast best hit as its taxonomy ID.

Example:
```
>Human_Prion
MANLGCWMLVLFVATWSDLGLCKKRPKPGGWNTGGSRYPGQGSPGGNRYPPQGGGGWGQP
HGGGWGQPHGGGWGQPHGGGWGQPHGGGWGQGGGTHSQWNKPSKPKTNMKHMAGAAAAGA
VVGGLGGYMLGSAMSRPIIHFGSDYEDRYYRENMHRYPNQVYYRPMDEYSNQNNFVHDCV
NITIKQHTVTTTTKGENFTETDVKMMERVVEQMCITQYERESQAYYQRGSSMVLFSSPPV
ILLISFLIFLIVG
```

#### 4.1.3. Blast file (-blastFile <blast_file>)

Blast result of a single protein generated by Standalone BLAST+ in tabular format (-outfmt 6). You may provide a protein accession 
from the result to be considered as query using `-queryID`, or else, TaxOnTree will consider the protein 
in the first column or, if it is not an identifier from NCBI or Uniprot, the best hit subject as query.

#### 4.1.4. List file (-listFile <list_file>) 

A file containing a list of protein identifiers from NCBI (GI or accession number) or UniprotKB 
(accession number or entry name) separated by new line. You may provide a protein accession from 
the list to be considered as query using `-queryID`, or else, TaxOnTree will consider the first entry 
in the list as query. 

#### 4.1.5. Multi-FASTA file (-mfastaFile <mfasta_file>)

A Multi-FASTA file containing ortholog sequences. You may provide a protein accession from the file to be 
considered as query using `-queryID`, or else, TaxOnTree will consider the first entry in the file as query.

#### 4.1.6. Aligned multi-FASTA file (-alignFile <align_file>)

An Aligned Multi-FASTA file. You may provide a protein accession from the list to be considered as 
query using `-queryID`, or else, TaxOnTree will consider the first entry in the file as query.

#### 4.1.7. Tree file (-treeFile <tree_file>)

A tree file in NEWICK format. You must provide the protein in the tree to be considered as query by
using `-queryID`. If the leaves of the tree are not exactly an accession number from NCBI or UniprotKB, but it contains the accessions in their names, you can use `-delimiter` and `-position` parameters to allow TaxOnTree to extract the accession and retrieve the taxonomy ID of each proteins. Alternatively, you can provide a table containing the leaves (first column) and their
corresponding taxonomy id (second column) using the option `-treetable`. To generate a file with all leaves
name in your tree, use the option `-printLeaves`. 

### 4.2. Other parameters that follow the input

Parameters described here can be used to customize the phylogenetic pipeline, the tree output or 
even provide additional information to be embeded in the tree. To facilitate the comprehension
we subdivided these parameters according to the phylogenetic steps that they are related. 

#### 4.2.1. Blast option

* **-db <database_name> Default: refseq_protein**

BLAST-formatted database name. It works on -seqFile, -singleID, -blastFile and -listFile.

For Standalone protein BLAST search, provide the address and the name (without extension) of the database. 
Example: /home/user/taxontree/db, where db is the name of BLAST-formatted database. This option will
only work if the database was generated using sequences from GenBank or Uniprot (using its 
FASTA-header pattern) and the option -parse_seqids on makeblastdb command (See details on README).

To request the BLAST search from NCBI server, you may choose one of these databases: 
nr or refseq_protein. 

* **-evalue <real_value> Default: 10e-5**

Expect value threshold for BLAST search. It works on -seqFile and -singleID.

* **-threshold <int_value> Default: 50**

Protein identity threshold. For each subject, TaxOnTree calculates its identity with the query sequence after
removing overlapping HSPs and considering the length of the query sequence. Threshold may vary between 0-100.
It works on -seqFile, -blastFile and -singleID.

* **-maxTarget <int_value> Default: 200**

Max target sequences to be used for phylogenetic analysis. It works on -seqFile, -blastFile and -singleID.

* **-maxTargetBlast <int_value>**

Max target sequence to be retrieved by BLAST. It works on -seqFile and -singleID.

#### 4.2.2 Alignment option

* **-aligner <aligner_software> Default: muscle**

Software for sequence alignment step. It works on -seqFile, -blastFile, -listFile, -mfastaFile and -singleID. 
To add more aligners, see CONFIG.xml.

* **-trimming <trimming_software> Default: trimal**

Software for alignment trimming step. You can set "false" to skip this step. It works on -seqFile, -blastFile, -listFile, -mfastaFile, 
-alignFile and -singleID. To add more alignment trimming software, see CONFIG.xml.

#### 4.2.3. Tree option

* **-treeProg <tree_reconstruction_software> Default: FastTree**

Software for tree reconstruction. It works on -blastFile, -listFile, -mfastaFile, -alignFile and -singleID. To add more tree 
reconstruction software, see CONFIG.xml.

* **-treeTable <table_file>**

A table containing the leaf names of the input tree file in the first column and the correspondent taxonomy
ID in the second. Use this option if the input tree does not contain an accession from NCBI or Uniprot
in its leaves. To obtain a list of leaf names in your tree, use the option -printLeaves. It works on -treeFile.

Example: For a newick tree "(gorilla,(human,chimp))", you could provide a tab-delimited table like this:

	human	9606
	chimp	9598
	gorilla	9595

* **-printLeaves**

Print the leaf names comprising your tree and exit. Use this to help you making the tree table file. It works on -treeFile.

* **-treeRoot Default: 1**

Define tree rooting mode. Use 0 to skip this step, 1 to root at midpoint or 2 to use taxonomic information do define a root. It works on all input.

* **-leafFmt Default: "lcaN;id;geneName;species"**

Leaf name format displayed in the tree. It works on all input. Data available to display in the leaf are: lcaN, lca, id, accession, species, geneID, geneName, rankcode, rankname. Use semicolons to separate the different data type. 

For "rankcode" and "rankname", include the taxonomic ranks that you want to display separated with comma and delimited by parenthesis. Taxonomic rank options: superkingdom, kingdom, phylum, subphylum, superclass, class, subclass, superorder, order, suborder, superfamily, family, subfamily, genus, subgenus, species, subspecies. 

#### 4.2.4 Filter option

* **-showIsoform**

TaxOnTree automatically links the RefSeq or Uniprot protein to a GeneID and discards its isoforms 
from further analysis. Use this option to allow isoforms in the tree. It works on all inputs.

* **-lcaLimit <int_value>**

Exclude all sequences from organisms which the LCA with the query organism is below the provided level. 
It works on all inputs.

* **-lcaLimitDown <int_value>**

Exclude all sequences from organisms which the LCA with the query organism is above the provided level 
(except for the query sequence). It works on all inputs.

* **-taxFilterCat <category>**

Filter sequences by category which could be a taxonomic rank or LCA. If "kingdom" is provided, it'll leave 
sequences from N organisms in each kingdom found in the tree. Use -taxFilter to define the N. It works on all inputs.

Categories allowed: lca, superkingdom, kingdom, phylum, subphylum, superclass, class, subclass, superorder, order, suborder, 
superfamily, family, subfamily, genus, subgenus, species, subspecies.

* **-taxFilter <int_value>**

Filter sequences by category which could be a taxonomic rank or LCA. If 2 is provided, it'll leave 
sequences from 2 organisms in each category found in the tree. Use -taxFilterCat to define the category. 
It works on all inputs.

* **-restrictTax <list_file>**

Provide a list of taxonomy ID (separated by newline) to show only sequences belonging to organisms which 
have their taxonomy ID listed in the file. It works on all inputs.

#### 4.2.5. Other parameters

* **-txidMap <taxonomy_id>**

Force TaxOnTree to consider the taxonomy ID provided by this option to be mapped in the tree. Example: "9606"
for human. It works on all inputs. 

* **-queryTax <taxonomy_id>**

NCBI taxonomy ID assigned to the query protein. Example: "9606" for human. It works only in -seqFile. 

* **-queryID <query_id>**

Protein accession or name in the list or tree to be considered as query. It works on -blastFile, -listFile, -mfastaFile
-alignFile and -treeFile. 

* **-forceNoTxid**

Retain entries in which TaxOnTree could not determine their taxonomy ID. These entries will
be assigned with the taxonomy ID of root (txid:1). It works on all inputs.

* **-forceNoInternet**

Force TaxOnTree to not retrieve data from internet. It works on all inputs.

* **-out <file_name> Default: Input name**

Prefix for output files. It works on all inputs.

* **-mysql**

Use a local MySQL database to retrieve required TaxOnTree data (See README for details). It works on all inputs.

* **-numThreads Defalut: 1**

Number of processors to be used for programs that can handle multi-threading. It works on all inputs.

* **-version**

Print TaxOnTree version.

### 4.3. Outputs

Besides the tree file in Nexus format, other type of files are also generated during a TaxOnTree run. Most of them are
inputs and outputs of each phylogenetic pipeline steps. The list of those files are summarized below (consider the file
prefix as *query*):

* **query_blast.txt** - Blast result;
* **query_all_seq.fasta** - Sequences in FASTA format that were submitted to the phylogenetic pipeline.
* **query_seq_aligned.fasta** - Sequences in FASTA format after the alignment.
* **query_seq_aligned_trimmed.fasta** - Aligned sequences in FASTA format after trimming.
* **query_seq_tree.nwk** - Tree in Newick format. 
* **query_taxRankTable.txt** - A table containing some data about the clusters formed on each taxonomic rank.
* **query_seq_tree.nex** - Tree in Nexus format.

## 5. Exploring the Nexus file on FigTree

After running TaxOnTree from [web interface](http://biodados.icb.ufmg.br/taxontree/) or from [command line](https://sourceforge.net/projects/taxontree/), TaxOnTree will generate a **Nexus file** structured to be opened on [FigTree](http://tree.bio.ed.ac.uk/software/figtree/) software. 

### 5.1. Exploring the taxonomic relationship by LCA

Right after opening the Nexus file in FigTree, you will see your phylogenetic tree with the branches colored according to the LCA (Lowest Common Ancestor) between the query species (in red) and the other species in the tree (**Figure 5**). LCA of two or more organisms represents the most recent ancestor that all organisms in the set have in common (see **Box 1** for mor details). There will have also a legend for the colors used in the branches of the tree. 

<img src="/img/taxontree_figtree1.png" width=650px/>

**Figure 5**: FigTree tree display right after opening a Nexus file generated by TaxOnTree.

> **Note**: Some taxon names in the legend are followed by an asterisk. This indicates that there is no organism in the tree that has this taxon as the LCA with the query organism.

### 5.2. Exploring the taxonomic diversity by ranks

Did you ever asked yourself how many distinct class, order or family are in your tree? This can be shortly answered with a tree generated by TaxOnTree in hand. TaxOnTree also embeds in the tree data of taxonomic lineage of all taxa comprising the tree, allowing the colorization of the tree according to a taxonomic rank. Take the following steps in the FigTree software:

1. In the FigTree side menu, go to *Appearance*;
1. In *Colour by* parameter, and choose a taxonomic rank to be used to color the branches. By choosing *08-superorder*, for example, the tree will be colored according to the superorder rank. You can setup the branch colors by clicking in *Colours* button;
1. To make the color legend concordant to the branch color, go to *Legend* in the FigTree side menu;
1. In *Attribute* parameter, set the same taxonomic rank that you selected in the previous step (**Figure 6**).

<img src="/img/taxontree_figtree2.png" width=650px/>

**Figure 6**: Steps on FigTree to evidence taxonomic diversity by ranks.

> **Note**: Ranks that are missing in a taxonomic lineage are filled using Taxallnomy database. See **Box 2** for more details.

### 5.3. Adding or changing labels in the tree

Taxonomic data can also be evidenced on the tips, nodes and/or branches in the tree. For instance, to change the tip label, go to *Tip labels*, on FigTree side menu; and, on *Display* parameter, select a taxonomic rank to be diplayed at the tip of the tree (**Figure 7**).

To evidence the taxonomic data on the nodes and/or on branches of the tree, use the same procedures but at *Node label* and/or *Branch label*, respectively.

<img src="/img/taxontree_figtree3.png" width=650px/>

**Figure 7**: Steps on FigTree to to add or change labels in the tree.

### 5.4. Checking branch statistic support value

By default, nodes in the tree are sized proportionally to the statistic support of the branch. If you want to know their values go to *Node label* on FigTree side menu and choose *BOOT* on *Display* parameter.

### 5.5. Evidencing duplication nodes

TaxOnTree also annotates those nodes that represent duplication events. To evidence them, go to the *Node shapes*, on FigTree side menu, and choose *dup* on *Size by* parameter. Set also an appropriate value for *Max size* (i.e. 6) and *Min size* (i.e. 0) parameters.

<img src="/img/taxontree_figtree4.png" width=650px/>

**Figure 8**: Steps on FigTree to evidence duplication nodes on the tree.

## 6. Advanced topics

### 6.1. Running TaxOnTree without internet connection

TaxOnTree depends on internet connection to retrieve taxonomic or sequence data from NCBI
or UniProt servers. To make TaxOnTree independent from using internet connection, there 
are additional prerequisites. They are:

* Standalone Blast+

  Blast executables are required to perform sequence similarity search and to retrieve 
  sequences from a Blast-formatted database.  Standalone Blast+ can be downloaded 
  at ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/. 

* Blast-formatted sequence database

  A sequence database generated by `makeblastdb`, one of Blast executables. If you have a Multi-FASTA
  file containing protein sequences from NCBI or UniProt, you can execute the following command to get a
  Blast-formatted sequence database:
  
  ```
  > makeblastdb -in <multi-fasta_file> -out <database_name> -dbtype prot -parse_seqids -hash_index
  ```
  
  Blast-formatted sequence databases used in [TaxOnTree web tool](http://bioinfo.icb.ufmg.br/taxontree) 
  are also available at our [Sourceforge page](https://sourceforge.net/projects/taxontree/files/db/).

* MySQL

  TaxOnTree can access taxonomic data from a MySQL database. If you don't have MySQL installed in your 
  system, please refer to the installation instruction at [MySQL page](https://dev.mysql.com/doc/refman/5.7/en/general-installation-issues.html).
  
  You'll also need an user account that have all privileges granted on database named `taxontree`. Access 
  your MySQL using the MySQL root account (`mysql -u root -p`) and type the following commands on MySQL environment:
  
  ```
  mysql> CREATE DATABASE taxontree;
  mysql> CREATE USER 'taxontreeUser'@'localhost' IDENTIFIED BY PASSWORD 'xxxxxxx';
  mysql> GRANT ALL ON taxontree.* TO 'taxontreeUser'@'localhost';
  ```
  
  The first command creates a database named *taxontree*. The second command creates a MySQL account
  with username *taxontreeUser* and password *xxxxxxx* (here you can set a more convenient username and password).
  Finally, the last command grants all privileges to the user *taxontreeUser* on *taxontree* database. 
  
  Now, you have to configure TaxOnTree to access MySQL using the username and password set previously.
  For this, open the file *~/.taxontree/CONFIG.xml* with your preferred text editor. In this XML file, you'll
  find a *mysql* tag that range from line 14 to line 29. Set the MySQL username created previously and its
  password at the *user* and *password* tags, respectively, like below and save the file.
  
  ```xml
  ...
  <mysql>
    <user>taxontreeUser</user>
    <password>xxxxxxx</password>
    <host>localhost</host>
    <port>3306</port>
    <database>taxontree</database>
    ...
  </mysql>
  ...
  ```
  
* TaxOnTree tables
  
  The last step is to populate the taxontree database with TaxOnTree tables. The tables are available at our
  [SourceForge page](https://sourceforge.net/projects/taxontree/files/db/). Download the file taxontree.sql.tgz and type
  the following commands:
  
  ```bash
  > tar -zxf taxontree.sql.tgz
  > cd taxontree_sql
  > mysql -u <username> -p < taxontree.sql
  ```
  
  Use the username of MySQL account that you have created in the previous section. The last command 
  should take some time, so please be patient.
  
> **Note**: TaxOnTree databases take up a lot of hard disk space (~30 GB). So, check your demand and evaluate
if it is worth having a local databases installed or if only web requests should be enough for your analysis.

After fullfilling these requisites, you can now run TaxOnTree independently of internet connection. To tell TaxOnTree
to access the MySQL database, add the parameter `-mysql` on the command line as below:

```bash
> ./taxontree -treefile sample/test.nwk -queryid 544509544 -mysql
```

If a sequence database is requested by TaxOnTree, you can provide its location using 
the `-db` parameter as below: 

```bash
> ./taxontree -singleid 4757876 -db /path/to/seq_database -mysql
```

If some data are not available in the local database, TaxOnTree will try to retrieve them from NCBI or UniProt
servers through internet. If your server has internet connection but you don't want TaxOnTree to retrieve data from 
those servers, add the parameter `-forceNoInternet` in the command line 
(e.g. `./taxontree -singleid 4757876 -db /path/to/seq_database -mysql -forceNoInternet`).

### 6.2. Adding other third-party software in the pipeline

Third-party software that comprise the TaxOnTree phylogenetic pipeline are subdivided 
in the following types:

* *Blast search* - this is performed exclusively by [Blast+](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download);
* *Sequence aligner* - software that performs sequence alignment. Must have Multi-FASTA file as input and as output;
* *Sequence trimmer* - software that trim a sequence alignment according to its quality. Must have Multi-FASTA file as input and as output;
* *Tree reconstructor* - software that reconstruct the phylogenetic history of a set of sequences. Must have an aligned Multi-FASTA as input and a tree in Newick format as output.

Third-party software that met the conditions above can be incorporated in TaxOnTree phylogenetic pipeline. 
To make these software viewable by TaxOnTree, they have to be installed in your system or, alternatively,
you can compile them and move their executables to the `~/.taxontree/bin` folder. Furthermore, parameters and
command lines that TaxOnTree executes for each third-party software have to be set in CONFIG.xml located 
in `~/.taxontree` folder. Third-party software that is compiled during TaxOnTree installation is already 
configured in the original CONFIG.xml.

Let consider that you want to add the software **MAFFT**, another largely used sequence aligner. 
To do that, you have to first compile and install it in your system (for this
check MAFFT installation insctruction) or move the compiled executables to the folder `~/.taxontree/bin`. Any one of these
procedures will make **MAFFT** visible to TaxOnTree.

After that, you have to include MAFFT in the TaxOnTree phylogenetic pipeline and set the command-line
that you want to execute when TaxOnTree calls it. This is performed in the CONFIG.xml file that is located at
`~/.taxontree/` folder. So, open the CONFIG.xml in the text editor of your preference.

In the CONFIG.xml file, you'll find the *programs* tag from the line 77. Inside *programs* tag, there are four 
other tags corresponding to each step of the phylogenetic pipeline. They are:

```xml
<programs> <!--third party software used in... -->
  <blastsearch>...</blastsearch> <!-- blast search step... -->
  <aligners>...</aligners>       <!-- sequence alignment step -->
  <trimming>...</trimming>       <!-- sequence alignment trimming step -->
  <treeReconstruction>...</treeReconstruction> <!-- tree reconstruction step -->
</programs>
```

Inside each tag of phylogenetic pipeline step, there are several *program* tags. 
Each *program* tag corresponds to the configuration of one software included in this pipeline step.
Inside a *program* tag, we have four more other tags:

```xml
<programs>
  <blastsearch>...</blastsearch>
  <aligners> <!-- third-party software configuration for alignment step...-->
    <program>
      <name>...</name>       <!--name of the software executable.-->
      <path>...</path>       <!--path to the software executable. Leave it blank if the executable is in the folder 
	                         `~/.taxontree/bin` or in a folder contained in your PATH-->
      <command>...</command> <!--parameters used after software call. Use the #INPUT and #OUTPUT codes to refer to the 
                                 input and output files. Use #NUMTHREADS to refer to the number of threads to be used 
                                 (this is set by the parameter -numthreads on TaxOnTree).-->
      <outName>...</outName> <!--name of the output file. Place #OUTPUT if the name of the output file will be the same 
                                 as the name set in the *command* tag. If a software, for instance, add the extension .fas
                                  in the name of the output place #OUTPUT.fas here.-->
    </program>
  </aligners>
  <trimming>...</trimming>
  <treeReconstruction>...</treeReconstruction>
</programs>
```

So, to add a software to the phylogenetic pipeline, just add another *program* tag to the correspondent phylogenetic
pipeline step tag. Since MAFFT is a software for sequence alignment, we will add a *program* tag inside the 
*aligners* tag. 

Let say that you want to run MAFFT in high-speed mode and using multi-threads as below:

```bash
> ./mafft --quiet --thread [threads] [input_file] > [output_file]
```

To configure the previous command in CONFIG.xml, just add a *program* tag inside the *aligners* 
tag with the following configuration:

```xml
  <program>
    <name>mafft</name>
    <path></path>
    <command>--quiet --thread #NUMTHREADS #INPUT > #OUTPUT</command>
    <outName>#OUTPUT</outName>
  </program>
```

Your *aligners* tag should look like this:

```xml
...
 <aligners>
  <program>
    <name>mafft</name>
    <path></path>
    <command>--quiet --thread #NUMTHREADS #INPUT > #OUTPUT</command>
    <outName>#OUTPUT</outName>
  </program>
  <program>
    <name>muscle</name> <!--http://www.drive5.com/muscle/downloads.htm-->
    <path></path>
    <command>-in #INPUT -out #OUTPUT -quiet</command>
    <outName>#OUTPUT</outName>
  </program>
  ...
 </aligners>
...
```

Save the file. Now the newly configured aligner can be used by TaxOnTree. To select this aligner on a TaxOnTree run,
add the parameter `-aligner mafft` to the command-line as below:

```bash
> ./taxontree -singleid 4757876 -aligner mafft
```

If you added another third-party software for trimming or tree reconstruction steps, use respectively the parameters `-trimming` or `-treeProg` to select the newly added software. 

## 7. Contact

If you have any trouble or suggestion to improve our work, please contact us by the following email address:

* tetsufmbio@gmail.com (Tetsu Sakamoto)
* miguel@ufmg.br (J. Miguel Ortega)

_**Laboratório de Biodados**  
Instituto de Ciências Biológicas (ICB)  
Universidade Federal de Minas Gerais (UFMG)  
Belo Horizonte - Minas Gerais – BRAZIL  
Zip code: 31270-010_
