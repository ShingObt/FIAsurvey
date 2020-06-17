# Forest inventory creation Pulmas, CA

## Overview of the project
I retrieved the IFA field plot data in Pulmas county, CA. The workflow is applicable to other states in CA.

## Original data
The original data is downloaded from FIA DataMart. SQLite3 State databases for the state of California is used.  

https://apps.fs.usda.gov/fia/datamart/datamart.html

As the original data exceeded the upload size limit of Github, I provide the link to the file on my Google Drive.

https://drive.google.com/open?id=1lFP1H1lEspKCZJIw-iZ_omxAiJAVnitZ

 I referred to the FIA documentation(I call it as the FIA document from here) to acquire the detailed information about the variables in FIA.

 _The Forest Inventory and Analysis Database: Database Description and User Guide for Phase 2 (version 8.0)_

The plot design of our area of interest is different from national standard for the plots measured in 1994.
According to the FIA document, 
> Five 30.5 BAF points for trees >=6.9 inches and <35.4 inches d.b.h.; five
55.8-foot fixed-radius plots for trees >=35.4 inches d.b.h.; and five
10.8-foot fixed-radius plots for seedlings and saplings <6.9 inches d.b.h.
Point and plot centers are coincident. Conditions are mapped. (I-5)

This mean that the size of the plot is different based on _"the per-acre expansion factor is determined by the diameter of the tree, the basal area factor (BAF), and the number of points used in the plot design."_

Each tree has different expansion factor. 

National standard plot design is as follow. Except 1994, all the plots are measured based on this protocol.

> National plot design consists of four 24-foot fixed-radius subplots for
trees 5 inches d.b.h., and four 6.8-foot fixed-radius microplots for
seedlings and trees 1 and <5 inches d.b.h. Subplot 1 is the center plot,
and subplots 2, 3, and 4 are located 120.0 feet, horizontal, at azimuths
of 360, 120, and 240, respectively. The microplot center is 12 feet east
of the subplot center. Four 58.9-foot fixed-radius macroplots are
optional. A plot may sample more than one condition. When multiple
conditions are encountered, condition boundaries are delineated
(mapped). (I-1)


## SQL works
"CountyInv" contains the sql code to query the data from the original data. Only the sample plot data measured in Pulmas county are queried. 

https://www.fia.fs.fed.us/library/database-documentation/current/ver80/FIADB%20User%20Guide%20P2_8-0.pdf

FIPS code for CA is retrieved from

https://www.weather.gov/hnx/cafips

### Volume per acre calculation
>Net cubic-foot volume. For timber species (trees where the diameter is measured at
breast height d.b.h.), this is the net volume of wood in the central stem of a sample tree
5.0 inches d.b.h., from a 1-foot stump to a minimum 4-inch top diameter, or to where the
central stem breaks into limbs all of which are <4.0 inches in diameter. For woodland
species (woodland species can be identified by REF_SPECIES.WOODLAND = X),
VOLCFNET is the net volume of wood and bark from the d.r.c. measurement point(s) to a 1½-inch top diameter; includes branches that are at least 1½ inches in diameter along
the length of the branch. This is a per tree value and must be multiplied by TPA_UNADJ to
obtain per acre information. This attribute is blank (null) for trees with DIA <5.0 inches.
All trees measured after 1998 with DIA 5.0 inches (including standing dead trees) will
have entries in this field. Does not include rotten, missing, and form cull (volume loss due
to rotten, missing, and form cull defect has been deducted).(3-20)


"FIAData_plumasCA.csv" is the queried table. Individual tree data is included in this data table. 

### Species code
The full list of the tree species group codes is available in the Appendix E of the FIA document.

### Owner group code
Please refer to page 2-36 of the FIA document.

### Inventory Year
Although I did not set any filter when I retrieve the original data from FIA DataMart, each plot has single inventory year for all the plot. Therefore, I left the inventory year as it is.

## Data aggregation
Data aggregation is done in R. "DataAggregation.R" is used for the aggregation of the individual tree data into the plot-level data. The variables taken from the FIA sample plot data was summarized for each plot ID that is unique to the plots. 

The outcome of the aggregation is written out to the "FIAData_plumasCA_plot.csv". Followings are the description of the columns.

The volume per acre is computed by (number of trees) x (volume per tree)


# Dominant tree height and dominant tree age
The dominant tree height is the tree height of the highest trees among the primary species within a plot. For 4 plots in Plumas county, dominant tree height was unavailable as the trees of the primary species do not have any height measurement as they are smaller than 5 inch in terms of the diameter.  
For these plots, Woodland hardwoods is the primary species.
Dominant tree age is the breast height age of the highest tree among the primary species. FIA data does not provide the breast height age for  68.5% of the trees. Therefore, dominant tree age is estimated from the given height equations presented in _”SITE INDEX SYSTEMS FOR MAJOR
YOUNG-GROWTH FOREST AND WOODLAND SPECIES IN NORTHERN CALIFORNIA”(
https://www.fire.ca.gov/media/3789/forestryreport4.pdf)_ 
The solution of the height equations for the age is summarized in "FIA_project_solutions.pdf".





- lastInvYr: The last year that inventory for the plot was created/updated.
- primarySpecies: Primary species group name. I took the mode of the species code within a plot.
- secondarySpecies: Secondary species group name.
- owner: Ownership description.
- volPerAcre: cubic feet per acre.
- dominantTreeHeight: The highest tree's height in feet. 
- dominantTreeAge: the age of the highest tree in a plot
- SI: Site index.

## Area and volume in the county
Area and volume in the county is retrieved from _evalidator_. 

Although I retrieved only the total area and volume, by using 
_evalidator_, it is possible to get the area and volume by stand class, species group,..,etc. 

These figures also can be calculated from plot data but I haven’t done that. 
