#!/usr/bin/env RScript

url = "https://en.wikipedia.org/wiki/List_of_restriction_enzyme_cutting_sites:_Ba-Bc#Whole_list_navigation"

args <- commandArgs(TRUE)
if (length(args) != 2) {
  stop("Missing argument: URL OutputFile\n")
}
url     <- args[[1]]  
output  <- args[[2]]

library(tidyverse)
library(rvest)

html  = read_html(url)


tables = html %>% 
  html_nodes(css = "table") 

filt = tables %>% 
  html_nodes(css = "sortable") %>% 
  html_table(fill = TRUE)

View(tables)
table <- tables[ -c(2:3) ]
colnames(table) <- c("enzyme", "source", "seq", "cut", "isoschizomers")
table$enzyme <- sub("\\[.+\\]", "", table$enzyme)
write.csv(table, output)
