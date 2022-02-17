#!/usr/bin/env python3
"""
Extract enzyme table from wikipedia page
"""
#lxml
import pandas as pd
from bs4 import BeautifulSoup
from urllib.request import urlopen
import re
import os, sys



def siteString(site):
    # site: 5' GAATTC 3' CTTAAG
    # cutsite: 5' ---G   AATTC--- 3'  3' ---CTTAA   G--- 5'
    if type(site) != str:
        return ""
    
    # Extract the string from "5'" to "3'"
    regex = "5'(.*?)3'"
    # Find the cutsite
    cutsite = re.search(regex, site).group(1)
    # Strip leadingnad trailing whitespaces
    return cutsite.strip()

def cutPosition(string):
    #5' ---AT CGAT--- 3'
    regex = "5' [-]+(.+) (.+)[-]+ 3'"
    # Capture the two groups
    match = re.search(regex, string)
    if match:
        return len(match.group(1))#, match.group(2)
    else:
        return -1

def getTable(url, class_attributes=[]):
    # Get the page from url
    page = BeautifulSoup(urlopen(url), "html.parser")
    # Select tables containing all attributes in the list class_attributes
    tables = page.find_all("table", class_=class_attributes)
    columnName = "Enzyme"
    # Select the table from tables having columnName as column name
    table = [table for table in tables if columnName in table.find_all("tr")[0].text]
    # Return the table
    return table

def htmlTableToDataFrame(table):
    # Create a dataframe from the table
    df = pd.read_html(str(table))[0]
    # First row is the header
    df.columns = df.iloc[0]
    # Drop the first row
    df = df.drop(df.index[0])
    # First column is the enzyme name (index)
    df.index = df.iloc[:,0]
    # Drop the first column
    df = df.drop(df.columns[0], axis=1)
    return df

def urlToDf(url):
    
    table = getTable(url, ["sortable"])
    df = htmlTableToDataFrame(table[0])
    # From the first column strip the pattern "\[.*\]"
    df.index = df.index.str.replace("\[.*\]", "")
    
    # Columns to remove
    colToRemove = ["PDB code" ]
    
    # Check if colToRemove are in the dataframe
    for col in colToRemove:
        if col in df.columns:
            df = df.drop(col, axis=1)

    # Replace column "Recognition sequence" with siteString()
    df["Recognition sequence"] = df["Recognition sequence"].apply(siteString)
    # Remove rows where "Recognition sequence" is empty
    df = df[df["Recognition sequence"] != ""]

    # Replace "Cut" with cutPosition()
    df["Cut"] = df["Cut"].apply(cutPosition)
    # Drop rows where "Cut" is -1
    df = df[df["Cut"] != -1]

    return df

if __name__ == "__main__":
    inputfile = sys.argv[-1]
    if not os.path.exists(inputfile):
        print("ERROR: file not found: ", inputfile)
        sys.exit(1)
    
    # Load list of urls from file
    with open(inputfile, "r") as f:
        urls = f.readlines()
    dataframes = []
    for url in urls:
        
        if not url.startswith("http"):
            continue
        basename = os.path.basename(url)
        # Strip after "#"
        if "#" in basename:
            basename = basename.split("#")[0]
        if ":_" in basename:
            basename = basename.split(":_")[1]
        try:
            df = urlToDf(url)
            print(basename, df.shape, file=sys.stderr)
            # Replace nan values with empty string
            df = df.fillna("")
            df.to_markdown(basename + ".md")
            dataframes.append(df)
        except Exception as e:
            print(e)
        
    if len(dataframes) > 0:
        df = pd.concat(dataframes)
        print(df.shape)
        
        df.to_markdown("enzyme_table.md")
        df.to_csv("enzyme_table.csv")
            

