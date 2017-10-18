# TaxOnTree: Including taxonomic information in phylogenetic trees

*Sakamoto T.* and *J. M. Ortega*

## About this document

## Determining the Lowest Common Ancestor (LCA)

LCA of two or more organisms represents the most recent ancestor that all organisms in the set have in common. Using phylogenetic methods, it is possible to estimate the date when an ancestor population has split apart and initiated the speciation process, but we could also take advantage of a hierarchical classification of species to verify how far the common ancestor of two or more species is. TaxOnTree uses this hierarchical classification to determine the LCA between the organisms of query and subjects proteins. The hierarchical classification used by TaxOnTree is taken from NCBI Taxonomy database. A short taxonomic lineage scheme from NCBI Taxonomy is represented in the **Figure S1**. Each species has a taxonomic lineage divided in several taxonomic ranks, like family, order, class, etc. To determine the LCA between two species we compare their taxonomic lineage and look for the lowest taxonomic rank that both species share a common taxon. For example, LCA between human and mouse is superorder (Euarchontoglires), while the LCA between human and frog is subphylum (Craniata). This simple comparison gives us information that LCA between human and mouse is more recent than LCA between human and frog. 

## Taxonomic lineages and ranks

TaxOnTree also retrieves the taxonomic lineage of each taxon comprising the phylogenetic tree and uses this information to color the tree according to a taxonomic rank (See Coloring branches by a taxonomic rank). By using this resource, users can rapidly identify, for instance, the different families comprising the phylogenetic tree. However, two issues have to be considered whenever we use the taxonomic rank information from NCBI Taxonomy:

* Some taxonomic ranks are absent in a taxonomic lineage. For example, in the human lineage, there is no taxon for subclass, superclass, and subphylum (**Figure S2A**);
* Some taxa found in a taxonomic lineage do not have a taxonomic rank. These taxa arereferred as “no rank”. For example, in the human lineage, Theria, Eutheria, Boroeutheria and others are taxa without rank (**Figure S2A**).

To handle these issues, we opted in using the Taxallnomy, a taxonomic database which provides a taxonomic lineage with all ranks for all taxa comprising the NCBI Taxonomy (http://biodados.icb.ufmg.br/taxallnomy). Taxallnomy provides a balanced version of the taxonomic tree from NCBI Taxonomy in which each hierarchical level corresponds to a taxonomic rank. **Figure S2B** shows the human taxonomic lineage retrieved from Taxallnomy database. Ranks that are originally missing in the human taxonomic lineage are filled by this data. 

<img src="/img/taxontree_taxsimple.png" width=700px/>

**Figure S2**: Human taxonomic lineage from (A) NCBI Taxonomy and from (B) Taxallnomy. Taxa with a taxonomic rank assigned are in blue and taxa exclusive from Taxallnomy are in red.

## Opening and exploring the tree generated by TaxOnTree

After running TaxOnTree from web (http://biodados.icb.ufmg.br/taxontree/) or from command line (https://sourceforge.net/projects/taxontree/), TaxOnTree will generate a Nexus file structured to use some of FigTree resources. FigTree is a free graphical viewer of phylogenetic trees developed in Java by Andrew Rambaut group. In its website (http://tree.bio.ed.ac.uk/software/figtree/) there are versions for Mac, UNIX and Windows. So, once you have the Nexus file, just download FigTree and open the Nexus file in it. In this manual, we will use a tree sample available in TaxOnTree website.

After opening the Nexus file in FigTree, you will see your phylogenetic tree with the branches colored according to the LCA (Lowest Common Ancestor) between the query species (in red) and the other species in the tree (**Figure S3**) according to the legend. In some cases, some taxon names in the legend are followed by an asterisk. This indicates that there is no organism in the tree that has this taxon as the LCA with the query organism.

## Coloring branches by a taxonomic rank

You can also color the tree according to some taxonomic rank. Take the following steps:

1. In the FigTree side menu, go to Appearance;
1.	Click on “Colour by”, and choose a taxonomic rank to be used to color the branches. By choosing “12-family”, for example (Figure S4), the tree will be colored according to the family rank. You can setup the branch colors by clicking in Colours;
1.	Branch color will change immediately. To make the color legend concordant to the branch color, go to Legend in the FigTree side menu and, in Attribute, set the same taxonomic rank that you selected to color the tree (Figure S5).


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
