# TaxOnTree: Including taxonomic information in phylogenetic trees

*Sakamoto T.* and *J. M. Ortega*

[TaxOnTree](http://biodados.icb.ufmg.br/taxontree) is a bioinformatics
tool that embeds taxonomic information from [NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/taxonomy)
 into phylogenetic trees. TaxOnTree generates trees that allow users to 
easily access the taxonomic information of all entities comprising a tree. 
This could be performed either by colorizing the tree according to a 
taxonomic data or by adding/changing labels to evidence a taxonomic 
data on the tips, branches or nodes.

## Prerequisites

* Unix Platform;

  TaxOnTree was tested on Ubuntu, CentOS and MacOS, but it should work on
  any Unix platforms.

* Perl;

  Almost all Unix platforms have Perl 5 installed. To verify that, type perl -v 
  inside a command shell. If not, follow the instructions on [Perl website]
  (https://www.perl.org/get.html) for its installation.

* Internet connection;

  This is required to allow TaxOnTree to retrieve sequence and taxonomic information
  via REST request from NCBI or Uniprot servers.  

* [OpenSSL](https://www.openssl.org/);

  [OpenSSL](https://www.openssl.org/) package is required by TaxOnTree to communicate 
  with NCBI server which uses HTTPS communication protocol. This can be installed using 
  the installation tool of your Unix distribution (*sudo apt-get install libssl-dev* for 
  Debian or *sudo yum install openssl-dev* for RPM based distribution).

* [FigTree](http://tree.bio.ed.ac.uk/software/figtree/).

  A free graphical phylogenetic trees viewer developed in Java by Andrew Rambaut group. 
  TaxOnTree output is made to be visualized in this software. There are versions for MacOS, 
  Linux and Windows. Pick the one that is more convenient for you.

## Installation

```bash
> git clone https://github.com/tetsufmbio/taxontree.git
> cd taxontree
> ./install.sh  # here you'll be asked for your email address and
                # if you want to configure TaxOnTree to access a local MySQL.
                # MySQL configuration can be done lately.
```

> NOTE: A **valid email address** is required for TaxOnTree execution to request data from
other servers like NCBI and UniProt. The email address is a way for the admin of those
servers to contact with you when necessary. This could happen if you are using 
TaxOnTree excessively. To run TaxOnTree without internet connection, refer to the
manual in docs folder.

This will install all TaxOnTree dependencies at $HOME/.taxontree/ folder. and create 
an executable named taxontree. The installation process will also attempt to install 
some third-party software that are in src folder. This includes:

* [MUSCLE]();
* [Clustal Omega]();
* [Kalign]();
* [trimAl]();
* [FastTree]().

If the installation goes well, it should create an executable called *taxontree* and display
the following message after the command *./taxontree -version*.

```
> ./taxontree

        TaxOnTree  Copyright (C) 2015-2017  Tetsu Sakamoto
        This program comes with ABSOLUTELY NO WARRANTY.
        This is free software, and you are welcome to redistribute it under
        certain conditions. See GNU general public license v.3 for details.

TaxOnTree v.1.10
```

For more details, please refer to the manual in docs folder.

## Contact

If you have troubles or suggestions to improve our work, please contact us by the following email address:

* tetsufmbio@gmail.com (Tetsu Sakamoto)
* miguel@ufmg.br (J. Miguel Ortega)

_**Laboratório de Biodados**  
Instituto de Ciências Biológicas (ICB)  
Universidade Federal de Minas Gerais (UFMG)  
Belo Horizonte - Minas Gerais - BRAZIL  
Zip code: 31270-010_
