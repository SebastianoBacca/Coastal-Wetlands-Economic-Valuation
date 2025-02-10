## Meta-regression benefit transfer

#libraries
library(dplyr)
library(ggplot2)
library(lmtest)
library(sandwich)
library(lme4)
library(MASS)
library(plm)
library(car)
library(xtable) 
library(openxlsx)
library(sf)
library(raster)
library(rgdal)
library(ggspatial)
library(rnaturalearth)
library(rnaturalearthdata)
library(writexl)

Sys.setenv(R_PROJECTS_PATH = "C:/Users/sebas/kDrive2/R-projects")

#meta-regression dataset of local case studies from ESVD
wetland_values <- read.csv(file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "wetland_values.csv"), header = TRUE)
head(wetland_values)
str(wetland_values)
summary(wetland_values)

#wetlands polygons mapping and visualization from .gpkg file 
wetlands_map <- st_read(file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "global_wetland_clusters.gpkg"))

#world map
world <- ne_countries(scale = "medium", returnclass = "sf")

#little adjustments
wetlands_map <- wetlands_map %>% mutate(type = ifelse(type == "saltmarch", "saltmarsh", type)) %>% filter(type != "coral_reef")

#global map
ggplot(data = world) + geom_sf() + geom_sf(data = wetlands_map, fill = "blue", color = "darkblue", alpha = 1) + theme_minimal() + ggtitle("Global coastal wetlands map")

#coloring wetlands according to the type (mangroves, salt marshes and tidal flats)
wetlands_map$type <- factor(wetlands_map$type, levels = c("saltmarsh", "mangrove", "tidal flat", "coral reef"))
ggplot(data = world) + geom_sf() + geom_sf(data = wetlands_map, aes(fill = type), alpha = 1, size = 0.1) + scale_fill_manual(values = c("saltmarsh" = "blue", "mangrove" = "green", "tidal flat" = "red")) + theme_minimal() + ggtitle("Global coastal wetlands by type") + theme(legend.title = element_text(size = 10), legend.text = element_text(size = 8))

#zooming in specific in the areas of interest
#the UK
uk_bbox <- st_bbox(c(xmin = -11, ymin = 49, xmax = 2, ymax = 61), crs = st_crs(4326)) 
ggplot(data = world) + geom_sf() + geom_sf(data = wetlands_map, aes(fill = type), color = "black", alpha = 1, size = 0.1) + scale_fill_manual(values = c("saltmarsh" = "blue", "tidal flat" = "red")) + coord_sf(xlim = c(uk_bbox$xmin, uk_bbox$xmax), ylim = c(uk_bbox$ymin, uk_bbox$ymax), expand = FALSE) + theme_minimal() + ggtitle("Coastal wetlands in the UK by type") + theme(legend.title = element_text(size = 10), legend.text = element_text(size = 8))

#the Wash bay (a large bay on the east coast of England)
wash_bbox <- st_bbox(c(xmin = -0.1, ymin = 52.6, xmax = 1.1, ymax = 53.6), crs = st_crs(4326))
ggplot(data = world) + geom_sf() + geom_sf(data = wetlands_map, aes(fill = type), color = "black", alpha = 1, size = 0.3) + scale_fill_manual(values = c("saltmarsh" = "blue", "tidal flat" = "red")) + coord_sf(xlim = c(wash_bbox$xmin, wash_bbox$xmax), ylim = c(wash_bbox$ymin, wash_bbox$ymax), expand = FALSE) + theme_minimal() + ggtitle("Coastal wetlands in the Wash bay by type") + theme(legend.title = element_text(size = 10), legend.text = element_text(size = 8))

#Bangladesh
bangladesh_bbox <- st_bbox(c(xmin = 88, ymin = 20, xmax = 93, ymax = 27), crs = st_crs(4326))
ggplot(data = world) + geom_sf() + geom_sf(data = wetlands_map, aes(fill = type), color = "black", alpha = 1, size = 0.1) + scale_fill_manual(values = c("saltmarsh" = "blue", "mangrove" = "green", "tidal flat" = "purple")) + coord_sf(xlim = c(bangladesh_bbox$xmin, bangladesh_bbox$xmax), ylim = c(bangladesh_bbox$ymin, bangladesh_bbox$ymax), expand = FALSE) + theme_minimal() + ggtitle("Coastal wetlands in Bangladesh by type") + theme(legend.title = element_text(size = 10), legend.text = element_text(size = 8))

#Sundarbans (one of the world's largest mangrove forest located in the southwestern part of Bangladesh)
sundarbans_bbox <- st_bbox(c(xmin = 88.0, ymin = 21.5, xmax = 90.0, ymax = 23.0), crs = st_crs(4326))
ggplot(data = world) + geom_sf() + geom_sf(data = wetlands_map, aes(fill = type), color = "black", alpha = 1, size = 0.3) + scale_fill_manual(values = c("mangrove" = "green")) + coord_sf(xlim = c(sundarbans_bbox$xmin, sundarbans_bbox$xmax), ylim = c(sundarbans_bbox$ymin, sundarbans_bbox$ymax), expand = FALSE) + theme_minimal() + ggtitle("Coastal wetlands in Sundarbans, Bangladesh, by type") + theme(legend.title = element_text(size = 10), legend.text = element_text(size = 8))

#geolocate the local case studies sites on a global map
world_map <- map_data("world")
case_studies_plot <- ggplot() + geom_polygon(data = world_map, aes(x = long, y = lat, group = group), fill = "grey80") + geom_point(data = wetland_values, aes(x = Longitude, y = Latitude), color = "red", size = 0.5) + labs(title = "Global map of local case study sites valuing coastal wetlands from ESVD", x = "Longitude", y = "Latitude")
case_studies_plot

#relationship between the coastal wetlands site area and the value ($) per ha 
wetland_values %>% ggplot(aes(x = log(Site_Area_In_Hectares) , y = log(Y))) + geom_point(alpha=0.8, color="darkgreen") + geom_smooth(method = "lm", se = FALSE, color = "red")+ ggtitle("Monetary values and coastal wetland size") + xlab("wetland area in ha") + ylab("marginal value Int$/ha")

#ols model estimation and diagnostics
olsd <- lm(log(Y) ~ Latitude + Longitude + Year_Pub + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + MP + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = wetland_values)
summary(olsd)

#Variance inflation factor for multicollinearity (>10 highly correlated)
vif(olsd)
#mp variable has a high vif, but still below 10. We proceed removing MP

#Ramsey RESET test for misspecification error
reset(olsd, power = 2)
#the test suggests no significant evidence of model misspecification

#Breusch-Pagan test for heteroskedasticity
bptest(olsd)
#there is heteroskedasticity in the model therefore we proceed using cluster robust standard errors 

#diagnostic plots
par(mfrow = c(2,2))
plot(olsd)

###OLS with cluster robust standard errors
#OLS unrestricted model
OLS <- lm(log(Y) ~ Longitude + Latitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = wetland_values)
OLS.cr <- coeftest(OLS, vcov = vcovHC, type = "HC1", cluster = "StudyId")
summary(OLS)
OLS.cr
AIC(OLS)
BIC(OLS)

#OLS restricted only methodological variables
OLS_method <- lm(log(Y) ~ log(Site_Area_In_Hectares) + CE + CV + DC + FI + GV + HP + OC + PF  + RC + RT + SC + TC + log(1+ population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020)  + Marginal_value  , data = wetland_values)
OLS_method.cr <- coeftest(OLS_method, vcov = vcovHC, type = "HC1", cluster = "StudyId")
summary(OLS_method)
OLS_method.cr
AIC(OLS_method)
BIC(OLS_method)

#OLS restricted without methodological variables
OLS_method_out <- lm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km * 100) + log(GDP_per_capita_2020) + Marginal_value, data = wetland_values)
OLS_method_out.cr <- coeftest(OLS_method_out, vcov = vcovHC, type = "HC1", cluster = "StudyId")
summary(OLS_method_out)
OLS_method_out.cr
AIC(OLS_method_out)
BIC(OLS_method_out)

###WLS regression
#creating the weights for weighted regression such that each study counts as 1
df <- wetland_values
df_counts <- df %>% group_by(StudyId) %>% summarize(count = n())
df_weights <- df_counts %>% mutate(weight = 1 / count)
df <- left_join(df, df_weights, by = "StudyId")
write.csv(df, file = file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "wetland_values_weighted.csv"), row.names = FALSE)
wetland_values_weighted <- df
head(wetland_values_weighted)

#WLS unrestricted model
weights <- wetland_values_weighted$weight
WLS <- lm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = wetland_values, weights = weights)
WLS.cr <- coeftest(WLS, vcov = vcovHC(WLS, type = "HC1", cluster = "StudyId"))
summary(WLS)
WLS.cr
AIC(WLS)
BIC(WLS)

#WLS restricted only methodological variables
WLS_method <- lm(log(Y) ~ log(Site_Area_In_Hectares) + CE + CV + DC + FI + GV + HP + OC + PF  + RC + RT + SC + TC + log(1+ population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020)  + Marginal_value  , data = wetland_values, weights = weights)
WLS_method.cr <- coeftest(WLS_method, vcov = vcovHC(WLS, type = "HC1", cluster = "StudyId"))
summary(WLS_method)
WLS_method.cr
AIC(WLS_method)
BIC(WLS_method)

#WLS restricted without methodological variable
WLS_method_out <- lm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km * 100) + log(GDP_per_capita_2020) + Marginal_value, data = wetland_values, weights = weights)
WLS_method_out.cr <- coeftest(OLS_method_out, vcov = vcovHC, type = "HC1", cluster = "StudyId")
summary(WLS_method_out)
WLS_method_out.cr
AIC(WLS_method_out)
BIC(WLS_method_out)

###Panel models with cluster robust standard error
panelmetadata <- pdata.frame(wetland_values, index = "StudyId")
pdim(panelmetadata)

#Fixed effect model
FE <- plm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = panelmetadata, model = "within", index = "StudyId")
FE.cr <- vcovHC(FE, type = "HC3", cluster = "group")
summary(FE, robust.se = TRUE)

#Pooled OLS model 
Pols <- plm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = panelmetadata, model = "pooling", index = "StudyId")
Pols.cr <- vcovHC(Pols, type = "HC3", cluster = "group")
summary(Pols, robust.se = TRUE)

#Breusch-Pagan Lagrange multiplier test
plmtest(Pols, effect = "individual", type = "bp")
#if pvalue is below 0.05 there is strong evidence against the null hypothesis of homoskedasticity,there is heteroscedasticity. Therefore we proceed using the fixed effect model.

#Random effects model
RE <- plm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = panelmetadata, model = "random", effect = "individual", index = "StudyId")
RE.cr <- vcovHC(RE, type = "HC3", cluster = "group")
summary(RE, robust.se = TRUE)

#Hausman Chi2 test choosing between random or fixed effect model
phtest(FE, RE)
#if pvalue is below 0.05 there is strong evidence against the null hypothesis of homoskedasticity,there is heteroscedasticity. Therefore the random effect model is inconsistent.

###Validity tests and error measurements
#MAPE loss function
calculate_mape <- function(real, predicted) {
  if (length(real) != length(predicted)) {
    stop("Input vectors must have the same length.")
    } 
  mape <- mean(abs((real - predicted) / real)) * 100 
  return(mape)
  }

#GMAPE loss function
calculate_gmape <- function(actual, forecast) {n <- length(actual)
if (n != length(forecast)) {
stop("Lengths of 'actual' and 'forecast' vectors must be the same.")
  }
  if (any(actual == 0)) {
    stop("Actual values must not contain zero for GMAPE calculation.")
  }
  percentage_errors <- abs(actual - forecast) / abs(actual)
  gmape <- prod(1 + percentage_errors)^(1/n) - 1
  return(gmape * 100)  
}

##Leave-one-out cross validation prediction unrestricted models OLS, WLS and RE
##OLS prediction
predictions <- numeric(nrow(wetland_values))
for (i in 1:nrow(wetland_values)) {
  validation_row <- wetland_values[i, ]
  train_data <- wetland_values[-i, ]
  OLS.cv <- lm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = train_data)
  predictions[i] <- predict(OLS.cv, newdata = validation_row)
}

#In-sample MAPE OLS
mape_result_in <- mean(abs((log(wetland_values$Y) - OLS$fitted.values) / log(wetland_values$Y))) * 100
print(paste("MAPE in-sample transfer error OLS:", mape_result_in, "%"))

#Out-of-sample MAPE using leave-one-out cross validation OLS
mape_result_out <- calculate_mape(log(wetland_values$Y), predictions)
print(paste("MAPE out-of-sample transfer error OLS:", mape_result_out, "%"))

#In-sample GMAPE OLS
n <- length(wetland_values$Y)
percentage_errors <- abs(log(wetland_values$Y) - OLS$fitted.values) / abs(log(wetland_values$Y))
gmape <- prod(1 + percentage_errors)^(1/n) - 1
gmape_result_in <- gmape*100
print(paste("GMAPE in-sample transfer error OLS:", gmape_result_in, "%")) 

#Out-of-sample GMAPE using leave-one-out cross validation OLS
actual_values <- log(wetland_values$Y)
forecast_values <- predictions
gmape_result_out <- calculate_gmape(actual = actual_values, forecast = forecast_values)
print(paste("GMAPE out-of-sample transfer error:", gmape_result_out))

##WLS prediction
predictions <- numeric(nrow(wetland_values_weighted))
for (i in 1:nrow(wetland_values_weighted)) {
  validation_row <- wetland_values_weighted[i, ]
  train_data <- wetland_values_weighted[-i, ]
  WLS.cv <- lm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = train_data, weights = train_data$weight)
  predictions[i] <- predict(WLS.cv, newdata = validation_row)
}

#In-sample MAPE WLS
mape_result_in <- mean(abs((log(wetland_values_weighted$Y) - WLS$fitted.values) / log(wetland_values_weighted$Y))) * 100
print(paste("MAPE in-sample transfer error WLS:", mape_result_in, "%"))

#Out-of-sample MAPE using leave-one-out cross validation WLS
mape_result_out <- calculate_mape(log(wetland_values_weighted$Y), predictions)
print(paste("MAPE out-of-sample transfer error WLS:", mape_result_out, "%"))

#In-sample GMAPE WLS
n <- length(wetland_values_weighted$Y)
percentage_errors <- abs(log(wetland_values_weighted$Y) - WLS$fitted.values) / abs(log(wetland_values_weighted$Y))
gmape <- prod(1 + percentage_errors)^(1/n) - 1
gmape_result_in <- gmape*100
print(paste("GMAPE in-sample transfer error WLS:", gmape_result_in, "%")) 

#Out-of-sample GMAPE using leave-one-out cross validation WLS
actual_values <- log(wetland_values_weighted$Y)
forecast_values <- predictions
gmape_result_out <- calculate_gmape(actual = actual_values, forecast = forecast_values)
print(paste("GMAPE out-of-sample transfer error WLS:", gmape_result_out))

##RE prediction
panelmetadata <- panelmetadata %>% group_by(StudyId) %>% filter(n() > 1) %>% ungroup()
prediction <- numeric(nrow(panelmetadata))
for (i in 1:nrow(panelmetadata)) {
  validation_row <- panelmetadata[i, ]
  train_data <- panelmetadata[-i, ]
  RE.cv <- plm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = train_data, model = "random", effect = "individual", index = "StudyId")
  prediction[i] <- predict(RE.cv, newdata = validation_row)
}

#In-sample MAPE RE
Y <- predict(RE, newdata = panelmetadata)
mape_result_in <- mean(abs((log(panelmetadata$Y) - Y) / log(panelmetadata$Y))) * 100
print(paste("MAPE in-sample transfer error RE:", mape_result_in, "%"))

#Out-of-sample MAPE using leave-one-out cross validation RE
mape_result_out <- calculate_mape(log(panelmetadata$Y), prediction)
print(paste("MAPE out-of-sample transfer error RE:", mape_result_out, "%"))

#In-sample GMAPE RE
n <- length(panelmetadata$Y)
percentage_errors <- abs(log(panelmetadata$Y) - Y) / abs(log(panelmetadata$Y))
gmape <- prod(1 + percentage_errors)^(1/n) - 1
gmape_result_in <- gmape*100
print(paste("GMAPE in-sample transfer error RE:", gmape_result_in, "%")) 

#Out-of-sample GMAPE using leave-one-out cross validation RE
actual_values <- log(panelmetadata$Y)
forecast_values <- prediction
gmape_result_out <- calculate_gmape(actual = actual_values, forecast = forecast_values)
print(paste("GMAPE out-of-sample transfer error RE:", gmape_result_out))

##FE prediction
panelmetadata <- pdata.frame(wetland_values, index = "StudyId")
panelmetadata <- panelmetadata %>% group_by(StudyId) %>% filter(n() > 1) %>% ungroup()
prediction <- numeric(nrow(panelmetadata))
for (i in 1:nrow(panelmetadata)) {
  validation_row <- panelmetadata[i, ]
  train_data <- panelmetadata[-i, ]
  FE.cv <- plm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = train_data, model = "random", effect = "individual", index = "StudyId")
  prediction[i] <- predict(RE.cv, newdata = validation_row)
}

#In-sample MAPE FE
Y <- predict(FE, newdata = panelmetadata)
mape_result_in <- mean(abs((log(panelmetadata$Y) - Y) / log(panelmetadata$Y))) * 100
print(paste("MAPE in-sample transfer error FE:", mape_result_in, "%"))

#Out-of-sample MAPE using leave-one-out cross validation FE
mape_result_out <- calculate_mape(log(panelmetadata$Y), prediction)
print(paste("MAPE out-of-sample transfer error FE:", mape_result_out, "%"))

#In-sample GMAPE FE
n <- length(panelmetadata$Y)
percentage_errors <- abs(log(panelmetadata$Y) - Y) / abs(log(panelmetadata$Y))
gmape <- prod(1 + percentage_errors)^(1/n) - 1
gmape_result_in <- gmape*100
print(paste("GMAPE in-sample transfer error FE:", gmape_result_in, "%")) 

#Out-of-sample GMAPE using leave-one-out cross validation FE
actual_values <- log(panelmetadata$Y)
forecast_values <- prediction
gmape_result_out <- calculate_gmape(actual = actual_values, forecast = forecast_values)
print(paste("GMAPE out-of-sample transfer error FE:", gmape_result_out))

##Trimmed OLS
lower_threshold <- quantile(wetland_values$Y, 0.05)
upper_threshold <- quantile(wetland_values$Y, 0.95)
trimmed_data <- wetland_values[wetland_values$Y >= lower_threshold & wetland_values$Y <= upper_threshold, ]
OLS_tr <- lm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = trimmed_data)
OLS_tr.cr <- coeftest(OLS_tr, vcov = vcovHC, type = "HC1", cluster = "StudyId")
summary(OLS_tr)
OLS_tr.cr

#prediction accuracy
predictions <- numeric(nrow(trimmed_data))
for (i in 1:nrow(trimmed_data)) {
  validation_row <- trimmed_data[i, ]
  train_data <- trimmed_data[-i, ]
  OLS_tr.cv <- lm(log(Y) ~ Latitude + Longitude + log(Site_Area_In_Hectares) + Coastal_salt_marshes_and_reedbeds + Mangroves + Muddy_shorelines + Riverine_estuaries_and_bays + Sandy_and_Rocky_Shorelines + Aesthetic_information + Air_quality_regulation + Climate_regulation + Erosion_prevention + Existence_bequest_values + Food + Information_for_cognitive_development + Inspiration_for_culture_art_and_design + Maintenance_of_genetic_diversity + Maintenance_of_life_cycles + Maintenance_of_soil_fertility + Medicinal_resources + Moderation_of_extreme_events + Opportunities_for_recreation_and_tourism + Raw_materials + Regulation_of_water_flows + Waste_treatment + Water + CE + CV + DC + FI + GV + HP + OC + PF + RC + RT + SC + TC + log(1 + population_in_50_km_radius) + log(1 + Ecosystems_in_75km*100) + log(GDP_per_capita_2020) + Marginal_value, data = train_data)
  predictions[i] <- predict(OLS_tr.cv, newdata = validation_row)
}

#In-sample MAPE Trimmed OLS
mape_result_in <- mean(abs((log(trimmed_data$Y) - OLS_tr$fitted.values) / log(trimmed_data$Y))) * 100
print(paste("MAPE in-sample transfer error Trimmed OLS:", mape_result_in, "%"))


#Out-of-sample MAPE using leave-one-out cross validation Trimmed OLS
mape_result_out <- calculate_mape(log(trimmed_data$Y), predictions)
print(paste("MAPE out-of-sample transfer error Trimmed OLS:", mape_result_out, "%"))

#In-sample GMAPE Trimmed OLS
n <- length(trimmed_data$Y)
percentage_errors <- abs(log(trimmed_data$Y) - OLS_tr$fitted.values) / abs(log(trimmed_data$Y))
gmape <- prod(1 + percentage_errors)^(1/n) - 1
gmape_result_in <- gmape*100
print(paste("GMAPE in-sample transfer error Trimmed OLS:", gmape_result_in, "%")) 


#Out-of-sample GMAPE using leave-one-out cross validation Trimmed OLS
actual_values <- log(trimmed_data$Y)
forecast_values <- predictions
gmape_result_out <- calculate_gmape(actual = actual_values, forecast = forecast_values)
print(paste("GMAPE out-of-sample transfer error Trimmed OLS:", gmape_result_out))

###Value function transfer global estimates 
global_wetlands_data <- read.csv(file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "global_wetlands_data.csv"), header = TRUE)
head(global_wetlands_data)
summary(global_wetlands_data)

#meta-regression benefit transfer prediction
value_prediction_ols <- predict(OLS, newdata=global_wetlands_data, interval = "predict", level = 0.95)
head(value_prediction_ols)
#converting back 
estimates_ols <- exp(value_prediction_ols)
head(estimates_ols)

#trimmed ols
value_prediction_tr <- predict(OLS_tr, newdata=global_wetlands_data, interval = "predict", level = 0.95)
head(value_prediction_tr)
#converting back 
estimates_tr <- exp(value_prediction_tr)
head(estimates_tr)

#store results a dataframe
data_ols <- as.data.frame(estimates_ols)
data_tr <- as.data.frame(estimates_tr)

#creating a new dataframe with the predicted monetary values
data_ols_renamed <- data_ols %>% rename(y_ols = fit, y_ols_lwr = lwr, y_ols_upr = upr)
data_tr_renamed <- data_tr %>% rename(y_tr = fit, y_tr_lwr = lwr, y_tr_upr = upr)
global_wetlands_values <- global_wetlands_data %>% bind_cols(data_ols_renamed) %>% bind_cols(data_tr_renamed)
head(global_wetlands_values)

#there are some NA when the fit is 0 we remove them from the analysis 
anyNA(data_ols_renamed)
anyNA(data_tr_renamed)
anyNA(global_wetlands_values)
global_wetlands_values <- global_wetlands_values %>% mutate(y_ols_lwr = replace(y_ols_lwr, is.na(y_ols_lwr), 0), y_ols_upr = replace(y_ols_upr, is.na(y_ols_upr), 0), y_tr_lwr = replace(y_tr_lwr, is.na(y_tr_lwr), 0), y_tr_upr = replace(y_tr_upr, is.na(y_tr_upr), 0))
head(global_wetlands_values)
anyNA(global_wetlands_values)

###Scale up calculations
#calculate total values for OLS predictions and bounds
global_wetlands_values$tot_value_ols <- global_wetlands_values$y_ols * global_wetlands_values$Site_Area_In_Hectares
global_wetlands_values$tot_value_ols_lwr <- global_wetlands_values$y_ols_lwr * global_wetlands_values$Site_Area_In_Hectares
global_wetlands_values$tot_value_ols_upr <- global_wetlands_values$y_ols_upr * global_wetlands_values$Site_Area_In_Hectares

#calculate total values for TR predictions and bounds
global_wetlands_values$tot_value_tr <- global_wetlands_values$y_tr * global_wetlands_values$Site_Area_In_Hectares
global_wetlands_values$tot_value_tr_lwr <- global_wetlands_values$y_tr_lwr * global_wetlands_values$Site_Area_In_Hectares
global_wetlands_values$tot_value_tr_upr <- global_wetlands_values$y_tr_upr * global_wetlands_values$Site_Area_In_Hectares

head(global_wetlands_values)

#save the dataframe with values
write.csv(global_wetlands_values, file = file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "global_wetlands_values.csv"), row.names = FALSE)

###global coastal wetlands areas loss 10%, 20% and 30%
##10% scenario
global_wetlands_reduction_10 <- as_tibble(global_wetlands_data)
global_wetlands_reduction_10$Site_Area_In_Hectares <- global_wetlands_data$Site_Area_In_Hectares * 0.9
global_wetlands_reduction_10$Ecosystems_in_75km <- global_wetlands_data$Ecosystems_in_75km * 0.9

#prediction
value_prediction_ols_10 <- predict(OLS, newdata=global_wetlands_reduction_10, interval = "predict", level = 0.95)
estimates_ols_10 <- exp(value_prediction_ols_10)
value_prediction_tr_10 <- predict(OLS_tr, newdata=global_wetlands_reduction_10, interval = "predict", level = 0.95)
estimates_tr_10 <- exp(value_prediction_tr_10)
data_ols_10 <- as.data.frame(estimates_ols_10)
data_tr_10 <- as.data.frame(estimates_tr_10)
data_ols_renamed_10 <- data_ols_10 %>% rename(y_ols = fit, y_ols_lwr = lwr, y_ols_upr = upr)
data_tr_renamed_10 <- data_tr_10 %>% rename(y_tr = fit, y_tr_lwr = lwr, y_tr_upr = upr)
global_wetlands_reduction_10 <- global_wetlands_reduction_10 %>% bind_cols(data_ols_renamed_10) %>% bind_cols(data_tr_renamed_10)
global_wetlands_reduction_10 <- global_wetlands_reduction_10 %>% mutate(y_ols_lwr = replace(y_ols_lwr, is.na(y_ols_lwr), 0), y_ols_upr = replace(y_ols_upr, is.na(y_ols_upr), 0), y_tr_lwr = replace(y_tr_lwr, is.na(y_tr_lwr), 0), y_tr_upr = replace(y_tr_upr, is.na(y_tr_upr), 0))

#calculate total values
global_wetlands_reduction_10$tot_value_ols <- global_wetlands_reduction_10$y_ols * global_wetlands_reduction_10$Site_Area_In_Hectares
global_wetlands_reduction_10$tot_value_ols_lwr <- global_wetlands_reduction_10$y_ols_lwr * global_wetlands_reduction_10$Site_Area_In_Hectares
global_wetlands_reduction_10$tot_value_ols_upr <- global_wetlands_reduction_10$y_ols_upr * global_wetlands_reduction_10$Site_Area_In_Hectares
global_wetlands_reduction_10$tot_value_tr <- global_wetlands_reduction_10$y_tr * global_wetlands_reduction_10$Site_Area_In_Hectares
global_wetlands_reduction_10$tot_value_tr_lwr <- global_wetlands_reduction_10$y_tr_lwr * global_wetlands_reduction_10$Site_Area_In_Hectares
global_wetlands_reduction_10$tot_value_tr_upr <- global_wetlands_reduction_10$y_tr_upr * global_wetlands_reduction_10$Site_Area_In_Hectares


##20% scenario
global_wetlands_reduction_20 <- as_tibble(global_wetlands_data)
global_wetlands_reduction_20$Site_Area_In_Hectares <- global_wetlands_data$Site_Area_In_Hectares * 0.8
global_wetlands_reduction_20$Ecosystems_in_75km <- global_wetlands_data$Ecosystems_in_75km * 0.8

#prediction
value_prediction_ols_20 <- predict(OLS, newdata=global_wetlands_reduction_20, interval = "predict", level = 0.95)
estimates_ols_20 <- exp(value_prediction_ols_20)
value_prediction_tr_20 <- predict(OLS_tr, newdata=global_wetlands_reduction_20, interval = "predict", level = 0.95)
estimates_tr_20 <- exp(value_prediction_tr_20)

data_ols_20 <- as.data.frame(estimates_ols_20)
data_tr_20 <- as.data.frame(estimates_tr_20)
data_ols_renamed_20 <- data_ols_20 %>% rename(y_ols = fit, y_ols_lwr = lwr, y_ols_upr = upr)
data_tr_renamed_20 <- data_tr_20 %>% rename(y_tr = fit, y_tr_lwr = lwr, y_tr_upr = upr)

global_wetlands_reduction_20 <- global_wetlands_reduction_20 %>% bind_cols(data_ols_renamed_20) %>% bind_cols(data_tr_renamed_20)
global_wetlands_reduction_20 <- global_wetlands_reduction_20 %>% mutate(y_ols_lwr = replace(y_ols_lwr, is.na(y_ols_lwr), 0), y_ols_upr = replace(y_ols_upr, is.na(y_ols_upr), 0), y_tr_lwr = replace(y_tr_lwr, is.na(y_tr_lwr), 0), y_tr_upr = replace(y_tr_upr, is.na(y_tr_upr), 0))

#calculate total values
global_wetlands_reduction_20$tot_value_ols <- global_wetlands_reduction_20$y_ols * global_wetlands_reduction_20$Site_Area_In_Hectares
global_wetlands_reduction_20$tot_value_ols_lwr <- global_wetlands_reduction_20$y_ols_lwr * global_wetlands_reduction_20$Site_Area_In_Hectares
global_wetlands_reduction_20$tot_value_ols_upr <- global_wetlands_reduction_20$y_ols_upr * global_wetlands_reduction_20$Site_Area_In_Hectares
global_wetlands_reduction_20$tot_value_tr <- global_wetlands_reduction_20$y_tr * global_wetlands_reduction_20$Site_Area_In_Hectares
global_wetlands_reduction_20$tot_value_tr_lwr <- global_wetlands_reduction_20$y_tr_lwr * global_wetlands_reduction_20$Site_Area_In_Hectares
global_wetlands_reduction_20$tot_value_tr_upr <- global_wetlands_reduction_20$y_tr_upr * global_wetlands_reduction_20$Site_Area_In_Hectares


##30% scenario
global_wetlands_reduction_30 <- as_tibble(global_wetlands_data)
global_wetlands_reduction_30$Site_Area_In_Hectares <- global_wetlands_data$Site_Area_In_Hectares * 0.7
global_wetlands_reduction_30$Ecosystems_in_75km <- global_wetlands_data$Ecosystems_in_75km * 0.7

#prediction
value_prediction_ols_30 <- predict(OLS, newdata=global_wetlands_reduction_30, interval = "predict", level = 0.95)
estimates_ols_30 <- exp(value_prediction_ols_30)
value_prediction_tr_30 <- predict(OLS_tr, newdata=global_wetlands_reduction_30, interval = "predict", level = 0.95)
estimates_tr_30 <- exp(value_prediction_tr_30)

data_ols_30 <- as.data.frame(estimates_ols_30)
data_tr_30 <- as.data.frame(estimates_tr_30)
data_ols_renamed_30 <- data_ols_30 %>% rename(y_ols = fit, y_ols_lwr = lwr, y_ols_upr = upr)
data_tr_renamed_30 <- data_tr_30 %>% rename(y_tr = fit, y_tr_lwr = lwr, y_tr_upr = upr)

global_wetlands_reduction_30 <- global_wetlands_reduction_30 %>% bind_cols(data_ols_renamed_30) %>% bind_cols(data_tr_renamed_30)
global_wetlands_reduction_30 <- global_wetlands_reduction_30 %>% mutate(y_ols_lwr = replace(y_ols_lwr, is.na(y_ols_lwr), 0), y_ols_upr = replace(y_ols_upr, is.na(y_ols_upr), 0), y_tr_lwr = replace(y_tr_lwr, is.na(y_tr_lwr), 0), y_tr_upr = replace(y_tr_upr, is.na(y_tr_upr), 0))

#calculate total values
global_wetlands_reduction_30$tot_value_ols <- global_wetlands_reduction_30$y_ols * global_wetlands_reduction_30$Site_Area_In_Hectares
global_wetlands_reduction_30$tot_value_ols_lwr <- global_wetlands_reduction_30$y_ols_lwr * global_wetlands_reduction_30$Site_Area_In_Hectares
global_wetlands_reduction_30$tot_value_ols_upr <- global_wetlands_reduction_30$y_ols_upr * global_wetlands_reduction_30$Site_Area_In_Hectares
global_wetlands_reduction_30$tot_value_tr <- global_wetlands_reduction_30$y_tr * global_wetlands_reduction_30$Site_Area_In_Hectares
global_wetlands_reduction_30$tot_value_tr_lwr <- global_wetlands_reduction_30$y_tr_lwr * global_wetlands_reduction_30$Site_Area_In_Hectares
global_wetlands_reduction_30$tot_value_tr_upr <- global_wetlands_reduction_30$y_tr_upr * global_wetlands_reduction_30$Site_Area_In_Hectares


###Welfare loss calculation 
#A1 = original area (no wetlands loss), A2;A3;A4 = wetlands area after the 10,20,30% loss, P1 = monetary value original area, P2;P3;P4 = monetary value after change
#area change: change_10 = A1 - A2, change_20 = A1 - A3, change_30 = A1 - A4. mean marginal change: mean_marginal_value_10 = (P1 .+ P2)/ 2, mean_marginal_value_20 = (P1 .+ P3)/ 2, mean_marginal_value_30 = (P1 .+ P4)/ 2
global_wetlands_reduction_10$area_change <- global_wetlands_values$Site_Area_In_Hectares - global_wetlands_reduction_10$Site_Area_In_Hectares
global_wetlands_reduction_10$mean_value_change <- (global_wetlands_values$y_ols + global_wetlands_reduction_10$y_ols)/2
global_wetlands_reduction_10$mean_value_change_lwr <- (global_wetlands_values$y_ols_lwr + global_wetlands_reduction_10$y_ols_lwr)/2
global_wetlands_reduction_10$mean_value_change_upr <- (global_wetlands_values$y_ols_upr + global_wetlands_reduction_10$y_ols_upr)/2

global_wetlands_reduction_10$mean_value_change_tr <- (global_wetlands_values$y_tr + global_wetlands_reduction_10$y_tr)/2
global_wetlands_reduction_10$mean_value_change_lwr_tr <- (global_wetlands_values$y_tr_lwr + global_wetlands_reduction_10$y_tr_lwr)/2
global_wetlands_reduction_10$mean_value_change_upr_tr <- (global_wetlands_values$y_tr_upr + global_wetlands_reduction_10$y_tr_upr)/2

global_wetlands_reduction_10$value_change <- global_wetlands_reduction_10$area_change * global_wetlands_reduction_10$mean_value_change
global_wetlands_reduction_10$value_change_lwr <- global_wetlands_reduction_10$area_change * global_wetlands_reduction_10$mean_value_change_lwr
global_wetlands_reduction_10$value_change_upr <- global_wetlands_reduction_10$area_change * global_wetlands_reduction_10$mean_value_change_upr
  
global_wetlands_reduction_10$value_change_tr <- global_wetlands_reduction_10$area_change * global_wetlands_reduction_10$mean_value_change_tr
global_wetlands_reduction_10$value_change_tr_lwr <- global_wetlands_reduction_10$area_change * global_wetlands_reduction_10$mean_value_change_lwr_tr
global_wetlands_reduction_10$value_change_tr_upr <- global_wetlands_reduction_10$area_change * global_wetlands_reduction_10$mean_value_change_upr_tr 

#export dataframe
write.csv(global_wetlands_reduction_10, file = file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "global_wetlands_reduction_10.csv"), row.names = FALSE)

#scenario 20%
global_wetlands_reduction_20$area_change <- global_wetlands_values$Site_Area_In_Hectares - global_wetlands_reduction_20$Site_Area_In_Hectares
global_wetlands_reduction_20$mean_value_change <- (global_wetlands_values$y_ols + global_wetlands_reduction_20$y_ols) / 2
global_wetlands_reduction_20$mean_value_change_lwr <- (global_wetlands_values$y_ols_lwr + global_wetlands_reduction_20$y_ols_lwr) / 2
global_wetlands_reduction_20$mean_value_change_upr <- (global_wetlands_values$y_ols_upr + global_wetlands_reduction_20$y_ols_upr) / 2

global_wetlands_reduction_20$mean_value_change_tr <- (global_wetlands_values$y_tr + global_wetlands_reduction_20$y_tr) / 2
global_wetlands_reduction_20$mean_value_change_lwr_tr <- (global_wetlands_values$y_tr_lwr + global_wetlands_reduction_20$y_tr_lwr) / 2
global_wetlands_reduction_20$mean_value_change_upr_tr <- (global_wetlands_values$y_tr_upr + global_wetlands_reduction_20$y_tr_upr) / 2

global_wetlands_reduction_20$value_change <- global_wetlands_reduction_20$area_change * global_wetlands_reduction_20$mean_value_change
global_wetlands_reduction_20$value_change_lwr <- global_wetlands_reduction_20$area_change * global_wetlands_reduction_20$mean_value_change_lwr
global_wetlands_reduction_20$value_change_upr <- global_wetlands_reduction_20$area_change * global_wetlands_reduction_20$mean_value_change_upr

global_wetlands_reduction_20$value_change_tr <- global_wetlands_reduction_20$area_change * global_wetlands_reduction_20$mean_value_change_tr
global_wetlands_reduction_20$value_change_tr_lwr <- global_wetlands_reduction_20$area_change * global_wetlands_reduction_20$mean_value_change_lwr_tr
global_wetlands_reduction_20$value_change_tr_upr <- global_wetlands_reduction_20$area_change * global_wetlands_reduction_20$mean_value_change_upr_tr

#export dataframe
write.csv(global_wetlands_reduction_20, file = file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "global_wetlands_reduction_20.csv"), row.names = FALSE)

#scenario 30%
global_wetlands_reduction_30$area_change <- global_wetlands_values$Site_Area_In_Hectares - global_wetlands_reduction_30$Site_Area_In_Hectares
global_wetlands_reduction_30$mean_value_change <- (global_wetlands_values$y_ols + global_wetlands_reduction_30$y_ols) / 2
global_wetlands_reduction_30$mean_value_change_lwr <- (global_wetlands_values$y_ols_lwr + global_wetlands_reduction_30$y_ols_lwr) / 2
global_wetlands_reduction_30$mean_value_change_upr <- (global_wetlands_values$y_ols_upr + global_wetlands_reduction_30$y_ols_upr) / 2

global_wetlands_reduction_30$mean_value_change_tr <- (global_wetlands_values$y_tr + global_wetlands_reduction_30$y_tr) / 2
global_wetlands_reduction_30$mean_value_change_lwr_tr <- (global_wetlands_values$y_tr_lwr + global_wetlands_reduction_30$y_tr_lwr) / 2
global_wetlands_reduction_30$mean_value_change_upr_tr <- (global_wetlands_values$y_tr_upr + global_wetlands_reduction_30$y_tr_upr) / 2

global_wetlands_reduction_30$value_change <- global_wetlands_reduction_30$area_change * global_wetlands_reduction_30$mean_value_change
global_wetlands_reduction_30$value_change_lwr <- global_wetlands_reduction_30$area_change * global_wetlands_reduction_30$mean_value_change_lwr
global_wetlands_reduction_30$value_change_upr <- global_wetlands_reduction_30$area_change * global_wetlands_reduction_30$mean_value_change_upr

global_wetlands_reduction_30$value_change_tr <- global_wetlands_reduction_30$area_change * global_wetlands_reduction_30$mean_value_change_tr
global_wetlands_reduction_30$value_change_tr_lwr <- global_wetlands_reduction_30$area_change * global_wetlands_reduction_30$mean_value_change_lwr_tr
global_wetlands_reduction_30$value_change_tr_upr <- global_wetlands_reduction_30$area_change * global_wetlands_reduction_30$mean_value_change_upr_tr

#export dataframe
write.csv(global_wetlands_reduction_30, file = file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "global_wetlands_reduction_30.csv"), row.names = FALSE)

#aggregate results by countries
country_aggregated_value_change_10 <- global_wetlands_reduction_10 %>% group_by(Country_Codes) %>% 
  summarise(total_value_of_change_10_ols = sum(value_change),
            total_value_of_change_10_tr = sum(value_change_tr),
            total_value_of_change_10_ols_lwr = sum(value_change_lwr),
            total_value_of_change_10_ols_upr = sum(value_change_upr),
            total_value_of_change_10_tr_lwr = sum(value_change_tr_lwr),
            total_value_of_change_10_tr_upr = sum(value_change_tr_upr))

#aggregate values for 20% reduction scenario
country_aggregated_value_change_20 <- global_wetlands_reduction_20 %>% group_by(Country_Codes) %>%
  summarise(total_value_of_change_20_ols = sum(value_change),
            total_value_of_change_20_tr = sum(value_change_tr),
            total_value_of_change_20_ols_lwr = sum(value_change_lwr),
            total_value_of_change_20_ols_upr = sum(value_change_upr),
            total_value_of_change_20_tr_lwr = sum(value_change_tr_lwr),
            total_value_of_change_20_tr_upr = sum(value_change_tr_upr))

#aggregate values for 30% reduction scenario
country_aggregated_value_change_30 <- global_wetlands_reduction_30 %>% group_by(Country_Codes) %>%
  summarise(total_value_of_change_30_ols = sum(value_change), 
            total_value_of_change_30_tr = sum(value_change_tr),
            total_value_of_change_30_ols_lwr = sum(value_change_lwr),
            total_value_of_change_30_ols_upr = sum(value_change_upr),
            total_value_of_change_30_tr_lwr = sum(value_change_tr_lwr),
            total_value_of_change_30_tr_upr = sum(value_change_tr_upr))

#combine all scenarios into a single dataframe
country_aggregated_value_changes <- country_aggregated_value_change_10 %>% 
  full_join(country_aggregated_value_change_20, by = "Country_Codes") %>% 
  full_join(country_aggregated_value_change_30, by = "Country_Codes")

#save the results
write.csv(country_aggregated_value_changes, file = file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "country_aggregated_value_changes.csv"), row.names = FALSE)

###Results 
#global welfare losses for OLS method
global_value_change_10_scenario_ols <- (sum(global_wetlands_reduction_10$value_change))/1000000
global_value_change_10_scenario_ols_lwr <- (sum(global_wetlands_reduction_10$value_change_lwr))/1000000
global_value_change_10_scenario_ols_upr <- (sum(global_wetlands_reduction_10$value_change_upr))/1000000

#global welfare losses for TR method
global_value_change_10_scenario_tr <- (sum(global_wetlands_reduction_10$value_change_tr))/1000000
global_value_change_10_scenario_tr_lwr <- (sum(global_wetlands_reduction_10$value_change_tr_lwr))/1000000
global_value_change_10_scenario_tr_upr <- (sum(global_wetlands_reduction_10$value_change_tr_upr))/1000000

#20% scenario calculations
global_value_change_20_scenario_ols <- (sum(global_wetlands_reduction_20$value_change))/1000000
global_value_change_20_scenario_ols_lwr <- (sum(global_wetlands_reduction_20$value_change_lwr))/1000000
global_value_change_20_scenario_ols_upr <- (sum(global_wetlands_reduction_20$value_change_upr))/1000000

global_value_change_20_scenario_tr <- (sum(global_wetlands_reduction_20$value_change_tr))/1000000
global_value_change_20_scenario_tr_lwr <- (sum(global_wetlands_reduction_20$value_change_tr_lwr))/1000000
global_value_change_20_scenario_tr_upr <- (sum(global_wetlands_reduction_20$value_change_tr_upr))/1000000

#30% scenario calculations
global_value_change_30_scenario_ols <- (sum(global_wetlands_reduction_30$value_change))/1000000
global_value_change_30_scenario_ols_lwr <- (sum(global_wetlands_reduction_30$value_change_lwr))/1000000
global_value_change_30_scenario_ols_upr <- (sum(global_wetlands_reduction_30$value_change_upr))/1000000

global_value_change_30_scenario_tr <- (sum(global_wetlands_reduction_30$value_change_tr))/1000000
global_value_change_30_scenario_tr_lwr <- (sum(global_wetlands_reduction_30$value_change_tr_lwr))/1000000
global_value_change_30_scenario_tr_upr <- (sum(global_wetlands_reduction_30$value_change_tr_upr))/1000000

#create a dataframe with all global results
global_results <- data.frame(
  Scenario = c("10% Reduction", "20% Reduction", "30% Reduction"),
  OLS_Estimate = c(global_value_change_10_scenario_ols, global_value_change_20_scenario_ols, global_value_change_30_scenario_ols),
  OLS_Lower_Bound = c(global_value_change_10_scenario_ols_lwr, global_value_change_20_scenario_ols_lwr, global_value_change_30_scenario_ols_lwr),
  OLS_Upper_Bound = c(global_value_change_10_scenario_ols_upr, global_value_change_20_scenario_ols_upr, global_value_change_30_scenario_ols_upr),
  TR_Estimate = c(global_value_change_10_scenario_tr, global_value_change_20_scenario_tr, global_value_change_30_scenario_tr),
  TR_Lower_Bound = c(global_value_change_10_scenario_tr_lwr, global_value_change_20_scenario_tr_lwr, global_value_change_30_scenario_tr_lwr),
  TR_Upper_Bound = c(global_value_change_10_scenario_tr_upr, global_value_change_20_scenario_tr_upr, global_value_change_30_scenario_tr_upr)
)

#export
write.csv(global_results, file = file.path(Sys.getenv("R_PROJECTS_PATH"), "meta_regression_benefit_transfer_coastal_wetlands", "global_welfare_losses_scenarios.csv"), row.names = FALSE)







