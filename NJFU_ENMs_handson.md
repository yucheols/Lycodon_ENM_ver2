# ENMs in R hands-on practical session
#### Yucheol Shin 
Feb dd 2024
@ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University

In the paper, the modeling was done at two different spatial scales ("Broad" and "Narrow"). In this hands-on session, we will focus on the broad-scale modeling to illustrate the basic organization of the ENM workflow.

## 1. Before we start: A basic workflow of ENMs

## 2. Set up the working directory


## 3. Load the packages
The terra and raster packages are for raster data handling in R, dplyr is for data frame manipulation and filtering, SDMtune is used for core model fitting and predictions, 
ENMeval is used to generate spatial blocks, and extrafont, rasterVis and ggplot2 packages are used for plotting model outputs in R.

```r
## load libraries
library(terra)
library(raster)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(extrafont)
library(rasterVis)
library(ggplot2)
```

Also, prepare some basic data. 
