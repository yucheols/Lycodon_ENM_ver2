# ENMs in R hands-on practical session
#### By Yucheol Shin (Department of Biological Sciences, Kangwon National University, Korea)
Feb dd 2024
@ Laboratory of Animal Behaviour and Conservation, Nanjing Forestry University

In the paper, the modeling was done at two different spatial scales ("Broad" and "Narrow"). In this hands-on session, we will focus on the broad-scale modeling to illustrate the basic organization of the ENM workflow.

## 1. Before we start: A (very) basic workflow of presence-background ENMs
Presence-background ENM algorithms require the presence and background datasets, as well as environmental predictors, as inputs. Probably the most popular algorithm out there is MaxEnt, and it is the algorithm used here as well. Below is a very basic illustration of how the presence-background ENMs work. We will keep this workflow and its key steps in mind as we navigate the codes.  

[PUT ILLUSTRATION HERE]

## 2. Set up the working directory
Before diving in, we need to setup an environment to run the codes.

1) First, make sure to have both R and RStudio installed in your laptop.
2) Open RStudio and navigate to "File > New Project"
3) Select "New Directory > New Project"
4) Set the project name to "NJFU_ENMs_Workshop_2024"
5) Now you will be working within this directory for this workshop. 


## 3. Load packages and prepare data
The terra and raster packages are for raster data handling in R, dplyr is for data frame manipulation and filtering, SDMtune is used for core model fitting and predictions, 
ENMeval is used to generate spatial blocks, and extrafont, rasterVis and ggplot2 packages are used for plotting model outputs in R.

** Note: I used the raster package as a matter of personal preference while writing this code. But now it is recommended to use the terra package instead.

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

Now, we are ready to load and prepare the environmrntal predictors. But before we do that, lets create the files to put the environmental data.
We can do that by simply running dir.create(), like so.

```r
dir.create('climate')
dir.create('topo')
dir.create('land')
```
In the "climate" directory we will put climate rasters, in the "topo" directory we will put topographical variables (e.g. slope, elevation), and in the "land" directory we will put land cover/vegetation variables. 


```r
#####  PART 1 ::: environmental data  #####
# set clipping extent
ext <- c(100, 132, 18, 42)

# clim
clim <- raster::stack(list.files(path = 'E:/env layers/worldclim', pattern = '.tif$', full.names = T))
clim <- raster::crop(clim, ext)
plot(clim[[1]])

names(clim) = c('bio1','bio10','bio11','bio12','bio13','bio14','bio15',
                'bio16','bio17','bio18','bio19','bio2','bio3','bio4',
                'bio5','bio6','bio7','bio8','bio9')

# elev 
elev <- raster('E:/env layers/elev_worldclim/wc2.1_30s_elev.tif')
elev <- raster::crop(elev, ext)
names(elev) = 'elev'

# slope == created from the elev layer cropped above
slope <- raster('slope/slope.tif')
plot(slope)

# land cover
land <- raster::stack(list.files(path = 'E:/env layers/land cover', pattern = '.tif', full.names = T))
land <- raster::stack(subset(land, c('cultivated', 'herb', 'shrubs', 'forest_merged')))
land <- raster::crop(land, ext)
names(land) = c('cultivated', 'herb', 'shrubs', 'forest')
```

## 4. Background data sampling

## 5. Variable selection

## 6. Model tuning and optimal model selection

## 7. Response curves
With SDMtune you can get a response curve for each variable using the "plotResponse()" function. But you may wish to further customize the plot for better visualization or publication. For that we can actually extract the data used to build response curves and customize the plot using ggplot2.

To pull out the data though, we need to make a little work around because "plotResponse()" will automatically print out a finished plot. We can use this little wrapper function I've made to extract data:

```r
respDataPull <- function(model, var, type, only_presence, marginal, species_name) {
  
  plotdata.list <- list()
  
  for (i in 1:length(var)) {
    plotdata <- plotResponse(model = model, var = var[[i]], type = type, only_presence = only_presence, marginal = marginal)
    plotdata <- ggplot2::ggplot_build(plotdata)$data
    plotdata <- plotdata[[1]]
    
    plotdata <- plotdata[, c(1,2)]
    plotdata$species <- species_name
    plotdata$var <- var[[i]]
    
    plotdata.list[[i]] <- plotdata
  }
  plotdata.df <- dplyr::bind_rows(plotdata.list)
  return(plotdata.df)
}

# pull data
broad.resp.data <- respDataPull(model = tune@models[[6]], 
                                var = c('bio1', 'bio12', 'bio14', 'bio3', 'bio5', 'cultivated', 'herb', 'shrub', 'slope'),
                                type = 'cloglog', only_presence = T, marginal = T, species_name = 'Lycodon')

print(broad.resp.data)
```

Basically, what this function does, is that it loops over the number of input variables, extract plot data, and merge them into a data frame for customization in ggplot2.

## 8. Model extrapolation
This is the part that was not done in the paper. But here we will project the fitted model to the environmental conditions of California. This is an ecologically meaningless exercise because A) L. rufozonatus is very unlikely to actually arrive in California, and B) environmental conditions of California is very different from that of East and Southeast Asia. But we will try this nonetheless to illustrate the risk of model transfer.

