#######  Lycodon SDM re-run for Herpetologica MS revision round 1
## prevent encoding error
Sys.getlocale()
Sys.setlocale("LC_CTYPE", ".1251")
Sys.getlocale()

## load libraries
library(terra)
library(raster)
library(dplyr)
library(SDMtune)
library(ENMeval)
library(extrafont)
library(rasterVis)
library(ggplot2)

## jeju poly
jeju <- rgdal::readOGR('E:/worldclim/NEA shapefiles/Jeju_do.shp')

## set text font here for use in ggplot2
windowsFonts(a = windowsFont(family = 'Times New Roman'))

####################################################  Broad scale model
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

# stack all
envs <- raster::stack(clim, elev, slope, land) 

# export 
for (i in 1:nlayers(envs)) {
  r <- envs[[i]]
  layer <- paste0('envs/', names(envs)[[i]], '.bil')
  writeRaster(r, filename = layer, overwrite = T)
}

# shortcut
envs <- raster::stack(list.files(path = 'envs', pattern = '.bil$', full.names = T))
plot(envs[[1]])

#####  PART 2 ::: occurrence points & thinning  #####
# import occs
occs <- read.csv('occs/Lycodon_rufozonatus.csv') %>% dplyr::select(4,5,6)
colnames(occs) = c('species', 'long', 'lat')
head(occs)

# thin occurrence points
spThin::thin(loc.data = occs, lat.col = 'lat', long.col = 'long', spec.col = 'species', thin.par = 15,
             reps = 1, locs.thinned.list.return = F, write.files = T, max.files = 1, out.dir = 'occs',
             out.base = 'Lyco_15km', write.log.file = F, verbose = T)

# import thinned
occs_thin <- read.csv('occs/Lyco_15km_thin1.csv')
head(occs_thin)


#####  PART 3 ::: Background point sampling  #####
# import target group points
targ.pts <- read.csv('E:/Lycodon in Jeju/Lyco_Jeju/SDM/targ.bg/target_group_pts.csv')
targ.pts <- thinData(coords = targ.pts[, c(2,3)], env = terra::rast(envs), x = 'x', y = 'y', progress = T)
colnames(targ.pts) = colnames(occs[, c(2,3)])
head(targ.pts)

# generate bias layer
targ.ras <- rasterize(targ.pts, envs, 1)
plot(targ.ras)

targ.pres <- which(values(targ.ras) == 1)
targ.pres.locs <- coordinates(targ.ras)[targ.pres, ]

targ.dens <- MASS::kde2d(targ.pres.locs[,1], targ.pres.locs[,2], 
                         n = c(nrow(targ.ras), ncol(targ.ras)),
                         lims = c(extent(envs)[1], extent(envs)[2], extent(envs)[3], extent(envs)[4]))

targ.dens.ras <- raster(targ.dens, envs)
targ.dens.ras2 <- resample(targ.dens.ras, envs)
plot(targ.dens.ras2)

bias.layer <- raster::mask(targ.dens.ras2, envs[[1]])
plot(bias.layer)

# sample 10,000 bias corrected bg
length(which(!is.na(values(subset(envs, 1)))))

bg <- xyFromCell(bias.layer, sample(which(!is.na(values(subset(envs, 1)))), 10000,
                                    prob = values(bias.layer)[!is.na(values(subset(envs, 1)))])) %>% as.data.frame()

colnames(bg) = colnames(occs[, c(2,3)])
head(bg)

plot(envs[[1]])
points(bg)

# shortcut
bg <- read.csv('bg/targ.bg.csv') %>% dplyr::select(2,3)
head(bg)


#####  PART 4 ::: select environmental variables  #####
ntbox::run_ntbox()

## removed Pearson's |r| > 0.7
## selected vars == bio1 bio3 bio5 bio12 bio14 cultivated herb shrubs slope 
envs_subs <- raster::stack(subset(envs, c('bio1','bio3','bio5','bio12','bio14','cultivated','herb','shrubs','slope')))
print(envs_subs)

## create shortcut
for (i in 1:nlayers(envs_subs)) {
  r <- envs_subs[[i]]
  layer <- paste0('envs_subs/bil/', names(envs_subs)[[i]], '.bil')
  writeRaster(r, filename = layer, overwrite = T)
}

# import thru shortcut
envs_subs <- raster::stack(list.files(path = 'envs_subs', pattern = '.tif', full.names = T))
names(envs_subs) = c('bio1', 'bio12', 'bio14', 'bio3', 'bio5', 'cultivated', 'herb', 'shrub', 'slope')
print(envs_subs)
plot(envs_subs[[1]])


#####  PART 5 ::: model parameter tuning  #####
# prep SDMtune data
swd <- prepareSWD(species = 'Lyco', env = terra::rast(envs_subs), p = occs_thin[, c(2,3)], a = bg, verbose = T)

# get spatial block
spat.block1 <- ENMeval::get.block(occs = swd@coords[swd@pa == 1, ], bg = swd@coords[swd@pa == 0, ], orientation = 'lat_lon')

# train a Maxent model
base.mod <- train(method = 'Maxent', data = swd, folds = spat.block1, iter = 5000)

# tune models
tune <- gridSearch(model = base.mod,
                   hypers = list(fc = c('l', 'q', 'h', 'p', 'lq', 'lp', 'qh', 'qp', 'hp', 'lqh', 'lqp', 'lqhp', 'lqhpt'),
                                 reg = seq(0.5, 5, by = 0.5)),
                   metric = 'auc',
                   save_models = T,
                   interactive = F,
                   progress = T)

# tuning results
print(tune@results)

## export model tuning results
write.csv(tune@results, 'model_out/tuning_results_broad_SDMtune.csv')

# filter out optimal models == LP 0.5
tune@results %>% dplyr::filter(test_AUC == max(test_AUC))

# evaluate final model
auc(model = tune@models[[6]], test = T)
tss(model = tune@models[[6]], test = T)

# look at prediction
pred.b <- SDMtune::predict(object = tune@models[[6]], data = terra::rast(envs_subs), 
                           type = 'cloglog', clamp = T, progress = T) %>% raster()

plot(pred.b)

# crop to Jeju
pred.b.jj <- raster::crop(pred.b, extent(jeju))
plot(pred.b.jj)


#####  PART 6 ::: make binary maps  #####
## function
sdm_thresholds <- function(sdm, occs, type = 'p10', binary = F) {
  occPredVals <- raster::extract(sdm, occs)
  if(type == 'mtp'){
    thresh <- min(na.omit(occPredVals))
  } else if(type == 'p10'){
    if(length(occPredVals) < 10){
      p10 <- floor(length(occPredVals) * 0.9)
    } else {
      p10 <- ceiling(length(occPredVals) * 0.9)
    }
    thresh <- rev(sort(occPredVals))[p10]
  }
  sdm_thresh <- sdm
  sdm_thresh[sdm_thresh < thresh] <- NA
  if(binary){
    sdm_thresh[sdm_thresh >= thresh] <- 1
  }
  return(sdm_thresh)
}

## calc thresh
thresh <- sdm_thresholds(sdm = pred.b, occs = occs_thin[, c(2,3)], type = 'p10')
print(thresh)

## make binary
broad.bin <- ecospat::ecospat.binary.model(Pred = pred.b, Threshold = minValue(thresh)) 
plot(broad.bin)

## clip out Jeju
broad.bin.jj <- raster::crop(broad.bin, extent(jeju))
plot(broad.bin.jj)


#####  PART 7 ::: Response curves & variable importance  #####
# variable contribution
varImp1 <- maxentVarImp(tune@models[[6]])
write.csv(varImp1, 'model_out/VarImp_broad.csv')

###   pull response curve data for customization
#     build a function to pull response curve data from the SDMtune function [ plotResponse ]
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
  plotdata.df <<- dplyr::bind_rows(plotdata.list) 
}

# pull data
broad.resp.data <- respDataPull(model = tune@models[[6]], 
                                var = c('bio1', 'bio12', 'bio14', 'bio3', 'bio5', 'cultivated', 'herb', 'shrub', 'slope'),
                                type = 'cloglog', only_presence = T, marginal = T, species_name = 'Lycodon')

print(broad.resp.data)

# recode var name
broad.resp.data$var = dplyr::recode_factor(broad.resp.data$var,
                                           'bio1' = 'Bio 1',
                                           'bio12' = 'Bio 12',
                                           'bio14' = 'Bio 14',
                                           'bio3' = 'Bio 3',
                                           'bio5' = 'Bio 5',
                                           'cultivated' = 'Cultivated',
                                           'herb' = 'Herbaceous',
                                           'shrub' = 'Shrub',
                                           'slope' = 'Slope')

# reorder variables
broad.resp.data$var = factor(broad.resp.data$var, 
                             levels = c('Bio 1', 'Bio 3', 'Bio 5', 'Bio 12', 'Bio 14', 'Cultivated', 'Herbaceous', 'Shrub', 'Slope'))

## plot response == W 1076 X H 767
# set text
windowsFonts(a = windowsFont(family = 'Times New Roman'))

# plot
broad.resp.data %>%
  ggplot(aes(x = x, y = y)) +
  geom_line(linewidth = 1.2, color = '#1976D2') +
  facet_wrap(~ var, scales = 'free') +
  xlab('Value') + ylab('Suitability') +
  theme_bw() + 
  theme(text = element_text(family = 'a'),
        axis.title = element_text(size = 16, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 20)),
        axis.title.y = element_text(margin = margin(r = 20)),
        axis.text = element_text(size = 12),
        strip.text = element_text(size = 14)) +
  geom_hline(yintercept = minValue(thresh), linewidth = 1.2, color = 'red', linetype = 2)


#####  PART 8 ::: plot model  #####
# plot
gplot(pred.b.jj) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = c('#2b83ba', '#abdda4', '#ffffbf', '#fdae61', '#4f05d7'),
                       na.value = 'transparent',
                       name = 'Suitability',
                       breaks = c(0.3, 0.9),
                       labels = c('Low', 'High')) +
  xlab('Longitude (°)') + ylab('Latitude (°)') +
  theme(text = element_text(family = 'a'),
        axis.title = element_text(size = 14, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 14)),
        axis.title.y = element_text(margin = margin(r = 14)),
        axis.text = element_text(size = 12),
        legend.title = element_text(size = 14, face = 'bold', margin = margin(b = 10)),
        legend.text = element_text(size = 12)) +
  geom_polygon(data = jeju, aes(x = long, y = lat, group = group),
               linewidth = 1.5, fill = 'transparent', color = 'black')

  
####################################################  Narrow scale model == select own var
## import focal area poly
focal <- rgdal::readOGR('E:/Lycodon in Jeju/Lyco_Jeju/focal_area_china/focal_area_china.shp')

#####  PART 1 ::: occs  #####
head(occs)
narrow.occs <- thinData(coords = occs[, c(2,3)], env = terra::rast(envs_subs2), x = 'long', y = 'lat', progress = T)


#####  PART 2 ::: bg  #####
# make a second bias layer
head(targ.pts)
targ.pts2 <- thinData(coords = targ.pts[, c(2,3)], env = terra::rast(envs_subs2), x = 'x', y = 'y', progress = T)

targ.ras2 <- rasterize(targ.pts2, envs_subs2, 1)
plot(targ.ras2)

targ.pres2 <- which(values(targ.ras2) == 1)
targ.pres.locs2 <- coordinates(targ.ras2)[targ.pres2, ]

targ.dens2 <- MASS::kde2d(targ.pres.locs2[,1], targ.pres.locs2[,2],
                          n = c(nrow(targ.ras2), ncol(targ.ras2)),
                          lims = c(extent(envs_subs2)[1], extent(envs_subs2)[2], 
                                   extent(envs_subs2)[3], extent(envs_subs2)[4]))

targ.dens.ras.re <- raster(targ.dens2, envs_subs2)
targ.dens.ras.re2 <- resample(targ.dens.ras.re, envs_subs2)
plot(targ.dens.ras.re2)

bias.layer2 <- raster::mask(targ.dens.ras.re2, envs_subs2[[1]])
plot(bias.layer2)

# sample bias corrected bg
length(which(!is.na(values(subset(envs_subs2, 1)))))

bg.focal <- xyFromCell(bias.layer2, sample(which(!is.na(values(subset(envs_subs2, 1)))), 10000,
                                           prob = values(bias.layer2)[!is.na(values(subset(envs_subs2, 1)))])) %>% as.data.frame()

colnames(bg.focal) = colnames(narrow.occs)
head(bg.focal)

#####  PART 3 ::: select environmental variables  #####
## dont forget to import object envs before running the code below
print(envs)

## run ntbox
ntbox::run_ntbox()

## removed Pearson's |r| > 0.7
## selected vars ==  bio1 bio9 bio12 bio15 cultivated elev herb shrubs 
envs_subs2 <- raster::stack(subset(envs, c('bio1', 'bio9', 'bio12', 'bio15', 'cultivated', 'herb', 'shrubs', 'elev')))
envs_subs2 <- raster::crop(envs_subs2, focal)
envs_subs2 <- raster::mask(envs_subs2, focal)
plot(envs_subs2[[1]])

#####  PART 4 ::: tune  #####
# prep SWD
swd2 <- prepareSWD(species = 'Lyco', env = terra::rast(envs_subs2), p = narrow.occs, a = bg.focal, verbose = T)

# get spatial block
spat.block2 <- ENMeval::get.block(occs = swd2@coords[swd2@pa == 1, ], bg = swd2@coords[swd2@pa == 0, ], orientation = 'lat_lon')

# train a Maxent model
base.mod2 <- train(method = 'Maxent', data = swd2, folds = spat.block2, iter = 5000)
varImp(base.mod2)

# tune
tune2 <- gridSearch(model = base.mod2,
                    hypers = list(fc = c('l', 'q', 'h', 'p', 'lq', 'lp', 'qh', 'qp', 'hp', 'lqh', 'lqp', 'lqhp', 'lqhpt'),
                                  reg = seq(0.5, 5, by = 0.5)),
                    metric = 'auc',
                    save_models = T,
                    interactive = F,
                    progress = T)

## tuning results
print(tune2@results)

## export model tuning results
write.csv(tune2@results, 'model_out/tuning_results_narrow_SDMtune.csv')

## filter out optimal models == P 5
tune2@results %>% dplyr::filter(test_AUC == max(test_AUC))

## evaluate final model
auc(model = tune2@models[[121]], test = T)
tss(model = tune2@models[[121]], test = T)


## look at prediction
pred.n <- SDMtune::predict(object = tune2@models[[121]], data = terra::rast(envs_subs2),
                           type = 'cloglog', clamp = T, progress = T) %>% raster()

plot(pred.n)


#####  PART 5 ::: predict to Jeju  #####
# prep layer
envs.jj <- raster::stack(subset(envs, names(envs_subs2)))
envs.jj <- raster::crop(envs.jj, extent(jeju))
plot(envs.jj[[1]])

# predict
pred.n.jj <- SDMtune::predict(object = tune2@models[[121]], data = terra::rast(envs.jj),
                              type = 'cloglog', clamp = T, progress = T) %>% raster()

plot(pred.n.jj)

#####  PART 6 ::: binary maps  #####
## calc p10
thresh2 <- sdm_thresholds(sdm = pred.n, occs = narrow.occs, type = 'p10')
print(thresh2)

## make binary
narrow.bin.jj <- ecospat::ecospat.binary.model(Pred = pred.n.jj, Threshold = minValue(thresh2))
plot(narrow.bin.jj)


#####  PART 7 ::: Response curves & variable importance  #####
# variable contribution
varImp2 <- maxentVarImp(model = tune2@models[[121]])
print(varImp2)

write.csv(varImp2, 'model_out/VarImp_narrow.csv')

###   pull response curve data for customization
narrow.resp.data <- respDataPull(model = tune2@models[[121]], 
                                 var = c('bio1', 'bio9', 'bio12', 'bio15', 'cultivated', 'elev', 'herb', 'shrubs'),
                                 type = 'cloglog', only_presence = T, marginal = T, species_name = 'Lycodon')

# recode var name
narrow.resp.data$var <- dplyr::recode_factor(narrow.resp.data$var,
                                             'bio1' = 'Bio 1',
                                             'bio9' = 'Bio 9',
                                             'bio12' = 'Bio 12',
                                             'bio15' = 'Bio 15',
                                             'cultivated' = 'Cultivated',
                                             'elev' = 'Elevation',
                                             'herb' = 'Herbaceous',
                                             'shrubs' = 'Shrub')

# reorder variables
narrow.resp.data$var = factor(narrow.resp.data$var,
                              levels = c('Bio 1', 'Bio 9', 'Bio 12', 'Bio 15', 'Cultivated', 'Herbaceous', 'Shrub', 'Elevation'))

# plot response
narrow.resp.data %>% 
  ggplot(aes(x = x, y = y)) +
  geom_line(linewidth = 1.2, color = '#1976D2') +
  facet_wrap(~ var, scales = 'free') +
  xlab('Value') + ylab('Suitability') +
  theme_bw() + 
  theme(text = element_text(family = 'a'),
        axis.title = element_text(size = 16, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 20)),
        axis.title.y = element_text(margin = margin(r = 20)),
        axis.text = element_text(size = 12),
        strip.text = element_text(size = 14)) +
  geom_hline(yintercept = minValue(thresh2), linewidth = 1.2, color = 'red', linetype = 2)
  

#####  PART 8 ::: plot maps  #####
gplot(pred.n.jj) + 
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = c('#2b83ba', '#abdda4', '#ffffbf', '#fdae61', '#4f05d7'),
                       na.value = 'transparent')

#####  PART 9 ::: calculate MESS  #####
# check occs to extract ref values from
head(narrow.occs)

# check rasterStack object for the projection range
plot(envs.jj[[1]])

# get ref val
ref.val <- raster::extract(envs_subs2, narrow.occs) %>% as.data.frame()
head(ref.val)

# get MESS == set [ full = F ] to get MESS layer only
mess <- dismo::mess(x = envs.jj, v = ref.val, full = F)
mess <- raster::mask(mess, jeju)
plot(mess)

# plot mess == W760 X H379
gplot(mess) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = rev(c('#0571b0', '#92c5de', '#f7f7f7', '#f4a582', '#ca0020')),
                       na.value = 'transparent',
                       name = 'MESS',
                       breaks = c(0, -125),
                       labels = c('Low', 'High')) +
  xlab('Longitude (°)') + ylab('Latitude (°)') +
  theme(text = element_text(family = 'a'),
        axis.title = element_text(size = 14, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 16)),
        axis.title.y = element_text(margin = margin(r = 16)),
        axis.text = element_text(size = 12),
        legend.title = element_text(size = 14, face = 'bold', margin = margin(r = 14)),
        legend.text = element_text(size = 12)) +
  geom_polygon(data = jeju, aes(x = long, y = lat, group = group), fill = NA, size = 1.2, color = 'black')


##########################  plot both narrow & broad scale predictions for Jeju together == continuous and binary
######## continuous models
# stack cont models
mods <- stack(pred.b.jj, pred.n.jj)
names(mods) = c('Broad', 'Narrow')

# plot ::: W 876 X H 300
gplot(mods) +
  geom_tile(aes(fill = value)) +
  facet_wrap(~ variable) +
  coord_equal() +
  scale_fill_gradientn(colors = c('#2b83ba', '#abdda4', '#ffffbf', '#fdae61', '#4f05d7'),
                       na.value = 'transparent',
                       name = 'Suitability',
                       breaks = c(0.12, 0.9),
                       labels  = c('Low', 'High')) +
  xlab('Longitude (°)') + ylab('Latitude (°)') +
  theme_dark() +
  theme(text = element_text(family = 'a'),
        strip.text = element_text(size = 16, face = 'bold'),
        axis.title = element_text(size = 14, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 14)),
        axis.title.y = element_text(margin = margin(r = 14)),
        axis.text = element_text(size = 12),
        legend.title = element_text(size = 14, face = 'bold', margin = margin(b = 10)),
        legend.text = element_text(size = 12)) +
  geom_polygon(data = jeju, aes(x = long, y = lat, group = group), 
               linewidth = 1.4, color = 'black', fill = 'transparent')


########  binary models
# stack bin models  
bins <- raster::stack(broad.bin.jj, narrow.bin.jj)
names(bins) = c('Broad_bianry', 'Narrow_binary')

# plot ::: W 876 X H 300
gplot(bins) +
  geom_tile(aes(fill = value)) +
  facet_wrap(~ variable) +
  coord_equal() +
  scale_fill_gradientn(colors = rev(terrain.colors(1000)),
                       na.value = 'transparent') +
  xlab('Longitude (°)') + ylab('Latitude (°)') +
  theme_dark() +
  theme(text = element_text(family = 'a'),
        strip.text = element_text(size = 16, face = 'bold'),
        axis.title = element_text(size = 14, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 14)),
        axis.title.y = element_text(margin = margin(r = 14)),
        axis.text = element_text(size = 12),
        legend.position = 'none') +
  geom_polygon(data = jeju, aes(x = long, y = lat, group = group), 
               linewidth = 1.4, color = 'black', fill = 'transparent') 


##########################  plot full broad scale & narrow scale predictions
####  broad
plot(pred.b)

# plot == W 876 X H 609
gplot(pred.b) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = c('#2b83ba', '#abdda4', '#ffffbf', '#fdae61', '#4f05d7'),
                       na.value = 'transparent',
                       name = 'Suitability',
                       breaks = c(0.1, 0.9),
                       labels = c('Low', 'High')) +
  xlab('Longitude (°)') + ylab('Latitude (°)') +
  theme_dark() +
  theme(text = element_text(family = 'a'),
        strip.text = element_text(size = 16, face = 'bold'),
        axis.title = element_text(size = 14, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 14)),
        axis.title.y = element_text(margin = margin(r = 14)),
        axis.text = element_text(size = 12),
        legend.title = element_text(size = 14, face = 'bold', margin = margin(b = 10)),
        legend.text = element_text(size = 12))


####  narrow
plot(pred.n)
  
# plot == W 876 X H 609
gplot(pred.n) +
  geom_tile(aes(fill = value)) +
  coord_equal() +
  scale_fill_gradientn(colors = c('#2b83ba', '#abdda4', '#ffffbf', '#fdae61', '#4f05d7'),
                       na.value = 'transparent',
                       name = 'Suitability',
                       breaks = c(0.08, 0.9),
                       labels = c('Low', 'High')) +
  xlab('Longitude (°)') + ylab('Latitude (°)') +
  theme_dark() +
  theme(text = element_text(family = 'a'),
        strip.text = element_text(size = 16, face = 'bold'),
        axis.title = element_text(size = 14, face = 'bold'),
        axis.title.x = element_text(margin = margin(t = 14)),
        axis.title.y = element_text(margin = margin(r = 14)),
        axis.text = element_text(size = 12),
        legend.title = element_text(size = 14, face = 'bold', margin = margin(b = 10)),
        legend.text = element_text(size = 12)) +
  geom_polygon(data = focal, aes(x = long, y = lat, group = group), linewidth = 1.2, color = 'black', fill = 'transparent')

