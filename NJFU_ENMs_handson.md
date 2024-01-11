# ENMs in R hands-on practical session
Yucheol Shin 
Feb dd 2024

## 1. Set up the working directory


## 2. Load the packages
The [terra] and [raster] packages are for raster data handling in R, dplyr is for dataframe manipulation and filtering, SDMtune is used for core model fitting and predictions, 
ENMeval is used to generate spatial blocks, and extrafont, rasterVis and ggplot2 packages are used for plotting model outputs in R.

```r
library(terra)
library(raster)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(extrafont)
library(rasterVis)
library(ggplot2)
```
