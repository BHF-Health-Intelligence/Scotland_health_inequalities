### This script produces the plots for the hospital-related sections of the BHF's Socioeconomic Health Inequalities in Scotland report
### Data is sourced from a number of sources, including: NHS Scotland, National Records of Scotland, the Scottish Health Survey, and Scottish Government. Full details available in associated report.
### Note: some manual cleaning in Excel was done, and these files are used for the script.
### These files are: 
#outpatients-by-nhs-board-of-residence-and-simd-to-december-2022-new
#HB_population_by_simd.xlsx
#inpatient_data.xlsx

### Code structure (after loading necessary packages)
### Section 1 creates the custom BHF style functions for the plots (this requires access to our custom fonts)
### Section 2 sets the working directory (this will need amending to run locally if you're using the code)
### Section 3 reads, cleans, and analyses the data.
### 3.1 Outpatient
### 3.2 Inpatient
### 3.3 Day cases

options(scipen = 999)
library(openxlsx)
library(tidyverse)
library(magrittr)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
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
library(patchwork)
library(chron)
library(readODS)
library(lubridate)
library(sf)
library(geojsonsf)
library(gginnards)

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

##### Section 3 - Read the data #####

## Section 3.1 Outpatient data
# Read the outpatient data
outpatient_data <- read.csv("outpatients-by-nhs-board-of-residence-and-simd-to-december-2022-new.csv")

### Clean the outpatient data, by reducing the number of time periods - > group into years -> make wide to allow rates to be calculated
outpatient_data <- outpatient_data %>%
  group_by(year, hb_code, hb_name, simd, appt_type) %>%
  summarise(count = (sum(count))) %>%
  pivot_wider(names_from = appt_type, values_from = count)

### Create the outpatient data set used for national-level analysis 
outpatient_year_national_data <- outpatient_data %>%
  filter(hb_name == "Scotland") %>%
  mutate(rate = DNA/New) %>%
  filter(year != 2017)
outpatient_year_national_data <- outpatient_year_national_data[!(is.na(outpatient_year_national_data$simd)), ]

outpatient_plot_1 <- ggplot(outpatient_year_national_data, aes(simd, rate)) +
  geom_col() +
  facet_wrap(~year) +
  labs(title = str_wrap("Percentage of new outpatient appointments (all specialties) in Scotland which were 'Did Not Attend (DNA)' appointments, by patients' SIMD quintile, and year", 100),
                subtitle = "1 = most deprived, 5 = least deprived", 
                y = "Percentage of appointments that were DNA", x = "SIMD Quintile",
                caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  bhf_style()
outpatient_plot_1

## Separate the data for 2022
outpatient_data_2022 <- outpatient_data %>%
  filter(year == "2022") %>%
  summarise(DNA = sum(DNA), New = sum(New)) %>%
  mutate(rate = DNA/New)
outpatient_data_2022 <- outpatient_data_2022[!(is.na(outpatient_data_2022$simd)), ]

# Plot the 2022 data for DNAs by health board
outpatient_plot_2 <- ggplot(outpatient_data_2022, aes(simd, rate)) +
  geom_col() +
  facet_wrap(~hb_name) +
  labs(title = str_wrap("Percentage of new outpatient appointments (all specialties) in Scotland in 2022 which were 'Did Not Attend (DNA)' appointments, by patients' SIMD quintile, and health board", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Percentage of appointments that were DNA", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data. \n Outpatients grouped by board of residence.") +
  bhf_style()
outpatient_plot_2


### outpatient line plots
outpatient_year_national_data$simd <- factor(outpatient_year_national_data$simd, levels = c("1", "2", "3", "4", "5"))

### Outpatient DNAs over time plot
outpatient_plot_1 <- ggplot(outpatient_year_national_data, aes(year, rate, group = simd, color = simd, alpha = simd)) +
  geom_line(lwd=1.3) +
  geom_point() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  labs(title = str_wrap("Percentage of new outpatient appointments (all specialties) in Scotland which were 'Did Not Attend (DNA)' appointments, by patients' SIMD quintile, and year", 100),
       #subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Percentage of appointments that were DNA", x = "Year",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  bhf_style() +
  theme(plot.caption.position = "plot") +
  scale_y_continuous(labels = percent, limits = c(0,0.3))
  
outpatient_plot_1

### Outpatient time series plot - national
outpatient_plot_2_5 <- ggplot(outpatient_year_national_data, aes(year, New, group = simd, color = simd, alpha = simd)) +
  geom_point() +
  geom_line(lwd=1.3) +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.4,0.4,0.4, 1), guide = "none") +
  labs(title = str_wrap("Number of new outpatient appointments (all specialties) in Scotland by year and patients' SIMD quintile", 100),
       #subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Number of new outpatient appointments", x = "Year",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  bhf_style() +
  scale_y_continuous(label=comma, limits = c(0,400000)) +
  theme(plot.caption.position = "plot")
outpatient_plot_2_5

### Import the Health Board SIMD population data

HB_pop <- read.xlsx("HB_population_by_simd.xlsx")
HB_pop <- HB_pop %>%
  group_by(HB_area, SIMD_quintile, hb_code) %>%
  summarise(population = sum(Population))

### Calculate number of outpatient appointments per person in 2022 by health board

outpatient_data_matched_2022 <- outpatient_data_2022 %>%
  inner_join(HB_pop, by = c('hb_code' = 'hb_code', 'simd' = 'SIMD_quintile')) %>%
  mutate(appointments_per_pop = New / population)
  
### Plot new outpatient appointments per person for 2022
outpatient_plot_3 <- ggplot(outpatient_data_matched_2022, aes(simd, appointments_per_pop)) +
  geom_col() + 
  facet_wrap(~hb_name) +
  labs(title = str_wrap("Number of new outpatient appointments (all specialties) per person in Scotland in 2022, and health board of residence", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Percentage of appointments that were DNA", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data. \n Outpatients grouped by board of residence.") +
  bhf_style()
outpatient_plot_3

### Calculate number of outpatient appointments per 1,000 population in 2022 by health board

outpatient_data_matched_2022 <- outpatient_data_matched_2022 %>%
  mutate(appointments_per_thousand = appointments_per_pop * 1000)

### Plot new outpatient appointments per 1,000 population for 2022 by health board

outpatient_plot_4 <- ggplot(outpatient_data_matched_2022, aes(simd, appointments_per_thousand)) +
  geom_col() + 
  facet_wrap(~hb_name) +
  labs(title = str_wrap("Number of new outpatient appointments (all specialties) per 1,000 population in Scotland in 2022, by health board of residence and SIMD quintile", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Percentage of appointments that were DNA", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data. \n Outpatients grouped by board of residence.") +
  bhf_style()
outpatient_plot_4


##### Section 3.2. Inpatient data section ####

# Read inpatient data
inpatient_data <- read.xlsx("inpatient_data.xlsx")

# summarise inpatient data by year, health board, measure, and SIMD
inpatient_data <- inpatient_data %>%
  group_by(year, hb_code, hb_name, measure, simd) %>%
  summarise(eps = sum(eps), los = sum(los)) %>%
  mutate(alos = los / eps)

# filter for emergency inpatients and just the national data, then remove the oldest year from the data
emergency_inpatients_national <- inpatient_data %>%
  filter(measure == "Emergency Inpatients" & hb_name == "Scotland" & year != "2017")

# plot emergency inpatient data in bar chart format by SIMD quintile and year
plot_emergency_inpatients_national <- ggplot(emergency_inpatients_national, aes(simd, eps)) +
  geom_col() +
  facet_wrap(~year) +
  bhf_style() +
  scale_y_continuous(label = comma) +
  labs(title = str_wrap("Number of emergency inpatient episodes in Scotland by SIMD quintile and year", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "No. emergency inpatients", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.")
  plot_emergency_inpatients_national
  
### Length of emergency stay plot - total length of stay
plot_emergency_inpatients_national_los <- ggplot(emergency_inpatients_national, aes(simd, los)) +
    geom_col() +
    facet_wrap(~year) +
    bhf_style() +
    labs(title = str_wrap("Total length of stay (days) for emergency inpatients in Scotland by SIMD quintile and year", 100),
         subtitle = "1 = most deprived, 5 = least deprived", 
         y = "Length of stay (days)", x = "SIMD Quintile",
         caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  scale_y_continuous(label=comma)
  plot_emergency_inpatients_national_los

### Length of emergency stay plot - average length of stay  
plot_emergency_inpatients_national_alos <- ggplot(emergency_inpatients_national, aes(simd, alos)) +
    geom_col() +
    facet_wrap(~year) +
    bhf_style() +
    labs(title = str_wrap("Average length of stay (days) for emergency inpatients in Scotland by SIMD quintile and year", 100),
         subtitle = "1 = most deprived, 5 = least deprived", 
         y = "Length of stay (days)", x = "SIMD Quintile",
         caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.")
  plot_emergency_inpatients_national_alos


### Emergency line plots
  
# filter data for emergency inpatient at national level, remove 2017. Then make SIMD an ordered factor.  
  emergency_inpatients_national <- inpatient_data %>%
    filter(measure == "Emergency Inpatients" & hb_name == "Scotland" & year != "2017")
  emergency_inpatients_national$simd <- factor(emergency_inpatients_national$simd, levels = c("1", "2", "3", "4", "5"))
  
# plot number of emergency inpatient episodes by SIMD quintile and year   
  plot_emergency_inpatients_national <- ggplot(emergency_inpatients_national, aes(year, eps, group = simd, color = simd, alpha = simd)) +
    geom_line(lwd=1.3) +
    geom_point() +
    scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
    scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
    scale_y_continuous(label = comma, limits = c(0, 150000)) +
    bhf_style() +
    labs(title = str_wrap("Number of emergency inpatient episodes in Scotland by SIMD quintile and year", 100),
         #subtitle = "1 = most deprived, 5 = least deprived", 
         y = "No. emergency inpatients", x = "Year",
         caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
    theme(plot.caption.position = "plot")
  
  plot_emergency_inpatients_national
  
# Plot total length of stay for emergency inpatients by SIMD and year
  plot_emergency_inpatients_national_los <- ggplot(emergency_inpatients_national, aes(year, los, group = simd, color = simd, alpha = simd)) +
    geom_line(lwd=1.3) +
    geom_point() +
    scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
    scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
    bhf_style() +
    labs(title = str_wrap("Total length of stay (days) for emergency inpatients in Scotland by SIMD quintile and year", 100),
         #subtitle = "1 = most deprived, 5 = least deprived", 
         y = "Length of stay (days)", x = "Year",
         caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
    scale_y_continuous(label=comma, limits = c(0,350000)) +
    theme(plot.caption.position = "plot")
  plot_emergency_inpatients_national_los
  
# Plot average length of stay for emergency inpatients by SIMD and year
  
  plot_emergency_inpatients_national_alos <- ggplot(emergency_inpatients_national, aes(year, alos, group = simd, color = simd, alpha = simd)) +
    geom_line(lwd=1.3) +
    geom_point() +
    scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
    scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
    bhf_style() +
    labs(title = str_wrap("Average length of stay (days) for emergency inpatients in Scotland by SIMD quintile and year", 100),
         #subtitle = "1 = most deprived, 5 = least deprived", 
         y = "Length of stay (days)", x = "Year",
         caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
    theme(plot.caption.position = "plot") +
    scale_y_continuous(limits = c(0,3))
  plot_emergency_inpatients_national_alos
  
  
#### Elective inpatients ####
# read inpatient data, then filter for elective inpatients, national data only, and remove 2017 
elective_inpatients_national <- inpatient_data %>%
  filter(measure == "Elective Inpatients" & hb_name == "Scotland" & year != "2017")

# plot of elective episodes  
plot_elective_national_eps <- ggplot(elective_inpatients_national, aes(simd, eps)) +
  geom_col() +
  facet_wrap(~year) +
  bhf_style() +
  scale_y_continuous(label=comma) +
  labs(title = str_wrap("Number of elective inpatient episodes in Scotland by SIMD quintile and year", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "No. elective inpatients episodes", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.")
plot_elective_national_eps

# plot of elective length of stay
plot_elective_national_los <- ggplot(elective_inpatients_national, aes(simd, los)) +
  geom_col() +
  facet_wrap(~year) +
  bhf_style() +
  scale_y_continuous(label=comma) +
  labs(title = str_wrap("Total length of stay (days) of elective inpatient episodes in Scotland by SIMD quintile and year", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Length of elective inpatient episodes (days)", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.")
plot_elective_national_los

# plot of average elective length of stay
plot_elective_national_alos <- ggplot(elective_inpatients_national, aes(simd, alos)) +
  geom_col() +
  facet_wrap(~year) +
  bhf_style() +
  labs(title = str_wrap("Average length of stay (days) of elective inpatient episodes in Scotland by SIMD quintile and year", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Length of elective inpatient episodes (days)", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.")
plot_elective_national_alos

### elective line plots
elective_inpatients_national <- inpatient_data %>%
  filter(measure == "Elective Inpatients" & hb_name == "Scotland" & year != "2017")
elective_inpatients_national$simd <- factor(elective_inpatients_national$simd, levels = c("1", "2", "3", "4", "5"))

#line plot of elective episodes  
plot_elective_national_eps <- ggplot(elective_inpatients_national, aes(year, eps, group = simd, color = simd, alpha = simd)) +
  geom_line(lwd=1.3) +
  geom_point() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  bhf_style() +
  scale_y_continuous(label=comma, limits = c (0,30000)) +
  labs(title = str_wrap("Number of elective inpatient episodes in Scotland by SIMD quintile and year", 100),
       #subtitle = "1 = most deprived, 5 = least deprived", 
       y = "No. elective inpatients episodes", x = "Year",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  theme(plot.caption.position = "plot")
plot_elective_national_eps

# plot of elective length of stay
plot_elective_national_los <- ggplot(elective_inpatients_national, aes(year, los, group = simd, color = simd, alpha = simd)) +
  geom_line(lwd=1.3) +
  geom_point() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  bhf_style() +
  scale_y_continuous(label=comma, limits = c (0,80000)) +
  labs(title = str_wrap("Total length of stay (days) of elective inpatient episodes in Scotland by SIMD quintile and year", 100),
       #subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Length of elective inpatient episodes (days)", x = "Year",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  theme(plot.caption.position = "plot")
plot_elective_national_los

# plot of average elective length of stay
plot_elective_national_alos <- ggplot(elective_inpatients_national, aes(year, alos, group = simd, color = simd, alpha = simd)) +
  geom_line(lwd=1.3) +
  geom_point() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  bhf_style() +
  ylim(0, 3) +
  labs(title = str_wrap("Average length of stay (days) of elective inpatient episodes in Scotland by SIMD quintile and year", 100),
       #subtitle = "1 = most deprived, 5 = least deprived", 
       y = "Length of elective inpatient episodes (days)", x = "Year",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  theme(plot.caption.position = "plot")
plot_elective_national_alos


#### Sction 3.3. Day cases ####
# read the data and filter for day cases, national data, and remove 2017
day_cases_national <- inpatient_data %>%
  filter(measure == "All Day cases" & hb_name == "Scotland" & year != "2017")

# plots of all day cases  
# faceted bar plot
plot_day_cases_eps <- ggplot(day_cases_national, aes(simd, eps)) +
  geom_col() +
  facet_wrap(~year) +
  bhf_style() +
  scale_y_continuous(label=comma) +
  labs(title = str_wrap("Number of day cases in Scotland by SIMD quintile and year", 100),
       subtitle = "1 = most deprived, 5 = least deprived", 
       y = "No. day cases", x = "SIMD Quintile",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.")
plot_day_cases_eps

#line plot
day_cases_national <- inpatient_data %>%
  filter(measure == "All Day cases" & hb_name == "Scotland" & year != "2017")
day_cases_national$simd <- factor(day_cases_national$simd, levels = c("1", "2", "3", "4", "5"))


plot_day_cases_eps2 <- ggplot(day_cases_national, aes(year, eps, group = simd, color = simd, alpha = simd)) +
  geom_line(lwd=1.3) +
  geom_point() +
  scale_color_brewer(palette = "RdYlBu", name = "SIMD Quintile", guide = guide_legend(override.aes = list(size = 8)), labels = c("1 = most deprived", "2", "3", "4", "5 = least deprived")) +
  scale_alpha_manual(values=c(1,0.5,0.5,0.5, 1), guide = "none") +
  scale_y_continuous(label=comma, limits = c(0,100000)) +
  bhf_style() +
  labs(title = str_wrap("Number of day cases in Scotland by SIMD quintile and year", 100),
       #subtitle = "1 = most deprived, 5 = least deprived", 
       y = "No. day cases", x = "Year",
       caption = "Date source: Public Health Scotland \n Appointments for patients with residency outside of Scotland, with unknown residency, or no fixed abode excluded due to lack of SIMD data.") +
  theme(plot.caption.position = "plot")
plot_day_cases_eps2
