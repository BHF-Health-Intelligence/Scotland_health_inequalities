### This script produces the plots for the outcomes sections of the BHF's Socioeconomic Health Inequalities in Scotland report
### Data is sourced from a number of sources, including: National Records of Scotland, the Scottish Health Survey, and Scottish Government. Full details avaiable in associated report.
### Note: some manual cleaning in Excel was done, and these files are used for the script.
### These files are: 
#Scotland_Outcomes_2023_R_Version.xlsx
#CVD_SIMD_data.csv
#Scotland_heart_attack_admissions.xlsx
#Scotland_CHD_mortality_prem.xlsx
#life_expectancy_data_scotland.xlsx
#life_expectancy_scotland_time_series.csv
#Healthy_life_deciles.xlsx
#healthy_life_expectancy.xlsx

### Code structure (after loading necessary packages)
### Section 1 creates the custom BHF style functions for the plots (this requires access to our custom fonts)
### Section 2 sets the working directory (this will need amending to run locally if you're using the code)
### Section 3 reads and cleans the data, then creates the plots; with subsections of code taking different outcomes in turn.
### 3.1 contains analysis that does not feature in the report itself, but provides alternative views of data relating to outcomes and SIMD
#### 3.2 contains the plots featured in the actual report

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

#Beats  Will need to update local file location for .otf font files

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

##### Section 3 - Data cleaning and analysis #####

## Read the data containing data on life expectancy and premature CVD ASMRs, as well as SIMD ranks, by local authority
main_data <- read.xlsx("Scotland_Outcomes_2023_R_Version.xlsx")
main_data$LE_Year <- factor(main_data$LE_Year, levels = c("2013/15", "2014/16", "2015/17", "2016/18", "2017/19", "2018/20", "2019/21"))

#### Section 3.1 Initial analysis - Most the plots in this section were exploratory analysis, and did not make it into the report ####

## filter the data for the most recent reporting three-year average
data_2019_21 <- main_data %>%
  filter(LE_Year == "2019/21")

# Create plot showing male life expectancy at birth by LA and SIMD rank
LE_data_2019_21 <- data_2019_21 %>%
  subset(select = c("SIMD_Rank_2020", "LA", "LE_Female", "LE_Male")) %>%
  pivot_longer(cols = -c(SIMD_Rank_2020, LA), names_to = "Sex", values_to = "Life_expectancy")
LE_data_2019_21$Sex <- sub("LE_","",LE_data_2019_21$Sex)

LE_male_2019_21_plot <- ggplot(data_2019_21, aes(SIMD_Rank_2020, LE_Male)) +
  geom_point() +
  labs(title = "Male life expectany at birth, by local authority SIMD rank, 2019/21",
       subtitle = "1 = most deprived, 32 = least deprived",
       x = "SIMD Rank (2020)", y = "Life expectancy at birth") +
  bhf_style()
 
LE_male_2019_21_plot

# Create plot showing female life expectancy at birth by LA and SIMD rank
LE_female_2019_21_plot <- ggplot(data_2019_21, aes(SIMD_Rank_2020, LE_Female)) +
  geom_point() +
  labs(title = "Female life expectany at birth, by local authority SIMD rank, 2019/21",
       subtitle = "1 = most deprived, 32 = least deprived",
       x = "SIMD Rank (2020)", y = "Life expectancy at birth") +
  bhf_style()

LE_female_2019_21_plot

LE_male_female_2019_21_plot <- ggplot(LE_data_2019_21, aes(SIMD_Rank_2020, Life_expectancy)) +
  geom_point()+
  facet_wrap(~Sex) +
  labs(title = "Life expectany at birth, by local authority SIMD rank, 2019/21",
       subtitle = "1 = most deprived, 32 = least deprived",
       x = "SIMD Rank (2020)", y = "Life expectancy at birth") +
  bhf_style()
LE_male_female_2019_21_plot

# Create a plot showing LE over time for males by LA and SIMD rank with a trend line
LE_male_plot <- ggplot(main_data, aes(SIMD_Rank_2020, LE_Male)) +
  geom_point(aes(color = LE_Year)) +
  scale_color_brewer(palette = "Reds") +
  labs(title = "Male life expectany at birth, by local authority SIMD rank",
       subtitle = "1 = most deprived, 32 = least deprived",
       x = "SIMD Rank (2020)", y = "Life expectancy at birth") +
  stat_smooth () +
  bhf_style()

LE_male_plot

# Create a plot showing LE over time for females by LA and SIMD rank with a trend line
LE_female_plot <- ggplot(main_data, aes(SIMD_Rank_2020, LE_Female)) +
  geom_point(aes(color = LE_Year)) +
  scale_color_brewer(palette = "Reds") +
  labs(title = "Female life expectany at birth, by local authority SIMD rank",
       subtitle = "1 = most deprived, 32 = least deprived",
       x = "SIMD Rank (2020)", y = "Life expectancy at birth") +
  stat_smooth () +
  bhf_style()

LE_female_plot

### Graphs comparing 2013/15 with 2019/21
# Graph comparing male LE in 2013/15 with 2019/21 by LA SIMD Rank
data_past_recent <- main_data %>%
  filter(LE_Year == "2013/15" | LE_Year == "2019/21")

LE_male_plot_2 <- ggplot(data_past_recent, aes(SIMD_Rank_2020, LE_Male)) +
  geom_point(aes(color = LE_Year)) +
  geom_line(aes(group = SIMD_Rank_2020), alpha = 0.4) +
  scale_color_bhf(palette = "red and light blue") +
  labs(title = "Male life expectany at birth, by local authority SIMD rank",
       subtitle = "1 = most deprived, 32 = least deprived",
       x = "SIMD Rank (2020)", y = "Life expectancy at birth") +
  bhf_style()
LE_male_plot_2 

# Graph comparing female LE in 2013/15 with 2019/21 by LA SIMD Rank
LE_female_plot_2 <- ggplot(data_past_recent, aes(SIMD_Rank_2020, LE_Female)) +
  geom_point(aes(color = LE_Year)) +
  geom_line(aes(group = SIMD_Rank_2020), alpha = 0.4) +
  scale_color_bhf(palette = "red and light blue") +
  labs(title = "Female life expectany at birth, by local authority SIMD rank",
       subtitle = "1 = most deprived, 32 = least deprived",
       x = "SIMD Rank (2020)", y = "Life expectancy at birth") +
  bhf_style()
LE_female_plot_2 


#ASMR graphs 
#### ASMR by Local Authority 
##### Section 3.2 Plots from the report itself ####
##### CVD by SIMD quintile ###
## Read the data and set SIMD factor levels
CVD_main_data <- read.csv("CVD_SIMD_data.csv")
CVD_main_data$SIMD <- factor(CVD_main_data$SIMD, levels = c("1", "2", "3", "4", "5"))
## Produce faceted time series plot of CVD and high risk condition prevalence
CVD_main_plot <- ggplot(CVD_main_data, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD))+
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Indicator, labeller = labeller(Indicator = label_wrap_gen(width = 25)), ncol = 3) +
  bhf_style() +
  theme(strip.text = element_text(size = 10.5))+
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8))) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 1), guide = "none") +
  labs(title = str_wrap("Self-reported doctor-diagnosed prevalence of cardiovascular diseases and risk factors amongst Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       subtitle = "1 = most deprived, 5 = least deprived",
       caption = str_wrap("Source: Data from Scottish Health Survey\n       
       *Please note that there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic\n
       **'Any cardiovascular condition' is derived from respondents being asked if they have ever had high blood pressure, angina, heart attack, heart murmur, abnormal heart rhythm or other heart trouble.",120)) +
  theme(legend.position="bottom")
CVD_main_plot

## Create an alternative plot with 'other heart conditions' removed
## Create alternative data frame without 'other heart conditions'
CVD_main_data2 <- CVD_main_data %>% filter(Indicator != "Doctor-diagnosed other heart condition")

## Produce faceted time series plot of CVD and high risk condition prevalence (minus 'other heart conditions')
CVD_main_plot2 <- ggplot(CVD_main_data2, aes(Year, Percent, color = SIMD, group = SIMD, alpha = SIMD))+
  geom_line(lwd=1.3) +
  geom_point() +
  facet_wrap(~Indicator, labeller = labeller(Indicator = label_wrap_gen(width = 25)), ncol = 3) +
  bhf_style() +
  theme(strip.text = element_text(size = 10.5))+
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8))) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 1), guide = "none") +
  labs(title = str_wrap("Self-reported doctor-diagnosed prevalence of cardiovascular diseases and risk factors amongst Scottish adults in 2012-2021*, by Scottish Index of Multiple Deprivation (SIMD) quintile", 100),
       subtitle = "1 = most deprived, 5 = least deprived",
       caption = str_wrap("Source: Data from Scottish Health Survey\n       
       *Please note that there is no data for 2020, as the Scottish Health Survey was suspended due to the Covid-19 pandemic\n
       **'Any cardiovascular condition' is derived from respondents being asked if they have ever had high blood pressure, angina, heart attack, heart murmur, abnormal heart rhythm or other heart trouble.",120)) +
  theme(legend.position="bottom")
CVD_main_plot2


#### Heart attack admissions plot ###

heart_attack_stats <- read.xlsx("Scotland_heart_attack_admissions.xlsx")
heart_attack_stats <- heart_attack_stats %>%
  pivot_longer(!Year, names_to = "IEI_Decile", values_to = "Rate")
heart_attack_stats$IEI_Decile <- factor(heart_attack_stats$IEI_Decile, levels = c("1","2", "3", "4", "5","6","7","8","9","10"))

heart_attack_plot <- ggplot(heart_attack_stats, aes(Year, Rate, color = IEI_Decile, alpha = IEI_Decile)) +
  geom_line(size = 1.5) +
  bhf_style() +
  scale_color_bhf(palette = "red and light blue", name = "IEI decile", labels = c("1 = most deprived", "2", "3", "4", "5", "6", "7", "8", "9", "10 = least deprived")) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 0.4,0.4,0.4,0.4, 0.4, 1), guide = "none") +
  labs(title = str_wrap("Inequalities in first ever hospital admission for heart attack aged under 75 (rate per 100,000 population), by Income Employment Index (IEI) deciles",100),
       #subtitle = "1 = most deprived, 10 = least deprived", 
       x = "Year", y = "Rate per 100,000 population",
       caption = "Data source: Scottish Government") +
  scale_x_continuous(breaks = seq(1997, 2021, by = 2)) +
  scale_y_continuous(limits = c(0,225)) +
  theme(panel.grid.minor.x = element_blank()) +
  theme(plot.caption.position = "plot")

heart_attack_plot

### prem CHD mortality by IEI ###

CHD_45to74 <- read.xlsx("Scotland_CHD_mortality_prem.xlsx")
CHD_45to74 <- CHD_45to74 %>%
  pivot_longer(!Year, names_to = "IEI_Decile", values_to = "Rate")
CHD_45to74$IEI_Decile <- factor(CHD_45to74$IEI_Decile, levels = c("1","2", "3", "4", "5","6","7","8","9","10"))


CHD45to74_plot <- ggplot(CHD_45to74, aes(Year, Rate, color = IEI_Decile, alpha = IEI_Decile)) +
  geom_line(size = 1.5) +
  bhf_style() +
  scale_color_bhf(palette = "red and light blue", name = "IEI decile", labels = c("1 = most deprived", "2", "3", "4", "5", "6", "7", "8", "9", "10 = least deprived")) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 0.4,0.4,0.4,0.4, 0.4, 1), guide = "none") +
  labs(title = str_wrap("Inequalities in coronary heart disease (CHD) mortality aged 45 to 74 (rate per 100,000 population), by Income Employment Index (IEI) deciles",100),
       #subtitle = "1 = most deprived, 10 = least deprived", x = "Year", y = "Rate per 100,000 population",
       caption = "Data source: Scottish Government") +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  scale_x_continuous(breaks = seq(1997, 2021, by = 2)) +
  theme(panel.grid.minor.x = element_blank()) +
  theme(plot.caption.position = "plot")

CHD45to74_plot

### Life expectancy plots

## Life expectancy in 2019-21 by SIMD
## Read the life expectancy at birth data and order SIMD as a factor
life_expectancy_data <- read.xlsx("life_expectancy_data_scotland.xlsx")
life_expectancy_data$SIMD_Decile <- as.factor(life_expectancy_data$SIMD_Decile)

## Create a bar plot (faceted by gender) showing life expectancy by SIMD decile for 2019-21
life_expectancy_plot <- ggplot(life_expectancy_data, aes(SIMD_Decile, Life_expectancy, fill = SIMD_Decile)) +
  geom_bar(stat = "identity") +
  facet_wrap(~Sex) +
  bhf_style() +
  theme(plot.background = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_blank(),
        legend.position = "none") +
  geom_text(aes(label = sprintf("%0.1f", Life_expectancy)), vjust = -0.2, size = 3.8) +
  labs(title = str_wrap("Life expectancy at birth in Scotland (2019-21) by Scottish Index of Multiple Deprivation (SIMD) decile", 100),
       subtitle = "1 = most deprived, 10 = least deprived",
       x = "SIMD Decile", y = "Life expectancy at birth",
       caption = "Data source: National Records of Scotland") +
  scale_y_continuous(breaks = seq(0, 90, len = 10), limits=c(0,90), expand = c(0, 0)) +
  scale_fill_manual(values = c("#FF0030", "#474E5A", "#474E5A","#474E5A","#474E5A","#474E5A","#474E5A","#474E5A","#474E5A", "#2D91FF"))

life_expectancy_plot


#### Life expectancy time series ###

LE_data_time_series <- read.csv("life_expectancy_scotland_time_series.csv")
LE_data_time_series$DateCode <- factor(LE_data_time_series$DateCode, levels = c("2001-2003", "2002-2004", "2003-2005", "2004-2006", "2005-2007",
                                                                                "2006-2008", "2007-2009", "2008-2010", "2009-2011", "2010-2012",
                                                                                "2011-2013", "2012-2014", "2013-2015", "2014-2016", "2015-2017",
                                                                                "2016-2018", "2017-2019", "2018-2020", "2019-2021"))

LE_time_series_plot <- ggplot(LE_data_time_series, aes(DateCode, Value, color = SIMD_quintile, group = SIMD_quintile)) +
  geom_line(size = 1.5) +
  geom_point(size = 1.5) +
  facet_wrap(~Sex) +
  bhf_style() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  labs(title = "Life expectancy at birth in Scotland by Scottish Index of Multiple Deprivation (SIMD) decile",
       x = "Time period", y = "Life expectancy at birth",
       caption = "Data source: National Records of Scotland") +
  scale_color_bhf(palette = "red and light blue", name = "SIMD quintile")
  
LE_time_series_plot

### healthy life expectancy ###

healthy_life_data <- read.xlsx("healthy_life_expectancy.xlsx")
healthy_life_data$DateCode <- factor(healthy_life_data$DateCode, levels = c("2015-2017","2016-2018", "2017-2019", "2018-2020", "2019-2021"))
healthy_life_data$SIMD_quintile <- factor(healthy_life_data$SIMD_quintile, levels = c("1 - most deprived","2", "3", "4", "5 - least deprived"))

healthy_life_time_series_plot <- ggplot(healthy_life_data, aes(DateCode, Value, color = SIMD_quintile, group = SIMD_quintile)) +
  geom_line(size = 1.5) +
  geom_point(size = 1.5) +
  facet_wrap(~Sex) +
  bhf_style() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  labs(title = "Healthy life expectancy at birth in Scotland by Scottish Index of Multiple Deprivation (SIMD) quintile",
       x = "Time period", y = "Healthy life expectancy at birth",
       caption = "Data source: National Records of Scotland") +
  scale_color_bhf(palette = "red and light blue", name = "SIMD quintile") +
  scale_y_continuous(limits=c(20,80))

healthy_life_time_series_plot

# Plot with middle SIMDs made transparent
healthy_life_time_series_plot2 <- ggplot(healthy_life_data, aes(DateCode, Value, color = SIMD_quintile, group = SIMD_quintile, alpha = SIMD_quintile)) +
  geom_line(size = 1.5) +
  geom_point(size = 1.5) +
  facet_wrap(~Sex) +
  bhf_style() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  labs(title = "Healthy life expectancy at birth in Scotland by Scottish Index of Multiple Deprivation (SIMD) decile",
       x = "Time period", y = "Healthy life expectancy at birth",
       caption = "Data source: National Records of Scotland") +
  scale_color_bhf(palette = "red and light blue", name = "SIMD quintile") +
  scale_alpha_manual(values=c(1,0.6,0.6,0.6, 1), guide = "none")

healthy_life_time_series_plot2


### HLE decile data ### 

HLE_deciles <- read.xlsx("Healthy_life_deciles.xlsx")
HLE_deciles$SIMD_decile <- factor(HLE_deciles$SIMD_decile, levels = c("1","2", "3", "4", "5","6","7","8","9","10"))

HLE_deciles_plot <- ggplot(HLE_deciles, aes(SIMD_decile, HLE, fill = SIMD_decile)) +
  geom_bar(stat = "identity") +
  facet_wrap(~Sex) +
  bhf_style() +
  labs(title = str_wrap("Healthy life expectancy at birth in Scotland, 2019-21, by Scottish Index of Multiple Deprivation decile", 100),
       subtitle = "1 = most deprived, 10 = least deprived", x = "SIMD Decile", y = "Healthy life expectancy (years)",
       caption = "Data source: Scottish Government") +
  scale_fill_manual(values = c("#FF0030", "#474E5A", "#474E5A","#474E5A","#474E5A","#474E5A","#474E5A","#474E5A","#474E5A", "#2D91FF")) +
  geom_text(aes(label = sprintf("%0.1f", HLE)), vjust = -0.2, size = 3.8) +
  theme(plot.background = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_blank(),
        legend.position = "none")
  
HLE_deciles_plot

HLE_deciles_plot2 <- ggplot(HLE_deciles, aes(SIMD_decile, Perc_good_health, fill = SIMD_decile)) +
  geom_col() +
  facet_wrap(~Sex) +
  bhf_style() +
  labs(title = str_wrap("Percentage of life estimated to be spent in good health in Scotland, 2019-21, by Scottish Index of Multiple Deprivation decile", 100),
       subtitle = "1 = most deprived, 10 = least deprived", x = "SIMD Decile", y = "Percentage of life spent in good health (%)",
       caption = "Data source: Scottish Government") +
  scale_fill_manual(values = c("#FF0030", "#474E5A", "#474E5A","#474E5A","#474E5A","#474E5A","#474E5A","#474E5A","#474E5A", "#2D91FF")) +
  geom_text(aes(label = ifelse(SIMD_decile == "1" | SIMD_decile == "10", (sprintf("%0.0f%%", Perc_good_health)),""), vjust = -0.2, size = 3.8)) +
  theme(plot.background = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_blank(),
        legend.position = "none",
        axis.text.y=element_blank(),
        axis.ticks.y=element_blank()) +
  scale_y_continuous()

HLE_deciles_plot2