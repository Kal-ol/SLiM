Kallol Mozumdar, Rushworth Lab, Biology Department, Utah State University (kallol.mozumdar@usu.edu)

This repository contains the primary scripts for my models for my Master's Thesis Project. 

///script version for Terminal runs on cluster have the prefix CHPC////

We used the population genetic framework SLiM to construct individual-based models of parent-hybrid coexistence across a range of gene flow and recombination rates, subject to BDMIs and intraspecific and interspecific competition. We began with a baseline model of annual organisms that experience bidirectional gene flow and subsequently undergo outcrossing. Next, inspired by the perennial wildflower Boechera, in which hybrids are asexual and result from unidirectional gene flow, we varied life history strategies (from annual to perennial), gene flow direction (from bidirectional to unidirectional), and hybrid reproductive mode (from outcrossing to self-fertilization and asexuality).

Annual
- non overlapping generations
- 3-pop nonWF hybrid model
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are sexual and there is backcrossing.
- any mating between hybrid and parents will produce more hybrids


Perennial
- short lived overlapping generation
- 3-pop nonWF hybrid model
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are sexual and there is backcrossing.
- any mating between hybrid and parents will produce more hybrids

Selfing_Annual
- non overlapping generations
- selfing hybrids
- 3-pop nonWF hybrid model
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are selfing 
- any mating between hybrid and parents will produce more hybrids

Selfing_Perennial
- short lived overlapping generations
- selfing hybrids
- 3-pop nonWF hybrid model
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are selfing 
- any mating between hybrid and parents will produce more hybrids

Apomixis_Annual
- non overlapping generations
- apomixis hybrids
- 3-pop nonWF hybrid model
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are asexual
- any mating between hybrid and parents will produce more hybrids

Apomixis_Perennial
- short lived overlapping generations
- apomixis hybrids
- 3-pop nonWF hybrid model
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are asexual
- any mating between hybrid and parents will produce more hybrids

Selfing_Annual
- non overlapping generations
- 3-pop nonWF hybrid model
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are sexual and there is backcrossing
- Only P2 X P1 produces hybrids
- any mating between hybrid and parents will produce more hybrids

Boechera
- short lived overlapping generations
- apomixis hybrids
- 3-pop nonWF hybrid model
- unidirectional gene flow
- multi-locus BDMI 
- Ancestry markers - lineage specific fixed neutral alleles
- Admixture index is measured based on distribution of ancestral markers
- Density dependnent Offspring production
- Assortative mating based on Admixture index
- BDMI based survival
- Hybrid offspring flagged in p1/p2 and migrated to p3
- p3 are asexual
- any mating between hybrid and parents will produce more hybrids
