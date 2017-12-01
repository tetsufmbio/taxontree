# TaxOnTree: Including taxonomic information in phylogenetic trees

*Sakamoto T.* and *J. M. Ortega*

[TaxOnTree](http://biodados.icb.ufmg.br/taxontree) is a bioinformatics
tool that embeds taxonomic information from [NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/taxonomy)
 into phylogenetic trees. TaxOnTree generates trees that allow users to 
easily access the taxonomic information of all entities comprising the tree. 

## Prerequisites

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

## Installation

```bash
> git clone https://github.com/tetsufmbio/taxontree.git
> cd taxontree
> ./install.sh  # Here you'll be asked for your email address.
```

> NOTE: A **valid email address** is required for TaxOnTree execution to request data from
other servers like NCBI and UniProt. The email address is requested by those servers admin
to contact you when necessary. This could happen if you are using TaxOnTree excessively.
To run TaxOnTree without internet connection, refer to the manual in docs folder.

This will install all TaxOnTree dependencies at $HOME/.taxontree/ folder and create 
an executable named taxontree. The installation process will also attempt to install 
some third-party software that is in src folder. This includes:

* [MUSCLE](https://www.drive5.com/muscle/);
* [Clustal Omega](http://www.clustal.org/omega/);
* [Kalign](http://msa.sbc.su.se/cgi-bin/msa.cgi);
* [trimAl](http://trimal.cgenomics.org/);
* [FastTree](http://www.microbesonline.org/fasttree/).

If some of them could not be installed, you can try to install them manually.

> NOTE: Third-party software is only required when using TaxOnTree phylogenetic pipeline.
If your input is a tree in Newick format, no third-party software is necessary.

## Testing

If the installation goes well, it should create an executable called *taxontree* and display
the following message after the command `./taxontree -version`.

```
> ./taxontree -version

        TaxOnTree  Copyright (C) 2015-2017  Tetsu Sakamoto
        This program comes with ABSOLUTELY NO WARRANTY.
        This is free software, and you are welcome to redistribute it under
        certain conditions. See GNU general public license v.3 for details.

TaxOnTree v.1.10.1
```

A sample Newick file is also provided for test in *sample* folder. Try the following command:

```bash
> ./taxontree -treefile sample/test.nwk -queryid 544509544
```

This should generate a file called *test_seq_tree.nex*. Open this file on **FigTree**.

For more details on TaxOnTree command line usage, type the command `./taxontree -man` or 
refer to the manual in docs folder.

## Contact

If you have troubles installing TaxOnTree or suggestions to improve our work, please contact
us by the following email address:

* tetsufmbio@gmail.com (Tetsu Sakamoto)
* miguel@ufmg.br (J. Miguel Ortega)

_**Laboratório de Biodados**  
Instituto de Ciências Biológicas (ICB)  
Universidade Federal de Minas Gerais (UFMG)  
Belo Horizonte - Minas Gerais - BRAZIL  
Zip code: 31270-010_
