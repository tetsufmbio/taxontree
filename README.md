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
* Perl;
* Internet connection;
* [OpenSSL](https://www.openssl.org/);
* [FigTree](http://tree.bio.ed.ac.uk/software/figtree/);

## Installation

```bash
> git clone https://github.com/tetsufmbio/taxontree.git
> cd taxontree
> ./install.sh  # here you'll be asked for your email address and
                # if you want to configure TaxOnTree to access a local MySQL
```

This will install all TaxOnTree dependencies at $HOME/.taxontree/ folder. and create 
an executable named taxontree. This will also install some third-party software that 
are in src folder. This includes:

* MUSCLE;
* Clustal Omega;
* Kalign;
* trimAl;
* FastTree.

If all goes well, it should display the following message after the command ./taxontree.

```
> ./taxontree

        TaxOnTree  Copyright (C) 2015-2017  Tetsu Sakamoto
        This program comes with ABSOLUTELY NO WARRANTY.
        This is free software, and you are welcome to redistribute it under
        certain conditions. See GNU general public license v.3 for details.

ERROR: No input was provided.
Usage:
    ./taxontree -singleID <sequence_ID>
...
```

For more details, please refer to the manual in docs folder.

> NOTE: A valid email address is required for TaxOnTree execution to request data from
other servers like NCBI and UniProt. The email address is a way to the admin of those
servers to communicate with you when necessary. This could happen if you are using 
TaxOnTree excessively. To run TaxOnTree without internet connection, refer to the
manual in docs folder.

## Contact

If you have troubles or suggestions to improve our work, please contact us by the following email address:

* tetsufmbio@gmail.com (Tetsu Sakamoto)
* miguel@ufmg.br (J. Miguel Ortega)

_**Laboratório de Biodados**  
Instituto de Ciências Biológicas (ICB)  
Universidade Federal de Minas Gerais (UFMG)  
Belo Horizonte - Minas Gerais - BRAZIL  
Zip code: 31270-010_
