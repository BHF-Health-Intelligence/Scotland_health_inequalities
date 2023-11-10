### This script produces the plots for the prevention section of the BHF's Socioeconomic Health Inequalities in Scotland report
### Data is sourced from Scottish Health Survey: https://scotland.shinyapps.io/sg-scottish-health-survey/ 
### Note: some manual cleaning in Excel was done, and these files are used for the script.
### These files are: smoking_status_data.csv ; BMI_data.xlsx ; Fruit_veg_data.csv ; 'Scotland physical activity data.csv'

### Code structure (after loading necessary packages)
### Section 1 creates the custom BHF style functions for the plots (this requires access to our custom fonts)
### Section 2 sets the working directory (this will need amending to run locally if you're using the code)
### Section 3 reads and cleans the data, then creates the plots; with subsections of code taking each risk factor in turn.

library(tidyverse)
library(dplyr)
library(ggplot2)
library(openxlsx)
library(tidyr)
library(stringr)
library(ggthemes)
library(ggthemr)
library(curl)
library(ggrepel)
library(readxl)
library(RColorBrewer)
library(sf)
library(qicharts2)
library(showtext)
library(scales)
library(chron)
library(readODS)
library(lubridate)
library(sf)

######### Section 1 - RUN BHF STYLE FUNCTIONS###########

##ADD FONTS##

#Beats Will need to update local file location for .otf font files. Anyone seeking to recreate this analysis outside the BHF will need to use alternative fonts.

font_add("bhf_beats_bold", "C:/Users/almondth/OneDrive - British Heart Foundation/Documents/R/Fonts/Beats/OTF/BHFBeats-Bold.otf")
font_add("bhf_beats_light", "C:/Users/almondth/OneDrive - British Heart Foundation/Documents/R/Fonts/Beats/OTF/BHFBeats-Light.otf")
font_add("bhf_beats_reg", "C:/Users/almondth/OneDrive - British Heart Foundation/Documents/R/Fonts/Beats/OTF/BHFBeats-Regular.otf")
font_add("bhf_ginger_bold", "C:/Users/almondth/OneDrive - British Heart Foundation/Documents/R/Fonts/Ginger/OTF/F37Ginger-Bold.otf")
font_add("bhf_ginger_light", "C:/Users/almondth/OneDrive - British Heart Foundation/Documents/R/Fonts/Ginger/OTF/F37Ginger-Light.otf")
font_add("bhf_ginger_reg", "C:/Users/almondth/OneDrive - British Heart Foundation/Documents/R/Fonts/Ginger/OTF/F37Ginger-Regular.otf")
showtext_auto()

t_font <- list(family = "bhf_ginger_reg", size = 14)

#If you are using showtext in RMarkdown documents you don’t have to use showtext_auto(). 
#That will set up the wrong dpi and the text will look too small. 
#You need to add fig.showtext=TRUE to the chunk settings.

###SET COLOUR PALETTES##

bhf_colours <- c(
  `Bright Red` = "#FF0030",
  `Dark Red` = "#8C0032",
  `Medium Red` = "#D20019",
  `Rubine Red` = "#E71348",
  `Light Blue` = "#2D91FF",
  `Indigo` = "#500AB4",
  `Pinkish` = "#FF3C64",
  `Orange` = "#FF873C",
  `Yellow` = "#FFBE32",
  `Light green` = "#19D79B",
  `Dark green` = "#00A06E",
  `Dark grey` = "#474E5A",
  `White` = "#FFFFFF"
)

bhf_cols <- function(...) {
  cols <- c(...)
  if(is.null(cols))
    return(bhf_colours)
  bhf_colours[cols]
}

#Define palettes

bhf_palettes <- list(
  `reds` = bhf_cols("Bright Red","Dark Red","Rubine Red", "Medium Red"),
  `not reds` = bhf_cols("Bright Red","Light Blue","Indigo"),
  `gradient_1` = bhf_cols("Dark Red","Medium Red"),
  `gradient_2` = bhf_cols("Medium Red","Bright Red"),
  `gradient_3` = bhf_cols("Bright Red","Rubine Red"),
  `gradient_4` = bhf_cols("Bright Red","White"),
  `secondaries` = bhf_cols("Light Blue", "Indigo","Pinkish",
                           "Orange","Yellow","Light green",
                           "Dark green","Dark grey"),
  `expanded secondaries` = bhf_cols("Bright Red", "Light Blue", "Indigo","Pinkish",
                                    "Orange","Yellow","Light green",
                                    "Dark green","Dark grey"),
  `red and light blue` = bhf_cols("Bright Red", "Light Blue")
)

bhf_pal<- function(palette = "reds", reverse = FALSE, ...) {
  pal <- bhf_palettes[[palette]]
  if(reverse) pal <- rev(pal)
  colorRampPalette(pal,...)
}

#Create scale_colour and scale_fill functions

scale_color_bhf <- function(palette = "reds", discrete = TRUE, reverse = FALSE, ...) {
  pal <- bhf_pal(palette = palette, reverse = reverse)
  
  if (discrete) {
    discrete_scale("colour", paste0("bhf_", palette), palette = pal, ...)
  } else {
    scale_color_gradientn(colours = pal(256), ...)
  }
}


scale_fill_bhf <- function(palette = "reds", discrete = TRUE, reverse = FALSE, ...) {
  pal <- bhf_pal(palette = palette, reverse = reverse)
  
  if (discrete) {
    discrete_scale("fill", paste0("bhf_", palette), palette = pal, ...)
  } else {
    scale_fill_gradientn(colours = pal(256), ...)
  }
}


scale_fill_bhf_cont <- function(palette = "reds", discrete = FALSE, reverse = TRUE, ...) {
  pal <- bhf_pal(palette = palette, reverse = reverse)
  
  if (discrete) {
    discrete_scale("fill", paste0("bhf_", palette), palette = pal, ...)
  } else {
    scale_fill_gradientn(colours = pal(256), ...)
  }
}

##BUILD FORMATTING FUNCTION##


#BHF everything 

bhf_style <- function (bhf_brand,textsize=10) 
{
  
  ggplot2::theme(plot.title = ggplot2::element_text(family = "bhf_beats_bold", 
                                                    size = textsize+2, color = "#191919"), plot.subtitle = ggplot2::element_text(family = "bhf_beats_reg", 
                                                                                                                                 size = textsize, margin = ggplot2::margin(9, 0, 9, 0)),  
                 legend.position = "right", legend.text.align = 0, legend.background = ggplot2::element_blank(), 
                 #legend.title = ggplot2::element_blank(), legend.key = ggplot2::element_blank(), 
                 legend.text = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                     color = "#191919"),  
                 axis.text = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                   color = "#191919"), axis.ticks = ggplot2::element_blank(),
                 axis.title.x = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                      color = "#191919"),
                 axis.title.y = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                      color = "#191919"))#,
  #axis.line = ggplot2::element_blank(), 
  #panel.grid.minor = ggplot2::element_blank(), 
  # panel.grid.major.y = ggplot2::element_line(color = "#e6e6e6"), 
  #panel.grid.major.x = ggplot2::element_blank(), panel.background = ggplot2::element_blank(), 
  #strip.background = ggplot2::element_rect(fill = "white"), 
  #strip.text = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, hjust = 0))
}

bhf_map_style <- function (bhf_brand,textsize=10) 
{
  
  ggplot2::theme(plot.title = ggplot2::element_text(family = "bhf_beats_bold", 
                                                    size = textsize+2, color = "#191919"), plot.subtitle = ggplot2::element_text(family = "bhf_beats_reg", 
                                                                                                                                 size = textsize, margin = ggplot2::margin(9, 0, 9, 0)),  
                 legend.position = "right", legend.text.align = 0, legend.background = ggplot2::element_blank(), 
                 #legend.title = ggplot2::element_blank(), legend.key = ggplot2::element_blank(), 
                 legend.text = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                     color = "#191919"),  
                 axis.text = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                   color = "#191919"), axis.ticks = ggplot2::element_blank(),
                 axis.title.x = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                      color = "#191919"),
                 axis.title.y = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, 
                                                      color = "#191919"),
                 axis.line = ggplot2::element_blank(), 
                 panel.grid.minor = ggplot2::element_blank(), 
                 # panel.grid.major.y = ggplot2::element_line(color = "#e6e6e6"), 
                 panel.grid.major.x = ggplot2::element_blank(), panel.background = ggplot2::element_blank(), 
                 strip.background = ggplot2::element_rect(fill = "white")) 
  #strip.text = ggplot2::element_text(family = "bhf_ginger_reg", size = textsize, hjust = 0))
}

####### Section 2 - Set working directory ######
setwd('C:/Users/almondth/OneDrive - British Heart Foundation/Documents/Projects/Health Inequalities/Scotland')

##### Section 3.1.1 - Physical activity ####
## Read the physical activity data, and then set the factor levels for Categories and SIMD
activity_data <- read.csv("Scotland physical activity data.csv")
activity_data$Categories <- factor(activity_data$Categories, levels = c("Meets recommendations", "Some activity", "Low activity", "Very low activity"))
activity_data$SIMD <- factor(activity_data$SIMD, levels = c("1", "2", "3", "4", "5"))

# Plot highlighting most and least deprived SIMDs within 4x4 faceted time series

activity_time_series_2 <- ggplot(activity_data, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD)) +
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Categories) +
  bhf_style() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8))) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  labs(title = str_wrap("Activity levels of Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       subtitle = "1 = most deprived, 5 = least deprived",
       caption = "Source: Data from Scottish Health Survey\n Physical activity weekly guidelines: Recommended 150+ mins, Some = 60 to <150 mins,
       Low = 30 to <60 mins, Very low = 0 to <30 mins\n
       *Please note that there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic")

activity_time_series_2

## Plot showing just those meeting activity requirements and those who have 'very low' activity - This version is used in report.

activity_data2 <- activity_data %>%
  filter(Categories != "Some activity") %>%
  filter(Categories != "Low activity")

activity_time_series_3 <- ggplot(activity_data2, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD)) +
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Categories) +
  bhf_style() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  labs(title = str_wrap("Activity levels of Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       #subtitle = "1 = most deprived, 5 = least deprived",
       caption = "Source: Data from Scottish Health Survey\n Physical activity weekly guidelines: Recommended 150+ mins, Some = 60 to <150 mins,
       Low = 30 to <60 mins, Very low = 0 to <30 mins\n
       *Please note that there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic") +
  theme(plot.caption.position = "plot")

activity_time_series_3


#### Section 3.1.2 - Fruit and vegetables ####
## Read the fruit and veg data, and then set the factor levels for Categories and SIMD
fruit_veg_data <- read.csv("Fruit_veg_data.csv")
fruit_veg_data$Categories <- factor(fruit_veg_data$Categories, levels = c("5 portions or more", "Less than 5 portions", "None"))
fruit_veg_data$SIMD <- factor(fruit_veg_data$SIMD, levels = c("1", "2", "3", "4", "5"))


supp.labs <- c("5 portions or more", "Fewer than 5 portions", "None")
names(supp.labs) <- c("5 portions or more", "Less than 5 portions", "None")

## plot of fruit and veg consumotion
fruit_veg_time_series <- ggplot(fruit_veg_data, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD)) +
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Categories, labeller = labeller(Categories = supp.labs)) +
  bhf_style() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 1), guide = "none") +
  labs(title = str_wrap("Fruit and vegetable consumption by Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       #subtitle = "1 = most deprived, 5 = least deprived",
       caption = "Source: Data from Scottish Health Survey\n
       *Please note there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic") +
  theme(plot.caption.position = "plot")

fruit_veg_time_series

#### Section 3.1.3 - Smoking status ####
## Read the smoking data, and then set the factor levels for Categories and SIMD
smoking_status_data <- read.csv("smoking_status_data.csv")
smoking_status_data$Categories <- factor(smoking_status_data$Categories, levels = c("Never smoked/Used to smoke occasionally", "Used to smoke regularly",  "Current smoker"))
smoking_status_data$SIMD <- factor(smoking_status_data$SIMD, levels = c("1", "2", "3", "4", "5"))

## time series smoking plot with all smoking categories
smoking_plot <- ggplot(smoking_status_data, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD))+
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Categories, labeller = labeller(Categories = label_wrap_gen(width = 25))) +
  bhf_style() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8))) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 1), guide = "none") +
  labs(title = str_wrap("Smoking status of Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       subtitle = "1 = most deprived, 5 = least deprived",
       caption = "Source: Data from Scottish Health Survey\n
       *Please note there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic")
smoking_plot

## time series smoking polot with past smokers removed. This is version in the report.
smoking_status_data_cropped <- smoking_status_data %>%
  filter(Categories != "Used to smoke regularly")

smoking_plot2 <- ggplot(smoking_status_data_cropped, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD))+
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Categories, labeller = labeller(Categories = label_wrap_gen(width = 25))) +
  bhf_style() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 1), guide = "none") +
  labs(title = str_wrap("Smoking status of Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       #subtitle = "1 = most deprived, 5 = least deprived",
       caption = "Source: Data from Scottish Health Survey\n
       *Please note there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic") +
  theme(plot.caption.position = "plot")
smoking_plot2


#### Section 3.1.4 - BMI ####
## Read the BMI data, and then set the factor levels for Categories and SIMD
BMI_data <- read.xlsx("BMI_data.xlsx")
BMI_data$Categories <- factor(BMI_data$Categories, levels = c("Healthy weight", "Overweight (including obese)",  "Obese", "Morbidly obese"))
BMI_data$SIMD <- factor(BMI_data$SIMD, levels = c("1", "2", "3", "4", "5"))

## BMI plot
BMI_plot <- ggplot(BMI_data, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD))+
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Categories, labeller = labeller(Categories = label_wrap_gen(width = 25))) +
  bhf_style() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  labs(title = str_wrap("BMI category of Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       #subtitle = "1 = most deprived, 5 = least deprived",
       caption = "Source: Data from Scottish Health Survey\n
       *Please note there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic") +
  theme(plot.caption.position = "plot")
BMI_plot




