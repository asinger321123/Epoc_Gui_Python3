# To add a new cell, type ''
# To add a new markdown cell, type ' [markdown]'

import os
import sys
import pandas as pd
import snowflake.connector
import pandas as pd
from collections import defaultdict
import query_snowflake as qs
import contextlib
import pandas.io.formats.format as pf
from functools import reduce
from IPython.display import display, HTML
import win32com
from win32com.client import Dispatch
from pywintypes import com_error
import numpy as np
import re
import sqlite3
import timeit
import logging
from io import StringIO
import datetime
import json
import subprocess



def matchLogger(inStr, indent, extra=None):
    with open(logFileName, "a+") as outLog:
        # Move read cursor to the start of file.
        outLog.seek(0)
        # If file is not empty then append '\n'
        data = outLog.read(100)
        if len(data) > 0 :
            outLog.write("\n")
        # Append text at the end of file
        if indent == 'No':
            outLog.write(str(datetime.datetime.today().strftime("%m/%d/%Y %H:%M:%S")) + ' - ' + inStr +'\n\n')
        else:
            if extra == 'Yes':
                outLog.write('\t\t\t' + str(datetime.datetime.today().strftime("%m/%d/%Y %H:%M:%S")) + ' - ' + inStr +'\n\n')
            else:
                outLog.write('\t\t' + str(datetime.datetime.today().strftime("%m/%d/%Y %H:%M:%S")) + ' - ' + inStr +'\n\n')



logFileName = 'matchLog.LOG'
if os.path.exists(logFileName):
    os.remove(logFileName)
else:
    pass



#KeyDataFrame Dictionary to store important tables
#**********************************************************************************************

keyDataFrames = {}

# SETTING CLIENT/TARGET LIST AND MATCH TYPE
#**********************************************************************************************
matchTypeDict = {
    "Standard": ["npi", "me", "fname", "lname", "zip"],
    "Standard_Seg": ["npi", "me", "fname", "lname", "zip"],
    "Exact": ["npi", "me"],
    "Exact_Seg": ["npi", "me"],
    "Fuzzy": ["fname", "lname", "zip"]
                }

isTargeting = 'No'
matchType = 'Standard_Seg'
caseType = 'DocAlert'
clientListCap = ''
activeUserLookBack = 180

#SEGMENTATION PARAMETERS
#**********************************************************************************************
segmentation = ['Target_Flag_Name']
# pivotVariables = ['Ovarian', 'Segment2']

# #NO SEGMENTATION
# segmentation = []
pivotVariables = []

#list of segments to be broken out bymatchand price and or Pivot Tables
run_30_60_90_Segs = 'Yes'

#Appends Segmenation Columns to MatchType Dictionary which is used for deduping duplicate rows
if len(segmentation) != 0:
    matchTypeDict['Standard_Seg'].extend(segmentation)
    matchTypeDict['Exact_Seg'].extend(segmentation)



# CLient List Data
#*******************************************************************************************************

# For previously matched data with new add ons
loadedMatchDF = ''
# loadedMatchDF = 'C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList\\finalMatch_38834.csv'

if loadedMatchDF != '':
    targetListDF = pd.read_csv(loadedMatchDF, encoding='utf-8', dtype=str, sep=',')
    matchLogger('Imported Pre Matched File "{file}" successfully . . . Contains {count} rows'.format(file=loadedMatchDF, count=len(loadedMatchDF.index)), 'No')


# For new Full Matches
else:
    # targetFile = ''
    targetFile = 'C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList\\Test TargetFiles\\target_4.csv'
    targetListDF = pd.read_csv(targetFile, encoding='utf-8', dtype=str, sep=',')
    targetListDF.drop_duplicates(subset=matchTypeDict['Standard'], keep='first', inplace=True)
    matchLogger('Imported Target File "{file}" successfully . . . Contains {count} rows'.format(file=targetFile, count=len(targetListDF.index)), 'No')



# Suppression File Data
#**********************************************************************************************

suppFile = ''
# suppFile = 'C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList\\supp.csv'

if suppFile != '':
    suppDF = pd.read_csv(suppFile, encoding='utf-8', dtype=str, sep=',')
    suppDF.drop_duplicates(subset=matchTypeDict[matchType], keep='first', inplace=True)
    matchLogger('Imported Suppression File "{file}" successfully . . . Contains {count} rows'.format(file=suppFile, count=len(suppDF.index)), 'No')







# ADD ON PARAMETERS
# ***************************************************************************************************

sda_only = 'No'
bda_only = 'No'
sdaCap = ''
bdaCap = ''
supp_sda_only = 'No'
supp_bda_only = 'No'

# ***************************************************************************************************

# sdaDict = {}
# bdaDict = {}

# ***************************************************************************************************

# NEEDED FOR TEST DO NOT CHANGE
sdaDict = {
    'sda1': {'occs': ['MD', 'DO'], 'specs': ['Family Practice', 'Cardiology']},
    'sda2': {'occs': ['MD', 'DO', 'NP', 'PA'], 'specs': ['Gastroenterology', 'Endocrinology', 'Hematology']}
            }

# bdaDict = {'bda1': {'occs': ['MD', 'DO', 'NP', 'PA'], 'specs': [], 'dedupe': 'No', 'drugList': ['aspirin', 'ibuprofen', 'MiraLAX'], 'numLookUps': 1, 'lookupPeriod': 31, 'dedupeFrom': 'N/A'}}

# ***************************************************************************************************

# CAN BE ADJUSTED
bdaDict = {
    'bda1': {'occs': ['MD', 'DO', 'NP', 'PA'], 'specs': [], 'dedupe': 'No', 'drugList': ['aspirin', 'ibuprofen', 'MiraLAX'], 'queryByTherapy': 'No', 'numLookUps': 1, 'lookupPeriod': 31, 'dedupeFrom': 'N/A'},
    'bda2': {'occs': ['MD', 'DO'], 'specs': ['Family Practice', 'Internal Medicine, General'], 'dedupe': 'No', 'drugList': ['Acne'], 'queryByTherapy': 'Yes', 'numLookUps': 1, 'lookupPeriod': 31, 'dedupeFrom': 'N/A'},
    'bda3': {'occs': ['MD', 'DO'], 'specs': [], 'dedupe': 'No', 'drugList': ['aspirin', 'ibuprofen', 'MiraLAX'], 'queryByTherapy': 'No', 'numLookUps': 1, 'lookupPeriod': 31, 'dedupeFrom': 'N/A'}
            }

# ***************************************************************************************************

#useful varaibles to be set through out the program to be easily callable if they get populated

#There variables get set as 1 or more SDAs are ran to keep track of the matched userids and the important pricing info 
sdaMatchedIdsDict = {}
sdaTableDict = {}
totalSDAs = len(sdaDict)
totalBDAs = len(bdaDict)



# State and Zip paramenters
excludeStates = "'CO', 'VT'"
applyToClientList = 'No'
applyToSda = 'No'
applyToBda = 'No'
queryByState = 'No'
queryByZip = 'No'
stateList = None

if queryByZip == 'Yes':
    zipImportDF = pd.read_csv('zipImport.csv', dtype=str)
    zipList = zipImportDF['zipcode'].to_list()
else:
    zipList = None



#RATE CARD FOR PRICING
#**********************************************************************************************

rate_card = 'C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList\\rate_card.csv'
gaur_rates_file = 'P:\\Epocrates Analytics\\List Match\\Guarentee Rates\\gaur_rates_new.csv'
rateCardDF = pd.read_csv(rate_card)
gaurRatesDF = pd.read_csv(gaur_rates_file)



# DEFINE CUSTOMTABLE PROPERTIES HERE
#**********************************************************************************************

defaultProps = {'width':'10em', 'text-align':'center'}
addOnProps = {'width':'250px', 'text-align':'center'}
topSpecProps = {'width':'200px', 'text-align':'center'}



#userful varaibles to be set through out the program to be easily callable if they get populated

#There variables get set as 1 or more SDAs are ran to keep track of the matched userids and the important pricing info 
sdaMatchedIdsDict = {}
sdaTableDict = {}



#targeting inputs
manu = 'Merck'
exportPaths = ['C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList\\TargetExports\\Brand Manu', 'C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList\\TargetExports\\targetdump']
dSharingPath = 'C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList\\TargetExports\\datasharing\\{manu}'.format(manu=manu)


# #segmented example with Add ons
# target_numbers = {
#     'T-11111': 'one',
#     'T-22222': 'two',
#     'T-33333': 'three',
#     'T-44444': 'four',
#     'T-55555': 'five',
#     'T-66666': 'six',
#     'T-98765': 'sda_1_Match_Final',
#     'T-54321': 'sda_2_Match_Final',
#     'T-66554': 'bda_1_Match_Final',
#     'T-11223': 'bda_2_Match_Final',
#     'T-68557': 'bda_3_Match_Final'
#     }

# # Whole List + 2 SDAs and 1 BDA Example
target_numbers = {
    'T-12345': 'whole_list',
    'T-22222': 'sda_1_Match_Final',
    'T-33333': 'sda_2_Match_Final',
    'T-99999': 'bda_1_Match_Final',
    'T-88888': 'bda_2_Match_Final',
    'T-77777': 'bda_3_Match_Final'
    }

datasharingColumns = ['npi']
segmentOn = 'Target_Flag_Name'

# # Segmentation AND DATASHARING
# datasharingColumns = ['OCCUPATION', 'SPECIALTY', 'STATE']
# segmentOn = 'Ovarian'



#Print all user variables to the Log
userInputs = locals()
finalInputs = "User Inputs\n"
for key in list(userInputs.keys()):
    if not key.startswith('_') and not key.endswith('DF') and key != 'In' and key != 'Out' and key != 'userInputs' and key != 'finalInputs':
        if not str(userInputs[key]).startswith(('<module', '<class', '<function', '<built-in', '<IPython', '<bound')):
            finalInputs += '{key} : {val}\n'.format(key=key, val=userInputs[key])
            
matchLogger(finalInputs, indent='No')



def dataFramePreview(dataFrame, rows):
    rowCount = str(len(dataFrame.index))
    if int(rowCount) < rows*2:
        previewDF = dataFrame.to_string(index=False, justify='center', col_space=7)
    else:
        previewDF = dataFrame.head(rows).to_string(index=False, justify='center', col_space=7) + '\n\n. . .\n\n' + dataFrame.tail(rows).to_string(index=False, justify='center', col_space=7, header=False)
    

    numLength = len(rowCount)
    hyphens = ""
    for x in range(0, numLength):
        hyphens += "-"
    totalHyphens = '--------------'+hyphens
    totalRows = """{hyph}
|Total Rows: {count}|
{hyph}""".format(hyph=totalHyphens, count=rowCount)

    df_with_rowCount = '\n'+previewDF+'\n'+totalRows
    return df_with_rowCount



def extractClientListData(inFile, column):
    clientListDF = pd.read_csv(inFile, encoding='utf-8', dtype=str, sep=',')
    
    # if (isinstance(columnToList[0], int) or isinstance(columnToList[0], float)) and column != 'me':
    if column == 'npi':
        columnToList = clientListDF[column].tolist()

    elif column == 'me':
        # Extracts ME data and adds leading 0s to string to create me strings
        columnToList = clientListDF[column].tolist()
        newList = [str(num).zfill(10) for num in columnToList]
        columnToList = newList

    elif column == 'fuzzyNameZip':
        # concat fuzzy match name where NPI AND ME are both NULL and force capitalization to noralize data
        notNullValuesDF = clientListDF[(clientListDF['npi'].isnull())&(clientListDF['me'].isnull())]
        notNullValuesDF['fuzzyNameZip'] = notNullValuesDF['fname'].str.upper()+notNullValuesDF['lname'].str.upper()+notNullValuesDF['zip'].str.upper()
        finalFuzzy = notNullValuesDF[(notNullValuesDF['fuzzyNameZip'].notnull())]
        columnToList = finalFuzzy['fuzzyNameZip'].tolist()

    else:
        columnToList = columnToList

    return columnToList



# def convertStringsToNumbers(inList):
#     convertedList = [int(str(x).replace('nan', '0')) for x in inList]
#     for npiNum in convertedList:
#         if npiNum == 0:
#             convertedList.remove(npiNum)
#     return convertedList



def sqlInStatement(inList):

    if isinstance(inList[0], int):
        return ", ".join('{0}'.format(n) for n in inList)
    else:
        return ", ".join("'{0}'".format(n) for n in inList)



def fetchBaseTable(caseType):
    matchLogger('fetchBaseTable() is running for {caseType}...'.format(caseType=caseType), indent='Yes')

    baseUsersSQL ="""Select 
                        USER_ID,
                        FIRST_NAME,
                        LAST_NAME,
                        EMAIL,
                        STATE,
                        POSTAL_CODE,
                        COUNTRY,
                        NPI::TEXT as NPI,
                        ME_NUM,
                        ME_TRIM,
                        OCCUPATION,
                        SPECIALTY,
                        LAST_SESSION_DT,
                        FTC_ELIGIBLE
                    FROM USER_MODEL_ANALYTICS
                        WHERE last_session_dt >= dateadd(day, -{activeUserLookBack}, to_date(current_timestamp))
                        AND STATE NOT IN ({eclusionStates})
                        AND COUNTRY = 'United States of America'
                        """.format(activeUserLookBack=activeUserLookBack, eclusionStates=excludeStates)

    matchLogger('Retrieving BaseTable Data for list Match AND/OR Add ons', indent='Yes', extra='Yes')
    userDataDF = qs.querySnowflake(baseUsersSQL, 'dataFrame')


    #create new column Occ spec to include all OCCs then will update to correct concat version for join to rate card
    matchLogger('Creating OCCSPEC Column on User Base Table', indent='Yes', extra='Yes')
    userDataDF['OCCSPEC'] = userDataDF['OCCUPATION']
    md_do_Mask = (userDataDF['OCCUPATION'] == 'MD') | (userDataDF['OCCUPATION'] == 'DO')
    userDataDF['OCCSPEC'][md_do_Mask] = 'MD/DO - '+ userDataDF['SPECIALTY']
    
    matchLogger('BASE DATA PULL FROM SNOWFLAKE (ALL Active Users): {count} rows created in userDataDF DataFrame'.format(count=len(userDataDF.index)), indent='Yes', extra='Yes')
    matchLogger('fetchBaseTable() finished running ...', indent='Yes')
    return userDataDF



def matchClientList(inFile, inFileDF, matchType, caseType, suppMatch):
    matchLogger('matchClientList() is running ...', indent='No')

    if 'baseData' not in keyDataFrames.keys():
        userDataDF = fetchBaseTable(caseType)
    else:
        userDataDF = keyDataFrames['baseData']

    # print(userDataDF)

    # Create concat column of FNAME, LNAME and ZIP if not Exact Match
    if matchType not in ['Exact', 'Exact_Seg']:
        matchLogger('Running Standard Match . . . Concatenating FNAME, LNAME and Zip in Base Tables', indent='Yes')
        userDataDF['fuzzyNameZip'] = userDataDF['FIRST_NAME'].str.upper()+userDataDF['LAST_NAME'].str.upper()+userDataDF['POSTAL_CODE'].str.upper()

    #Currently correcting incorrect ME Num, this will go away when the number is correct
    userDataDF['ME_CORRECTED'] = userDataDF['ME_NUM'].str[:10]

    userDataFinalDF = userDataDF

    #creates the 3 data frames of matched data based on NPI, ME or FuzzyFields then joins on those fields to retain target.csv column data for segmentation or deduping client data
    matchLogger('Running NPI Match . . . ', indent='Yes')
    npiList = extractClientListData(inFile, 'npi')
    npiMatchedDF = userDataFinalDF[userDataFinalDF['NPI'].isin(npiList)]
    npiMatchedDF = pd.merge(npiMatchedDF, inFileDF, how='inner', left_on=['NPI'], right_on=['npi'])
    matchLogger('NPI Match Complete!: {count} rows created in npiMatchedDF Dataframe'.format(count=len(npiMatchedDF.index)), indent='Yes')

    npiNotMatchedDF = userDataFinalDF[~userDataFinalDF['NPI'].isin(npiList)]

    matchLogger('Running ME Match . . . ', indent='Yes')
    meList = extractClientListData(inFile, 'me')
    meMatchedDF = npiNotMatchedDF[npiNotMatchedDF['ME_TRIM'].isin(meList)]
    meMatchedDF = pd.merge(meMatchedDF, inFileDF, how='inner', left_on=['ME_TRIM'], right_on=['me'])
    matchLogger('ME Match Complete!: {count} rows created in meMatchedDF Dataframe'.format(count=len(meMatchedDF.index)), indent='Yes')


    if matchType not in ['Exact', 'Exact_Seg']:
        matchLogger('Running Fuzzy Match . . . ', indent='Yes')
        fuzzyList = extractClientListData(inFile, 'fuzzyNameZip')
        fuzzyMatchedDF = userDataFinalDF[userDataFinalDF['fuzzyNameZip'].isin(fuzzyList)]
        fuzzyMatchedDF = pd.merge(fuzzyMatchedDF, inFileDF, how='inner', left_on=['FIRST_NAME', 'LAST_NAME', 'POSTAL_CODE'], right_on=['fname', 'lname', 'zip'])
        matchLogger('Fuzzy Match Complete!: {count} rows created in meMatchedDF Dataframe'.format(count=len(fuzzyMatchedDF.index)), indent='Yes')
    else:
        matchLogger('Performing Exact Match no Fuzzy Match Needed\n', indent='Yes')
        fuzzyMatchedDF = pd.DataFrame()
        


    print('NPI DATA\n--------------------\n', npiMatchedDF)
    print('ME DATA\n--------------------\n', meMatchedDF)
    print('FUZZY DATA\n--------------------\n', fuzzyMatchedDF)



    #Merge All DF's together
    mergedDF = pd.concat([npiMatchedDF, meMatchedDF, fuzzyMatchedDF], axis=0, ignore_index=True)

    #Sort by Userid and Last session DT to help identify which duplicates to keep ( We want most active Session DT for dup users)
    mergedDF.sort_values(["USER_ID", "LAST_SESSION_DT"], ascending=True)

    #Drop the duplicate NPI, ME FUZYY USERS where we keep the last value of dups which would be the greatest last_session_DT time
    mergedDF.drop_duplicates(subset=matchTypeDict[matchType], keep='last', inplace=True)

    # state or zip match or Both
    if (queryByState == 'Yes' or queryByZip == 'Yes') and applyToClientList == 'Yes':
        mergedDF = stateZipMatch(mergedDF, zipList, stateList)

    #specialized Deduping here. State, Zip, dataCaps
    if clientListCap != '':
        mergedDF = sampleData(mergedDF, clientListCap)

    finalDataDF = ftcEligibleUsers(mergedDF, isTargeting)
    finalDF = finalDataDF[0]
    totalNonFTCEligible = finalDataDF[1]

    # Keep all important dataframes in a Dictionary to do stuff with later or call on
    matchLogger('Appending Key Dataframes to KeyDataFrames Dictionary', indent='Yes')
    if suppMatch == 'No':
        keyDataFrames['baseData'] = userDataFinalDF
        keyDataFrames['npiMatchData'] = npiMatchedDF
        keyDataFrames['meMatchData'] = meMatchedDF
        keyDataFrames['fuzzyMatchData'] = fuzzyMatchedDF
        keyDataFrames['finalMatch'] = finalDF
        keyDataFrames['nonFTCEligible'] = totalNonFTCEligible
        keyDataFrames['finalMatch_User_Profile'] = createUserProfile(finalDF)
    else:
        keyDataFrames['npiMatchData_Supp'] = npiMatchedDF
        keyDataFrames['meMatchData_Supp'] = meMatchedDF
        keyDataFrames['fuzzyMatchData_Supp'] = fuzzyMatchedDF
        keyDataFrames['finalMatch_Supp'] = finalDF

    matchLogger('Client List Matching Complete!: {count} rows created in finalDF Dataframe'.format(count=len(finalDF.index)), indent='Yes')
    matchLogger('matchClientList() finished running ...', indent='No')
    matchLogger(dataFramePreview(finalDF, 5), 'No')
    return finalDF



def stateZipMatch(dataFrame, zipList=None, stateList=None):
    matchLogger('stateZipMatch() is running ...', indent='No')
    if zipList != None:
        logZipList = zipList
    else:
        logZipList = []

    if stateList != None:
        logStateList = stateList
    else:
        logStateList = []

    matchLogger('Filtering Data on States: {} | Zips: {}'.format(', '.join(logStateList), ', '.join(logZipList)), 'Yes')

    if zipList != None:
        filteredDF = dataFrame[dataFrame['POSTAL_CODE'].isin(zipList)]
    elif stateList != None:
        filteredDF = dataFrame[dataFrame['STATE'].isin(stateList)]
    elif zipList != None and stateList != None:
        filteredDF = dataFrame[dataFrame['POSTAL_CODE'].isin(zipList) & dataFrame['STATE'].isin(stateList)]

    matchLogger('stateZipMatch() finished running ...', indent='No')
    return filteredDF



def get_30_60_90(activeDaysList):
    matchLogger('get_30_60_90() is running ...', indent='No')

    matchedDF = keyDataFrames['finalMatch']
    data = []
    for desiredDays in activeDaysList:
        subsetDF = matchedDF[matchedDF['LAST_SESSION_DT'] >= (pd.datetime.now().date() - pd.to_timedelta(desiredDays, unit='d'))]
        row = ['{}_Days_Active'.format(desiredDays), len(subsetDF.index)]
        data.append(row)

    activeUsersDF = pd.DataFrame(data=data, columns = ['Days Active', 'Matched Count'])

    stringInts = [str(x) for x in activeDaysList]
    title = ', '.join(stringInts).replace(', ', '/')+ ' Days Active Match Counts'
    
    matchLogger('get_30_60_90() finished running ...', indent='No')
    matchLogger(dataFramePreview(commaFormatting(activeUsersDF), 5), 'Yes')
    return commaFormatting(activeUsersDF), title



def priceDataFrame(dataFrame, product, addOn=None, dfName=None):
    # matchLogger('priceDataFrame() is running ...', indent='No')

    groupedUsersDF = dataFrame.groupby('OCCSPEC').count()
    pricingDF = pd.merge(left=groupedUsersDF, right=rateCardDF, left_on=['OCCSPEC'],right_on=['occspec'])
    pricingDF['price'] = pricingDF['USER_ID'] * pricingDF['rate']
    finalPricingDF = pricingDF[['occspec', 'USER_ID', 'rate', 'price']]
    finalPricingDF.columns = ['occspec', 'count', 'rate', 'price']


    if dfName:
        # keyDataFrames['grouped_{}'.format(dfName)] = groupedUsersDF
        keyDataFrames['price_{}'.format(dfName)] = finalPricingDF

    if addOn:
        totalPrice = int(round((finalPricingDF['price'].sum()) + 499, -3))

    else:
        if product == 'DocAlert':
            multi = 1.2
        elif product == 'EpocQuiz':
            multi = 1.25
        elif product == 'Triggered':
            multi = 1.15 

        totalPrice = int(round((finalPricingDF['price'].sum() * multi) + 499, -3))


    # matchLogger('priceDataFrame() finish running ...', indent='No')
    return '$'+str(commaFormatting(totalPrice)), finalPricingDF


    



def createUserProfile(dataframe):
    user_profileDF = dataframe.copy(deep=True)

    np_pa_Mask = (user_profileDF.OCCUPATION=='NP') | (user_profileDF.OCCUPATION=='PA')
    user_profileDF['OCCSPEC'][np_pa_Mask] = 'NP/PA - '+ user_profileDF['SPECIALTY']
    
    return user_profileDF



def gauranteeRateCalculator(dataframeList):

    #return gaur rates for JUST LM or Just Add On. Always required by itself for the email + LM and Add ons if applicable. Fnction needs to do both
    if len(dataframeList) == 1:
        user_profileDF = dataframeList[0]

        if sda_only == 'No' and bda_only == 'No': 
            user_profileRates = pd.merge(left=user_profileDF, right=gaurRatesDF, how='inner', left_on=['OCCSPEC'],right_on=['occspec'])
        
        else:
            user_profileRates = pd.merge(left=user_profileDF, right=gaurRatesDF, how='left', left_on=['OCCSPEC'],right_on=['occspec'])
            user_profileRates.rate.fillna(0.0600)
            #Code to update Nan/Null Rates to .0600

    #return LM + Adds on stand alone Add on Gaur Rates
    else:
        # LM + Add on/ Append Two Profiles Then Join
        user_profile_LM = dataframeList[0]
        user_profile_AddOn = dataframeList[1]
        user_profileDF = user_profile_LM.append(user_profile_AddOn)
        user_profileRates = pd.merge(left=user_profileDF, right=gaurRatesDF, how='inner', left_on=['OCCSPEC'],right_on=['occspec'])


    #Rate Card Joined to Grouped User Progiles
    groupedRatesDF = pd.DataFrame( {'count' : user_profileRates.groupby(['occspec', 'rate']).size()}).reset_index()

    # Get total users of match/add on then calculate the weighted total by occ spec and update Dataframe
    sum_weighted_users = groupedRatesDF['count'].sum()
    groupedRatesDF['weight'] = groupedRatesDF['count'] / sum_weighted_users
    groupedRatesDF['weighted_rate'] = groupedRatesDF['weight'] * groupedRatesDF['rate']

    weightTotal = sum_weighted_users = groupedRatesDF['weighted_rate'].sum()
    weightPercentage = "{:.2%}".format(weightTotal)

    return weightPercentage

    # print('Total Weighted Users -', weightPercentage, '\n\n', groupedRatesDF)



# gauranteeRateCalculator(keyDataFrames['finalMatch'], sda_only, bda_only)



#function for taking list(row of data or individual number or dataframe) and converting it to comma separated
def commaFormatting(input):
    # matchLogger(logging.info('Is Running . . . '))
    formatter = '{:,d}'.format
    if isinstance(input, int):
        fmt_values = formatter(int(input))
    elif isinstance(input, list):
        fmt_values = [formatter(int(x)) if isinstance(x, int) else x for x in input]
    elif isinstance(input, pd.core.frame.DataFrame):
        fmt_values_list = []
        dfLists = input.values.tolist()
        for l in dfLists:
            fmt_values_list.append([formatter(int(x)) if isinstance(x, int) else x for x in l])
        fmt_values = pd.DataFrame(data=fmt_values_list, columns = input.columns)
    
    return fmt_values



def priceForEmail(dataFrame):
    # matchLogger('priceForEmail() is running ...', indent='No')

    rawPrice = int(priceDataFrame(dataFrame, caseType)[0].replace('$', '').replace(',',''))
    totalPrice = priceDataFrame(dataFrame, caseType)[0]

    if rawPrice >= 20000:
        priceText = """<b>Price: {totalPrice}</b>""".format(totalPrice=totalPrice)
        priceText2 = """Due to de-duplication, the price may drop if an additional <b>{product}</b> target is being added. Please put in a new Salesforce ticket in that case.<br><br>""".format(product=caseType)
    else:
        priceText = """<b>Price: $20,000 (minimum price for a wave)</b>"""
        priceText2 = """Due to de-duplication, the price may drop if an additional <b>{product}</b> target is being added. Please put in a new Salesforce ticket in that case.<br><br>""".format(product=caseType)

    # matchLogger('priceForEmail() finished running ...', indent='No')
    return priceText, priceText2



def currencyFormat(x):
    x = int(x.replace('$', ''))
    return "${:,}".format(x)



def createFullSegmentDataFrames(dataFrame, segmentedColumn):
    for val in target_numbers.values():
        segmentDF = dataFrame.loc[dataFrame[segmentedColumn] == val]
        # dataFrame.loc[dataFrame[segmentedColumn] == val]
        # dataFrame[dataFrame.segmentedColumn == val]

        keyDataFrames[val] = segmentDF



#SEGMENTATION WORK
#********************************************************************************

def segmentToDataFrame(segmentList, product):
    matchLogger('segmentToDataFrame() is running ...', indent='No')

    i = 1

    if product == 'DocAlert':
        multi = 1.2
    elif product == 'EpocQuiz':
        multi = 1.25
    elif product == 'Triggered':
        multi = 1.15

    segmentDFDictionary = {}
    for segment in segmentList:

        # create Frequency Chart of the Occspecs with respective rates
        segmentRatesMergeDF = pd.merge(left=keyDataFrames['finalMatch'], right=rateCardDF, left_on=['OCCSPEC'],right_on=['occspec'])

        #Group By Semgnet Values and sum Rates, Then we multiple each Segment Rate by the Multiplier
        segmentRatesDF = segmentRatesMergeDF.groupby('{}'.format(segment))['rate'].sum()
        segmentRatesDF = segmentRatesDF.reset_index()
        segmentRatesDF['new_rate'] = '$' + round((segmentRatesDF['rate']*multi) + 499, -3).astype(int).astype(str)

        # Set 3 data frames that contain all required info to build final segment chart
        segmentPrice = segmentRatesDF.drop(['rate'], axis=1)
        segmentCountsAll = targetListDF['{}'.format(segment)].value_counts().rename_axis('{}'.format(segment)).reset_index(name='Count')
        segmentMatchCounts = keyDataFrames['finalMatch']['{}'.format(segment)].value_counts().rename_axis('{}'.format(segment)).reset_index(name='Count')

        #merge all 3 Dataframes on Segment Name then create last needed column which is match rate
        dfs = [segmentPrice, segmentCountsAll, segmentMatchCounts]
        df_final = reduce(lambda left,right: pd.merge(left,right,on='{}'.format(segment)), dfs)
        df_final['Campaign Eligible\nSegment Match Rate'] = round((df_final['Count_y']/df_final['Count_x'])*100).astype(int).astype(str)+'%'

        #Rename all Columns then reorder to final order and lastly use currencyFOrmat function to apply formating to Price column
        df_final.columns = ['Client Segment', 'Campaign Eligible\nSegment Price', 'Original Client List\nSegment Count', 'Campaign Eligible\nSegment Match Count', 'Campaign Eligible\nSegment Match Rate']
        df_final = df_final[['Client Segment', 'Original Client List\nSegment Count', 'Campaign Eligible\nSegment Match Count', 'Campaign Eligible\nSegment Match Rate', 'Campaign Eligible\nSegment Price']]
        df_final['Campaign Eligible\nSegment Price'] = df_final['Campaign Eligible\nSegment Price'].apply(currencyFormat)
        
        
        segmentDFDictionary[segment] = commaFormatting(df_final)
        matchLogger('Semgnetation Complete for {}\n{}'.format(segment, dataFramePreview(df_final, 5)), indent='No')
        
    keyDataFrames.update(segmentDFDictionary)
    matchLogger('segmentToDataFrame() finished running ...', indent='No')

    if segmentOn != '':
        createFullSegmentDataFrames(keyDataFrames['finalMatch'], segmentOn)

    return segmentDFDictionary



def segment_30_60_90(segmentList, in_30_60_90_list):
    # matchLogger('segment_30_60_90() is running ...', indent='No')

    i = 1

    matchedDF = keyDataFrames['finalMatch']

    my30_60_90_SegmentsDict = {}
    for segment in segmentList:
        for activeDay in in_30_60_90_list:

            #create Subset of active users to create segment chart
            subsetDF = matchedDF[matchedDF['LAST_SESSION_DT'] >= (pd.datetime.now().date() - pd.to_timedelta(activeDay, unit='d'))]

            #Group by segment and count
            segmentsDF = subsetDF.groupby('{}'.format(segment)).count()
            segmentsDF = segmentsDF.reset_index()

            # retain segmentCOL and the count only and renamim count column
            segmentsDF = segmentsDF[['{clientSeg}'.format(clientSeg=segment), 'USER_ID']]
            segmentsDF.columns = ['{clientSeg}'.format(clientSeg=segment), '{activeDays}_Days_Active'.format(activeDays=activeDay)]
            df_final = segmentsDF[['{clientSeg}'.format(clientSeg=segment), '{activeDays}_Days_Active'.format(activeDays=activeDay)]]
            
            my30_60_90_SegmentsDict['{days}_{segment}'.format(days=activeDay, segment=segment)] = commaFormatting(df_final)

    keyDataFrames.update(my30_60_90_SegmentsDict)
    # matchLogger('segment_30_60_90() finished running ...', indent='No')

    return my30_60_90_SegmentsDict



# Creates Pivot Chart of 2 specified Segments
#**********************************************************************************************

def segmentPivotChart(segment1, segment2):
    # matchLogger('segmentPivotChart() is running ...', indent='No')

    pivotTable = keyDataFrames['finalMatch'].pivot_table(values= ['USER_ID'], index=segment1, columns=segment2, aggfunc=pd.Series.nunique, margins=True, margins_name='Totals')
    pivotTable.columns = pivotTable.columns.droplevel()
    pivotTable.index.name = segment1+'/'+segment2
    
    # matchLogger('segmentPivotChart() finished running ...', indent='No')
    return pivotTable.reset_index()
    # pivotTable.to_csv('pivotTest.csv')



#Begin SDA Work
#********************************************************************

def sdaMatch(totalEligibleDF, occList, specList, sdaInc):
    matchLogger('sdaMatch() is running ...', indent='No')

    #CE SDA Users that dedupes already matched users. This is SDA TOTAL BASE not broken down by Occ Spec yet

    # Get the Eligible Occ Specs
    if len(specList) != 0:      
        sdaEligibleDF_OccSpec = totalEligibleDF[totalEligibleDF['OCCUPATION'].isin(occList) & totalEligibleDF['SPECIALTY'].isin(specList)]
    else:
        sdaEligibleDF_OccSpec = totalEligibleDF[totalEligibleDF['OCCUPATION'].isin(occList)]

    keyDataFrames['sda_occspecs_undeduped'] = sdaEligibleDF_OccSpec
    matchLogger('SDA {inc} - Occs: {occ} | Specs: {spec} COMP COUNT: {count}'.format(inc=sdaInc, occ=', '.join(occList), spec=', '.join(specList), count=len(sdaEligibleDF_OccSpec.index)), indent='Yes')

#*************************************************************************************************************************************
    # Suppress User Base or Not
    if suppFile == '':
        sdaEligibleDF = sdaEligibleDF_OccSpec
    else:
        if supp_bda_only == 'Yes' and supp_sda_only == 'No':
            sdaEligibleDF = sdaEligibleDF_OccSpec
        else:
            sdaEligibleDF = dedupeDataframe(sdaEligibleDF_OccSpec, 'USER_ID', dFColToList(keyDataFrames['finalMatch_Supp'], 'USER_ID'), inList2=None)

#*************************************************************************************************************************************
    # CL + SDA
    if sda_only == 'No':
        sdaEligibleDF = dedupeDataframe(sdaEligibleDF, 'USER_ID', dFColToList(keyDataFrames['finalMatch'], 'USER_ID'), inList2=None)
        totalPriceRaw = int(totalPrice.replace('$', '').replace(',', ''))
        listMatchData = ['List Match Users', commaFormatting(matchedCount), totalPrice]

    # Stand alone SDA
    else:
        sdaEligibleDF = sdaEligibleDF

#*************************************************************************************************************************************
    # State / Zip Filtering
    if (queryByState == 'Yes' or queryByZip == 'Yes') and applyToSda == 'Yes':
        sdaEligibleDF = stateZipMatch(sdaEligibleDF, zipList, stateList)


    keyDataFrames['sda_occspecs_full_deduped'] = sdaEligibleDF
    
    sdaUsers = sdaEligibleDF
    if sdaCap != '' and sda_only == 'No':
        # Full CL + Cap on remaining SDA
        sdaUsers = sampleData(sdaUsers, sdaCap - len(keyDataFrames['finalMatch'].index))
    
    elif sdaCap != '' and sda_only == 'Yes':
        # Full CL + Cap on remaining SDA
        sdaUsers = sampleData(sdaUsers, sdaCap)


    #FTC SUPPRESSION
    sdaUsersFTC = ftcEligibleUsers(sdaUsers, isTargeting, 'SDA', sdaInc)
    sdaUsers = sdaUsersFTC[0]
    nonFTCSdaUserTotal = sdaUsersFTC[1]
    matchLogger('SDA {inc} -  Non Eligible FTC User Count: {count}'.format(inc=sdaInc, count=nonFTCSdaUserTotal), indent='Yes')

    sdaUsersCount = len(sdaUsers.index)
    sdaStringPrice = priceDataFrame(sdaUsers, 'DocAlert', 'sda', 'sda_{}'.format(sdaInc))[0]
    sdaRawPrice = int(sdaStringPrice.replace('$', '').replace(',', ''))
    
    sdaTable = []
    sdaColumns = ['Criteria', 'Users', 'Price']
    sdaTableData = ['Occupation/Specialty*',commaFormatting(sdaUsersCount), priceDataFrame(sdaUsers, 'DocAlert', 'sda')[0]]

    if sda_only == 'No':
        sdaPlusMatchData = ['Specialty + List Match', commaFormatting(sdaUsersCount + matchedCount), '$'+commaFormatting(totalPriceRaw+sdaRawPrice)]
        sdaTable.extend([listMatchData, sdaTableData, sdaPlusMatchData])
    else:
        sdaTable.extend([sdaTableData])

    sdaMatchedIdsDict['sda{}'.format(str(sdaInc))] = sdaUsers['USER_ID'].to_list()
    sdaTableDict['sda{}'.format(str(sdaInc))] = sdaTableData  
    sdaTableDF = pd.DataFrame(data=sdaTable, columns=sdaColumns)

    #append final match to keyDataFrame DIctionary
    keyDataFrames['sda_{}_Match_Final'.format(sdaInc)] = sdaUsers

    #Append the User_Profile for generating Guarantee Rates
    keyDataFrames['sda_{}_Match_Final_User_Profile'.format(sdaInc)] = createUserProfile(sdaUsers)

    matchLogger('sdaMatch() finished running ...', indent='No')
    if sda_only == 'No':
        return sdaTableDF, commaFormatting(sdaUsersCount + matchedCount), '$'+commaFormatting(totalPriceRaw+sdaRawPrice), occList, specList, nonFTCSdaUserTotal
    else:
        return sdaTableDF, commaFormatting(sdaUsersCount), '$'+commaFormatting(sdaRawPrice), occList, specList, nonFTCSdaUserTotal



#Begin BDA Work
#********************************************************************

# %let therapy_class = /*therapyClass*/;

def bdaMatch(totalEligibleDF, occList, specList, dedupeBDA, lookupPeriod, drugList, queryByTherapy, numLookUps, dedupeFrom, bdaInc):
    matchLogger('bdaMatch() is running ...', indent='No')

    #if were not deduping common sda users we just need to dedupe the matched ids from the Master Initial Pulled USers which woul dbe remaining eligible
    
    # Get the Eligible Occ Specs
    if len(specList) != 0:      
        bdaEligibleDF_OccSpec = totalEligibleDF[totalEligibleDF['OCCUPATION'].isin(occList) & totalEligibleDF['SPECIALTY'].isin(specList)]
    else:
        bdaEligibleDF_OccSpec = totalEligibleDF[totalEligibleDF['OCCUPATION'].isin(occList)]

    keyDataFrames['bda_occspecs_undeduped'] = bdaEligibleDF_OccSpec
    matchLogger('BDA {inc} - Occs: {occ} | Specs: {spec} COMP COUNT: {count}'.format(inc=bdaInc, occ=', '.join(occList), spec=', '.join(specList), count=len(bdaEligibleDF_OccSpec.index)), indent='Yes')

#*************************************************************************************************************************************
    # Suppress User Base or Not
    if suppFile == '':
        bdaEligibleDF = bdaEligibleDF_OccSpec
    else:
        if supp_sda_only == 'Yes':
            bdaEligibleDF = bdaEligibleDF_OccSpec
        else:
            bdaEligibleDF = dedupeDataframe(bdaEligibleDF_OccSpec, 'USER_ID', dFColToList(keyDataFrames['finalMatch_Supp'], 'USER_ID'), inList2=None)

#*************************************************************************************************************************************
    # CL + BDA
    if bda_only == 'No':
        # No BDA to dedupe from
        if dedupeBDA == 'No':
            bdaEligibleDF = dedupeDataframe(bdaEligibleDF, 'USER_ID', dFColToList(keyDataFrames['finalMatch'], 'USER_ID'), inList2=None)
        # dedupe the SDA from a BDA
        else:
            bdaEligibleDF = dedupeDataframe(bdaEligibleDF, 'USER_ID', dFColToList(keyDataFrames['finalMatch'], 'USER_ID'), sdaMatchedIdsDict[dedupeFrom])

#*************************************************************************************************************************************
    # Stand alone BDA
    else:
        # No SDA to dedupe from
        if dedupeBDA == 'No':
            bdaEligibleDF = bdaEligibleDF
        # dedupe the SDA from a BDA
        else:
            bdaEligibleDF = dedupeDataframe(bdaEligibleDF, 'USER_ID', sdaMatchedIdsDict[dedupeFrom], inList2=None)

#*************************************************************************************************************************************
    # State / Zip Filtering
    if (queryByState == 'Yes' or queryByZip == 'Yes') and applyToBda == 'Yes':
        bdaEligibleDF = stateZipMatch(bdaEligibleDF, zipList, stateList)


    bdaOccSpecsDF = bdaEligibleDF
    keyDataFrames['bda_occspecs_full_deduped'] = bdaOccSpecsDF


    therapyDrugSQL = """SELECT drug_name
                            FROM EPOC_ANALYTICS.THERAPEUTIC_CLASS_ALL_DRUGS 
                                WHERE THERAPEUTIC_CLASS_NAME IN ({inputTherapies})""".format(inputTherapies=getDrugsByTherapy(drugList))

                        

    if queryByTherapy == 'Yes':
        drugListQuery = therapyDrugSQL
    else:
        drugListQuery = sqlInStatement(drugList)


    drugSQL = """
                Select distinct USER_ID FROM
                    (
                        Select USER_ID, DRUG_NAME, SUM(TOTAL_VIEWS) as lookups
                            FROM EPOC_ANALYTICS.DRUG_MODEL_ANALYTICS
                                WHERE EVENT_DATE >= dateadd(day, -{lookupPeriod}, to_date(current_timestamp))
                                    AND EVENT_DATE <= current_timestamp
                                    AND DRUG_NAME IN ({drugList})
                                GROUP BY USER_ID, DRUG_NAME
                                ORDER BY USER_ID ASC
                    )
                        WHERE lookups >= {numLookUps}""".format(drugList=drugListQuery, lookupPeriod=lookupPeriod,numLookUps=numLookUps)

    drugDF = qs.querySnowflake(drugSQL, 'dataFrame')

    #
    bdaUsers = pd.merge(left=drugDF, right=bdaOccSpecsDF, left_on=['USER_ID'], right_on=['USER_ID'])
    if bdaCap != '' and bda_only == 'No':
        # Full CL + Cap on remaining BDA
        if len(sdaDict) == 0:
            bdaUsers = sampleData(bdaUsers, bdaCap - len(keyDataFrames['finalMatch'].index))
        else:
            bdaUsers = sampleData(bdaUsers, bdaCap - (len(keyDataFrames['finalMatch'].index) + sdaCap))
    
    elif bdaCap != '' and bda_only == 'Yes':
        # Cap on remaining SDA
        if len(sdaDict) == 0:
            bdaUsers = sampleData(bdaUsers, bdaCap)
        else:
            bdaUsers = sampleData(bdaUsers, bdaCap - len(keyDataFrames['sda_Match_Final'].index))
    bdaUsersCount = len(bdaUsers.index)


    #FTC SUPPRESSION
    bdaUsersFTC = ftcEligibleUsers(bdaUsers, isTargeting, 'BDA', bdaInc)
    bdaUsers = bdaUsersFTC[0]
    nonFTCBdaUserTotal = bdaUsersFTC[1]
    matchLogger('BDA {inc} -  Non Eligible FTC User Count: {count}'.format(inc=bdaInc, count=nonFTCBdaUserTotal), indent='Yes')


    keyDataFrames['bda_{}_Match_Final'.format(bdaInc)] = bdaUsers
    priceDataFrame(bdaUsers, 'DocAlert', 'bda', 'bda_{}'.format(bdaInc))
    #BDA Table runs function to determine to build BDA only or BDA + SDA 

    #Append the User_Profile for generating Guarantee Rates
    keyDataFrames['bda_{}_Match_Final_User_Profile'.format(bdaInc)] = createUserProfile(bdaUsers)

    bdaTableData = sdaBDATable(bdaUsers, bdaUsersCount, drugDF, dedupeBDA, dedupeFrom)

    matchLogger('bdaMatch() finished running ...', indent='No')
    
    if dedupeBDA == 'No':
        if bda_only == 'No':
            return bdaTableData[0], commaFormatting(bdaUsersCount + matchedCount), '$'+commaFormatting(bdaTableData[2]+bdaTableData[1]), occList, specList, drugList, numLookUps, lookupPeriod
        else:
            return bdaTableData[0], commaFormatting(bdaUsersCount), '$'+commaFormatting(bdaTableData[1]), occList, specList, drugList, numLookUps, lookupPeriod
    else:
        if bda_only == 'No':
            return bdaTableData[0], commaFormatting(bdaUsersCount + matchedCount+bdaTableData[1]), '$'+commaFormatting(bdaTableData[4]+bdaTableData[3]+bdaTableData[2]), occList, specList, drugList, numLookUps, lookupPeriod  
        else:
            return bdaTableData[0], commaFormatting(bdaUsersCount + bdaTableData[1]), '$'+commaFormatting(bdaTableData[3]+bdaTableData[2]), occList, specList, drugList, numLookUps, lookupPeriod
    



def getDrugsByTherapy(therapyList):
    sqlTherapies = sqlInStatement(therapyList)
    return sqlTherapies



def sdaBDATable(bdaUsers, bdaUsersCount, drugDF, dedupeBDA, dedupeFrom):
    matchLogger('sdaBDATable() is running ...', indent='No')

    if dedupeFrom == 'N/A':
        pass
    else:
        sdaData = sdaTableDict[dedupeFrom]
        sdaCount = int(sdaData[1].replace('$', '').replace(',', ''))
        sdaRawPrice = int(sdaData[2].replace('$', '').replace(',', ''))


    if bda_only == 'No': 
        bdaStringPrice = priceDataFrame(bdaUsers, 'DocAlert', 'bda')[0]
        bdaRawPrice = int(bdaStringPrice.replace('$', '').replace(',', ''))
        totalPriceRaw = int(totalPrice.replace('$', '').replace(',', ''))

        bdaTable = []
        bdaColumns = ['Criteria', 'Users', 'Price']
        listMatchData = ['List Match Users', commaFormatting(matchedCount), totalPrice]
        bdaTableData = ['Ramaining Behavioral Segment**',commaFormatting(bdaUsersCount), priceDataFrame(bdaUsers, 'DocAlert', 'bda')[0]]
        if dedupeBDA == 'No':
            bdaPlusMatchData = ['Behavioral + List Match', commaFormatting(bdaUsersCount + matchedCount), '$'+commaFormatting(totalPriceRaw+bdaRawPrice)]
            bdaTable.extend([listMatchData, bdaTableData,bdaPlusMatchData])
            bdaTableDF = pd.DataFrame(data=bdaTable, columns=bdaColumns)

            return bdaTableDF, bdaRawPrice, totalPriceRaw
        else:
            bdaSDAMatchData = ['Occ/Spec + Behavioral + List Match', commaFormatting(bdaUsersCount + matchedCount + sdaCount), '$'+commaFormatting(totalPriceRaw+bdaRawPrice+sdaRawPrice)]
            bdaTable.extend([listMatchData, sdaData, bdaTableData, bdaSDAMatchData])
            bdaTableDF = pd.DataFrame(data=bdaTable, columns=bdaColumns)
            
            return bdaTableDF, sdaCount, sdaRawPrice, bdaRawPrice, totalPriceRaw
    
    else:
        bdaStringPrice = priceDataFrame(bdaUsers, 'DocAlert', 'bda')[0]
        bdaRawPrice = int(bdaStringPrice.replace('$', '').replace(',', ''))

        bdaTable = []
        bdaColumns = ['Criteria', 'Users', 'Price']
        bdaTableData = ['Ramaining Behavioral Segment**',commaFormatting(bdaUsersCount), priceDataFrame(bdaUsers, 'DocAlert', 'bda')[0]]

        matchLogger('sdaBDATable() finished running ...', indent='No')
        
        if dedupeBDA == 'No':
            bdaTable.extend([bdaTableData])
            bdaTableDF = pd.DataFrame(data=bdaTable, columns=bdaColumns)

            return bdaTableDF, bdaRawPrice
        else:
            bdaSDABDAData = ['Occ/Spec + Behavioral', commaFormatting(bdaUsersCount + sdaCount), '$'+commaFormatting(bdaRawPrice+sdaRawPrice)]
            bdaTable.extend([sdaData, bdaTableData, bdaSDABDAData])
            bdaTableDF = pd.DataFrame(data=bdaTable, columns=bdaColumns)
            
            return bdaTableDF, sdaCount, sdaRawPrice, bdaRawPrice
        
    
 



# Test BDAS
# for k, d in bdaDict.items():
#     bdaAllData = bdaMatch(userDataFinalDF, d['occs'], d['specs'], d['dedupe'], d['lookupPeriod'], d['drugList'], d['numLookUps'])

    # print(bdaAllData[0])



def style_email_tables(s):
    # return ['background-color: #EFF2F8' if s.name % 2 else '' for v in s]
    return ['text-align: center; border-style: solid; border-collapse: collapse; border-width: 1.5px; border-color: #CCD4DC' if s.name % 2 else 'background-color: #EFF2F8; text-align: center; border-style: solid; border-collapse: collapse; border-width: 1.5px; border-color: #CCD4DC' for v in s]

def styleDataFrame(dataFrame, customProperties, columnSubset=None):
#     matchLogger('styleDataFrame() is running ...', indent='No')

    if columnSubset:
        mask = [x for x in dataFrame.columns if x not in columnSubset]
        # [x for x in dataFrame.columns if x not in columnSubset]
        tableHTML = (
                dataFrame.style.apply(style_email_tables, axis=1)
                        .set_properties(subset=columnSubset, **customProperties)
                        .set_properties(subset=mask, **defaultProps)
                        .set_table_styles([{'selector':'th', 'props': [('border-style','solid'),('border-collapse', 'collapse'),('border-width','1.5px'), ('border-color', '#CCD4DC'), ('text-align', 'center'), ('background', '#102038')]}])
                        .hide_index()
                        .render()
            )

    else:
        tableHTML = (
                dataFrame.style.apply(style_email_tables, axis=1)
                        .set_properties(**customProperties)
                        .set_table_styles([{'selector':'th', 'props': [('border-style','solid'),('border-collapse', 'collapse'),('border-width','1.5px'), ('border-color', '#CCD4DC'), ('text-align', 'center'), ('background', '#102038')]}])
                        .hide_index()
                        .render()
                )
        
#     matchLogger('styleDataFrame() finished running ...', indent='No')
    return tableHTML



# DEDUPING FUNCTIONs
def dedupeDataframe(dF, dedupeColumn, inList1, inList2=None):
    # matchLogger('dedupeDataframe() is running ...', indent='No')

    # dF1 is main Dataframe to keep MINUS the values from DF2 to dedupe, dF3 is optional to dedupe 2 dfs at once
    if not inList2:
        dedupedDF = dF[~dF[dedupeColumn].isin(inList1)]
    else:
        dedupedDF = dF[~dF[dedupeColumn].isin(inList1) & ~dF[dedupeColumn].isin(inList2)]

    # matchLogger('dedupeDataframe() finished running ...', indent='No')
    return dedupedDF


def dFColToList(dF, column):
    return dF[column].to_list()



def sampleData(dataFrame, cap=None, frac=None):
    matchLogger('sampleData() is running ...', indent='No')

    if not frac:
        capDF = dataFrame.sample(n=cap)
    else:
        capDF =dataFrame.sample(frac=frac)

    matchLogger('sampleData() finished running ...', indent='No')
    return capDF



def ftcEligibleUsers(dataframe, isTargeting, addOn=None, inc=None):
    baseMatchDF = dataframe.copy(deep=True)

    ftcEligibleDF = baseMatchDF[baseMatchDF.FTC_ELIGIBLE == 'Y']
    nonFtcEligibleDF = baseMatchDF[baseMatchDF.FTC_ELIGIBLE == 'N']

    if addOn:
        keyDataFrames['ftcEligibleDF_{}_{}'.format(addOn, inc)] = ftcEligibleDF
        keyDataFrames['nonFtcEligibleDF{}_{}'.format(addOn, inc)] = nonFtcEligibleDF
    else:
        keyDataFrames['ftcEligibleDF_ClientList'] = ftcEligibleDF
        keyDataFrames['nonFtcEligibleDF_ClientList'] = nonFtcEligibleDF   

    if isTargeting == 'No':
        totalNonEligibleFTC = len(nonFtcEligibleDF)
        # For presales we don't actually dedupe these users so we want to returnt he full match set but also the count of HOW MANY WOULD be deduped
        finalFTCDF = dataframe

    else:
        totalNonEligibleFTC = len(nonFtcEligibleDF)
        finalFTCDF = ftcEligibleDF

    return finalFTCDF, totalNonEligibleFTC



def runDataviewer():
    reviewResults = input('Would You Like to Review the Tables in the Dataviewer (Y/N): ')

    if reviewResults.lower() not in ['y', 'n', 'no', 'yes']:
        print('Invalid Input Please Respond with "Y" or "N"')
        runDataviewer()
    else:
        if reviewResults.lower() in ['y', 'yes']:
            print('Exporting Dataframes and building Dataviewer. Please wait 1 - 2 minutes. . .')
            jsonDataFrames = {}
            for key, val in keyDataFrames.items():
                if isinstance(val, pd.core.frame.DataFrame):
                    jsonDataFrames[key] = val.to_json()

            userhome = os.path.expanduser('~')
            desktop = os.path.join(userhome, 'Desktop')

            with open(os.path.join(desktop, 'GitHub_Python\\Targeting\\TestList', 'dataFrames.json'), 'w') as outfile2:
                json.dump(jsonDataFrames, outfile2, indent=2, sort_keys=True)

            print('Export Complete . . . Now reading Dataframes into the Data Viewer . . .')
            subprocess.call(['python.exe', os.path.join(desktop, 'GitHub_Python\\Targeting\\TestList','dataviewer.py'), 'dataFrames.json'], shell=True)
        else:
            print('Program Finished!')



def formatFileNameCount(dataFrame):
    fileCount = len(dataFrame)
    maxLength = 8
    neededLength = maxLength-len(str(fileCount))
    newTNumLength = len(str(fileCount))+neededLength
    finalFormat = str(fileCount).rjust(newTNumLength)

    return finalFormat



# Targeting Functions
def exportTargetFiles(dataFrame, tNumbersDict, exportPaths):
    exportColumns = ['USER_ID'] 
    matchedData = dataFrame

    for tKey, val in tNumbersDict.items():
        if val == 'whole_list':
            for path in exportPaths:
                matchedData.to_csv(os.path.join(path, '{tNum}_{exportCount}.csv'.format(tNum=tKey, exportCount=formatFileNameCount(matchedData))), columns=exportColumns, index=False)
        else:
            matchedData = keyDataFrames[val]
            for path in exportPaths:
                matchedData.to_csv(os.path.join(path, '{tNum}_{exportCount}.csv'.format(tNum=tKey, exportCount=formatFileNameCount(matchedData))), columns=exportColumns, index=False)



def exportDatasharingFiles(dataFrame, datasharingColumns, tNumbersDict, dSharingPath):
    exportColumns = ['USER_ID']
    exportColumns.extend(datasharingColumns)
    matchedData = dataFrame

    for tKey, val in tNumbersDict.items():
        if val == 'whole_list' and not val.startswith(('sda', 'bda')):
            matchedData.to_csv(os.path.join(dSharingPath, '{tNum}_{manu}_DS_{exportCount}.csv'.format(tNum=tKey, manu=manu, exportCount=formatFileNameCount(matchedData))), columns=exportColumns, index=False)

        else:
            if not val.startswith(('sda', 'bda')):
                matchedData = keyDataFrames[val]
                matchedData.to_csv(os.path.join(dSharingPath, '{tNum}_{manu}_DS_{exportCount}.csv'.format(tNum=tKey, manu=manu, exportCount=formatFileNameCount(matchedData))), columns=exportColumns, index=False)



# NOT YET WRAPPED IN FUNCTIONS CALL ALL THIS AFTER FUNCTION DEFS
# *****************************************************************************

#Get CLient LIst File Matched data and Price

# determine to match target file list or use a previous ran match file as well if we are running sda or bda only.
    #if so we need to still fetch out baseTable data the matchCLientList() function does but wont happen.
if bda_only == 'Yes' or sda_only == 'Yes' or loadedMatchDF != '':
    keyDataFrames['baseData'] = fetchBaseTable(caseType)
    if loadedMatchDF != '':
        keyDataFrames['finalMatch'] = targetListDF

        matchLogger('Using previous matched file', indent='Yes')
        matchLogger('Total NON ELIGIBLE FTC USERS (To be Deduped during Targeting): {ftc_non_eligible}\n'.format(ftc_non_eligible=keyDataFrames['nonFTCEligible']), indent='Yes')
    
else:
    matchClientList(targetFile, targetListDF, matchType, caseType, suppMatch='No')
    matchLogger('Total NON ELIGIBLE FTC USERS (To be Deduped during Targeting): {ftc_non_eligible}\n'.format(ftc_non_eligible=keyDataFrames['nonFTCEligible']), indent='Yes')


# suppress match file if there is one loaded
if suppFile != '':
    matchLogger('Running Suppression File Match', indent='Yes')
    matchClientList(suppFile, suppDF, matchType, caseType, suppMatch='Yes')

    if supp_sda_only == 'Yes' or supp_bda_only == 'Yes':
        keyDataFrames['finalMatch'] = keyDataFrames['finalMatch']

    elif supp_sda_only == 'No' and supp_bda_only == 'No':
        keyDataFrames['finalMatch'] = dedupeDataframe(keyDataFrames['finalMatch'], 'USER_ID', dFColToList(keyDataFrames['finalMatch_Supp'], 'USER_ID'))


if bda_only == 'No' and sda_only == 'No':
    totalPrice = priceDataFrame(keyDataFrames['finalMatch'], caseType, addOn=None, dfName='ClientList')[0]

    #get values needed for Complete list match results 
    #*********************************************************************
    clientListCount = len(targetListDF.index)
    matchedCount = len(keyDataFrames['finalMatch'].index)
    matchRate = str(round((matchedCount/clientListCount)*100))+'%'
    gaurantee_percent = gauranteeRateCalculator([keyDataFrames['finalMatch']])

    #export final match file
    keyDataFrames['finalMatch'].to_csv('finalMatch_{}.csv'.format(matchedCount))

    #Store as list of data to populate in Datafram
    matchRateData = [clientListCount, matchedCount, matchRate, gaurantee_percent]

    #create dataframe of values that will be converted to HTML in the email
    matchRateDF = pd.DataFrame(data = [commaFormatting(matchRateData)], columns=['Original Client\nList Count', 'Campaign Eligible\nMatch Count', 'Campaign Eligible\nMatch Rate', 'Minimum Message\nOpen Guarantee %'])





    #Determin Top MD-DO's Counts and Percentage Chart for Email
    #***************************************************************************
    finalPricingDF = priceDataFrame(keyDataFrames['finalMatch'], 'DocAlert')[1]
    topOccSpecsDF = finalPricingDF.sort_values(by=['count'], ascending=False)
    topOccSpecsDF = topOccSpecsDF.query('occspec.str.contains("MD/DO - ") & occspec.str.contains("Student|Other")==False', engine='python')[['occspec', 'count']]
    totalMDDOCount = int(topOccSpecsDF['count'].sum())

    keyDataFrames['topOccSpecsDF'] = topOccSpecsDF

    topOccSpecsDF['Specialty'] = topOccSpecsDF['occspec'].str.replace('MD/DO - ', '')
    # topOccSpecsDF['Percentage_Pre'] = (round((topOccSpecsDF['count']/len(keyDataFrames['finalMatch'].index))*100).astype(int))
    topOccSpecsDF['Percentage_Pre'] = (round((topOccSpecsDF['count']/totalMDDOCount)*100).astype(int))

    # Dynamically find how many specialties to include in this chart where values are greated than 2
    topOccSpecsDF = topOccSpecsDF[topOccSpecsDF['Percentage_Pre'] >= 1]
    if len(topOccSpecsDF.index) > 5:
        topOccSpecsDF = topOccSpecsDF.head()
        totalTopOccs = 5
    else:
        topOccSpecsDF = topOccSpecsDF.head(n=len(topOccSpecsDF.index))
        totalTopOccs = len(topOccSpecsDF.index)

    #Create new final Percent column as string with % sign, drop uneeded columns
    topOccSpecsDF['Percentage'] = topOccSpecsDF['Percentage_Pre'].astype(str)+'%'
    topOccSpecsDF = topOccSpecsDF.drop(['occspec', 'count', 'Percentage_Pre'], axis=1)
    topOccupationsDF = topOccSpecsDF.reset_index(drop=True)
else:
    matchLogger('No Main Match being Performed. . . SDA(s) and/or BDA(s) Only\n', indent='Yes')



# Email Testing
#**************************************************************


# import email file and start populating match results via format statment
emailFile = open('Presales_Email.html', 'r')
myMessage = emailFile.read()
emailFile.close()

if sda_only == 'No' and bda_only == 'No':
    # setPriceVariables
    # [0] = priceText (Formated Price over 20k), [1] returns priceText2 which is if price is under 20k
    priceData = priceForEmail(keyDataFrames['finalMatch'])
    activeDaysData = get_30_60_90([30,60,90])
    
    matchEmailData = """<span style='font-family:"Arial",sans-serif;color:#102038'>
                            Additionally, for your reference, the numbers segmented by Occupation are as follows:<br><br>

                            Count of Campaign Eligible MD/DOs: {totalMDDOCount}:<br>
                            Count of Campaign Eligible Other HCPs: {otherHCP}:<br><br>

                            <b><u>Pricing:</u></b><br><br>

                            <b><i>Note:</b> Please refer to the rate card for net open rate guarantee parameters and whether the targeting
                            scenario(s) outlined below are eligible for a guarantee.</i><br><br>

                            Of the Campaign Eligible MD\DOs (count {totalMDDOCount}), the top {totalTopOccs} specialties are broken out as
                            follows:<br><br>

                            topOccSpecsHere<br><br>

                            Based on the specialty break-out results, the price for a wave comes to the following:<br>
                            {priceText}<br><br>

                            {priceText2}<br><br>

                            <b><u>{daysActiveTitle}</u></b><br><br>

                            30_60_90_Active_Data_Here<br><br>

                        </span></span><br>""".format(totalMDDOCount=commaFormatting(totalMDDOCount), otherHCP=commaFormatting(matchedCount-totalMDDOCount), totalTopOccs=totalTopOccs, priceText=priceData[0], priceText2=priceData[1], daysActiveTitle=activeDaysData[1])
    
    myMessage = myMessage.replace('matchDataHere', matchEmailData)
    myMessage = myMessage.replace('matchRateDataHere', styleDataFrame(matchRateDF, defaultProps))
    myMessage = myMessage.replace('30_60_90_Active_Data_Here', styleDataFrame(activeDaysData[0], defaultProps))
    myMessage = myMessage.replace('topOccSpecsHere', styleDataFrame(topOccupationsDF, topSpecProps, ['Specialty']))

else:
    matchEmailData = ''
    myMessage = myMessage.replace('matchDataHere', matchEmailData)
    myMessage = myMessage.replace('matchRateDataHere<br><br>', '')


#Segmentation DF looping to populate myMessage with HTML
if len(segmentation) != 0 and sda_only == 'No' and bda_only == 'No':
    segInc = 1
    segmentDataFrames = segmentToDataFrame(segmentation, 'DocAlert')
    segmentDataFrames30_60_90 = segment_30_60_90(segmentation, [30, 60, 90])

    segmentDataColumns = ['Original Client List\nSegment Count', 'Campaign Eligible\nSegment Match Count', 'Campaign Eligible\nSegment Match Rate', 'Campaign Eligible\nSegment Price']
    segmentParts = """<span style='font-family:"Arial",sans-serif;color:#102038'>
                        <b><u>Requested Client Segmentation</u></b>
                        </span></span><br><br><br>
                    """

    for seg, dF in segmentDataFrames.items():
        segmentHTML = styleDataFrame(dF, defaultProps, segmentDataColumns)
        #EXCUTE the 30_60_90 Segs here to go under main segmentation
        if run_30_60_90_Segs == 'Yes':
            full_30_60_90 = ""

            for seg_369, dF_369 in segmentDataFrames30_60_90.items():
                if re.search('.+_{seg}'.format(seg=seg), seg_369):
                    segment30_60_90_HTML = styleDataFrame(dF_369, defaultProps)

                    # build all 30 60 90 segs at once to append under main segment below
                    part_30_60_90 = """{in30_60_90_Segs}<br><br>""".format(in30_60_90_Segs=segment30_60_90_HTML)
                    full_30_60_90 += part_30_60_90
        else:
            full_30_60_90 = ""


        myMessagePart = """
                        <BODY>
                            <span style='font-family:"Arial",sans-serif;color:#102038'>
                                The break-out by "{segment}" is as follows:
                                </span></span><br><br>
                                {htmlTable}
                                <br><br>
                                {in30_60_90_Segs}
                            </font>
                        </BODY>
                    """.format(htmlTable=segmentHTML, segment=seg, in30_60_90_Segs=full_30_60_90)

        segmentParts += myMessagePart
        # matchLogger('Segmentation for {segment} COMPLETE'.format(segment = segmentation[segInc-1]), indent='Yes')
        segInc += 1

    myMessage = myMessage.replace('segmentStuffHere', segmentParts)

else:
    myMessage = myMessage.replace('segmentStuffHere<br><br>', '')


# Pivot Chart Data
if len(pivotVariables) != 0:
    segment1 = pivotVariables[0]
    segment2 = pivotVariables[1]
    print(segment1, segment2)
    pivotTableHTML = styleDataFrame(segmentPivotChart(segment1, segment2), defaultProps)
    pivotParts = """<BODY>
                        <span style='font-family:"Arial",sans-serif;color:#102038'>
                            The break-out by "{segment1}" * "{segment2}" is as follows:
                            </span></span><br><br>
                            {htmlTable}
                            <br>
                        </font>
                    </BODY>""".format(segment1=segment1, segment2=segment2, htmlTable=pivotTableHTML)
    # matchLogger('Pivot Chart for {} * {} Complete'.format(segment1, segment2), indent='Yes')
    myMessage = myMessage.replace('segmentPivotDataHere', pivotParts)
else:
    myMessage = myMessage.replace('segmentPivotDataHere<br><br>', '')


#sdaTables looping
if len(sdaDict) != 0:
    sdaParts = ""
    sdaInc = 1
    for k, d in sdaDict.items():
        sdaAllData = sdaMatch(keyDataFrames['baseData'], d['occs'], d['specs'], sdaInc)
        sdaHTML = styleDataFrame(sdaAllData[0], defaultProps)

        #call sda gaur function here
        if sda_only == 'Yes':
            sda_gaurantee_rate = gauranteeRateCalculator([keyDataFrames['sda_{inc}_Match_Final_User_Profile'.format(inc=sdaInc)]])
        else:
            sda_gaurantee_rate = gauranteeRateCalculator([keyDataFrames['finalMatch_User_Profile'], keyDataFrames['sda_{inc}_Match_Final_User_Profile'.format(inc=sdaInc)]])

        mySDAMessagePart = """
                        <BODY>
                            <span style='font-family:"Arial",sans-serif;color:#102038'>
                                <b><u>SDA OPTION {inc}</b></u><br><br>

                                The total size of the client list and specialty is <b>{totalUsers}</b> campaign eligible users. The total price to target all these users is <b>{cashMoney}</b> per wave. The guarantee amount is <b>{sda_guar}</b><br><br>
                                {htmlTable}
                                <br><br>
                                * {occs} who specialize in {specs}<br><br>
                                </span></span><br><br>
                            </font>
                        </BODY>
                    """.format(htmlTable=sdaHTML, inc=sdaInc, totalUsers=sdaAllData[1] , cashMoney=sdaAllData[2], occs=', '.join(sdaAllData[3]), specs=', '.join(sdaAllData[4]), sda_guar=sda_gaurantee_rate)

        sdaParts += mySDAMessagePart
        # matchLogger('SDA OPTION {inc} COMPLETE'.format(inc=sdaInc), indent='Yes')
        sdaInc += 1
else:
    sdaParts = ""


#bdaTables Looping
if len(bdaDict) != 0:
    bdaParts = ""
    bdaInc = 1
    for k, d in bdaDict.items():
        bdaAllData = bdaMatch(keyDataFrames['baseData'], d['occs'], d['specs'], d['dedupe'], d['lookupPeriod'], d['drugList'], d['queryByTherapy'], d['numLookUps'], d['dedupeFrom'], bdaInc)
        bdaHTML = styleDataFrame(bdaAllData[0], addOnProps, ['Criteria'])

        if bda_only == 'Yes':
            bda_gaurantee_rate = gauranteeRateCalculator([keyDataFrames['bda_{inc}_Match_Final_User_Profile'.format(inc=bdaInc)]])
        else:
            bda_gaurantee_rate = gauranteeRateCalculator([keyDataFrames['finalMatch_User_Profile'], keyDataFrames['bda_{inc}_Match_Final_User_Profile'.format(inc=bdaInc)]])

        if d['dedupeFrom'] != 'N/A':
            bdaText = """* {occs} who specialize in {specs}<br>""".format(occs=', '.join(sdaDict[d['dedupeFrom']]['occs']), specs=', '.join(sdaDict[d['dedupeFrom']]['specs']))
        else:
            bdaText = """<br>"""

        myBDAMessagePart = """
                        <BODY>
                            <span style='font-family:"Arial",sans-serif;color:#102038'>
                                <b><u>BDA OPTION {inc}</b></u><br><br>

                                The total size of the client list and behavioral is <b>{totalUsers}</b> campaign eligible users. The total price to target all these users is <b>{cashMoney}</b> per wave. The guarantee amount is <b>{bda_guar}<br><br>
                                {htmlTable}
                                <br>
                                {bdaStuff}
                                ** Campaign eligible {occs} who specialize in {specs} and who have looked up Drugs {drugs} {numLookUps}+ Times in the past {days}<br><br>
                                </span></span><br><br>
                            </font>
                        </BODY>
                    """.format(htmlTable=bdaHTML, inc=bdaInc, totalUsers=bdaAllData[1] , cashMoney=bdaAllData[2], occs=', '.join(bdaAllData[3]), specs=', '.join(bdaAllData[4]), drugs=', '.join(bdaAllData[5]), numLookUps=bdaAllData[6], days=bdaAllData[7]-1, bdaStuff=bdaText, bda_guar=bda_gaurantee_rate)
        bdaParts += myBDAMessagePart
        # matchLogger('BDA OPTION {inc} COMPLETE'.format(inc=bdaInc), indent='Yes')
        bdaInc += 1
else:
    bdaParts = ""

#Find and replace proper sections of email with formated HTML Coding


myMessage = myMessage.replace('sdaDataHere', sdaParts)
myMessage = myMessage.replace('bdaDataHere', bdaParts)

outlook = Dispatch("Outlook.Application")

#Contruct a message Body found above ^
# Found the below syntax is needed to build outlook object to send message. 
msg = outlook.CreateItem(0)
msg.To = '{}@athenahealth.com'.format('asinger')
# msg.CC = emailCC

msg.Subject = 'Segment Test'

msg.GetInspector
index = msg.HTMLbody.find('>', msg.HTMLbody.find('<body'))
msg.HTMLbody = msg.HTMLbody[:index + 1] + myMessage + msg.HTMLbody[index + 1:]
# msg.HTMLBody = myMessage

msg.Display(False)
# msg.BodyFormat = '3'
msg.Send()
matchLogger('Email Sent!', indent='No')




# TO TEST TARGETING EXPORTS
if isTargeting == 'Yes':
    exportTargetFiles(keyDataFrames['finalMatch'], target_numbers, exportPaths)
    if len(datasharingColumns) > 0:
        exportDatasharingFiles(keyDataFrames['finalMatch'], datasharingColumns, target_numbers, dSharingPath)



runDataviewer()



#A Function to import all keyDataFrames Dictionary into tables in a DB if needed for investigation

# def keyDataFramesToDB():
#     conn = sqlite3.connect(os.path.join('C:\\Users\\asinger\\Desktop\\GitHub_Python\\Targeting\\TestList', 'match_results.db'))
#     conn.text_factory = str
#     cur = conn.cursor()

#     for key, df in keyDataFrames.items():
#         if key != 'baseData':
#             #Code i found to rename dup column names which throws error on import to DB
        
#             cols=pd.Series(df.columns.str.upper())
#             for dup in cols[cols.duplicated()].unique(): 
#                 cols[cols[cols == dup].index.values.tolist()] = [dup + '_' + str(i) if i != 0 else dup for i in range(sum(cols == dup))]
#             df.columns=cols

#             df.to_sql('{}'.format(key), conn, if_exists='replace', index=False)

# keyDataFramesToDB()






