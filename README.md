# TaxOnTree: Including taxonomic information in phylogenetic trees

*Sakamoto T.* and *J. M. Ortega*

## About TaxOnTree and this document

[TaxOnTree](http://biodados.icb.ufmg.br/taxontree) is a bioinformatics tool that embeds taxonomic information from [NCBI Taxonomy](https://www.ncbi.nlm.nih.gov/taxonomy) into phylogenetic trees. Trees generated by TaxOnTree allow users to easily access the taxonomic information of the entities comprising their trees. This could be performed either by colorizing the tree branches according to a taxonomic rank or by changing or adding labels to evidence a taxonomic data on the tips, branches or nodes.

This document is a guide for users to explore all functions and resources that TaxOnTree could provide. 

## Opening and exploring the tree generated by TaxOnTree

After running TaxOnTree from [web interface](http://biodados.icb.ufmg.br/taxontree/) or from [command line](https://sourceforge.net/projects/taxontree/), TaxOnTree will generate a **Nexus file** structured to be opened in [FigTree](http://tree.bio.ed.ac.uk/software/figtree/) software. FigTree is a free graphical viewer of phylogenetic trees developed in Java by Andrew Rambaut group. There are versions for Mac, UNIX and Windows. So, once you have the Nexus file, just download FigTree and open the Nexus file in it. In this manual, we will use a [tree sample]() available in TaxOnTree website.

### Exploring the taxonomic relationship by LCA

After opening the Nexus file in FigTree, you will see your phylogenetic tree with the branches colored according to the LCA (Lowest Common Ancestor) between the query species (in red) and the other species in the tree (**Figure S3**). LCA of two or more organisms represents the most recent ancestor that all organisms in the set have in common (see **Box 1** for mor details). There will have also a legend for the colors used in the tree. 

> **Note**: Some taxon names in the legend are followed by an asterisk. This indicates that there is no organism in the tree that has this taxon as the LCA with the query organism.

> **Box 1: Determining the LCA**  
> To accomplish this task, TaxOnTree takes advantage of the hierarchical structure from NCBI Taxonomy. To illustrate this, a short taxonomic lineages of human, dog and frog from NCBI Taxonomy are represented in the figure below. Walking through the human taxonomic lineage, beginning from the root (level 0), we could observe that several taxa comprising the human lineage are shared with the other two. However, in different point of the human lineage, frog and dog lineages take different route. The frog lineage diverge from the human lineage after the level 17 (Amniota), while, in dog lineage, this occur at level 21 (Boreoeutheria). Those taxa, which are the last taxa shared between the lineages in comparison, is what we denominate as LCA. By determining and comparing the LCA level between the species in comparison, we could determine how related those species are. This, for instance, gives enough information to claim that human is more closely related to dog than to frog.  
> <img src="/img/lca_frog.png" width=650px/>

### Exploring the taxonomic diversity by ranks

Did you ever asked yourself how many distinct class, order or family are in your tree? You can answer this in a few seconds if you have a tree generated by TaxOnTree in hand. TaxOnTree also embeds in the tree the taxonomic lineage data of all taxa comprising the phylogenetic tree, allowing you to colorize the tree according to a taxonomic rank. Take the following steps in the FigTree software and, if you are curious about how missing ranks in some lineages are filled in TaxOnTree, check the **Box 2**.

1. In the FigTree side menu, go to *Appearance*;
1.	Click on *Colour by*, and choose a taxonomic rank to be used to color the branches. By choosing *12-family*, for example (**Figure S4**), the tree will be colored according to the family rank. You can setup the branch colors by clicking in *Colours*;
1.	Branch color will change immediately. To make the color legend concordant to the branch color, go to *Legend* in the FigTree side menu and, in *Attribute*, set the same taxonomic rank that you selected in the previous step (**Figure S5**).

> **Box 2: Missing ranks and Taxallnomy database**  
> Whenever we are querying for a taxonomic rank from NCBI Taxonomy, two issues have to be considered :
> * Some taxonomic ranks are absent in a taxonomic lineage, e.g. there is no taxon for subclass, superclass, and subphylum in the human lineage (**Figure S2A**);
> * Some taxa found in a taxonomic lineage do not have a taxonomic rank. These taxa are referred as *no rank*, e.g. Theria, Eutheria, Boroeutheria and others are taxa without rank in the human lineage (**Figure S2A**).  
>  
> To handle these issues, we opted in using [Taxallnomy](http://biodados.icb.ufmg.br/taxallnomy), a taxonomic database which provides a taxonomic lineage with all ranks for all taxa comprising the NCBI Taxonomy. Taxallnomy provides a balanced version of the taxonomic tree from NCBI Taxonomy which its hierarchical levels are correspondent to the taxonomic ranks. **Figure S2B** shows the human taxonomic lineage retrieved from Taxallnomy database. Ranks that are originally missing in the human taxonomic lineage are filled by this data.  
> <img src="/img/taxontree_taxsimple.png" width=700px/>
>  
> **Figure S2**: Human taxonomic lineage from (A) NCBI Taxonomy and from (B) Taxallnomy. Taxa with a taxonomic rank assigned are in blue and taxa exclusive from Taxallnomy are in red.

## Other features

### Changing the labels of the tree

The tip labels in the tree can also be changed to evidence the taxon in which taxonomic rank 

### Evidencing duplication nodes

### Check branch statistic support value

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

*This text will be italic*
_This will also be italic_

**This text will be bold**
__This will also be bold__

_You **can** combine them_

* Item 1
* Item 2
  * Item 2a
  * Item 2b
  
1. Item 1
1. Item 2
1. Item 3
   1. Item 3a
   1. Item 3b
   
![GitHub Logo](/images/logo.png)
Format: ![Alt Text](url)

http://github.com - automatic!
[GitHub](http://github.com)

As Kanye West said:

> We're living the future so
> the present is our past.

I think you should use an
`<addr>` element here instead.

```javascript
function fancyAlert(arg) {
  if(arg) {
    $.facebox({div:'#foo'})
  }
}
```
