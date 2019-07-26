from openpyxl import Workbook, load_workbook
import re
import os
import sys
import xlrd
import csv
from shutil import copyfile
from fuzzywuzzy import fuzz
from fuzzywuzzy import process
# import psycopg2
import unicodecsv
# import pprint
from collections import Counter
import datetime
import json
import subprocess
from os import listdir
from os.path import isfile, join
from termcolor import *
from colorama import init, Fore, Back, Style
import time
import pandas
import sqlite3
import random
import utils as utils
from threading import Thread

init(autoreset=True)

args = sys.argv[1:]

listText = 'target.txt'
colList = []
finalDrugs = []
unmatchedDrugs = []
segmentList = []
segmentListSingle = []
fullNameList = []
colLength = None
csvFile = 'target.csv'
csvFileMod = 'target_mod.csv'
csvFileModTemp = 'target_mod_temp.csv'
csvFileModTemp2 = 'target_mod_temp2.csv'
csvFileFinal = 'target_final.csv'
dt = str(datetime.datetime.now().strftime("%Y%m%d"))

inc = 0


#Excludes SPecial Datasharing clients
cmiCompasSegmentation = "npi, address1, campaign_type, city, cl_fname, cl_lname, cl_me, cl_zip, clientid, compasid, middle_name, segment1, specialty, state_code, tier, segment2, segment3"
cmiCompasSQL = "address1, campaign_type, city, fname as cl_fname, lname as cl_lname, me as cl_me, zip as cl_zip, clientid, compasid, middle_name, segment1, specialty, state_code, tier, segment2, segment3"
cmiList = ['npi', 'address1', 'campaign_type', 'city', 'cl_fname', 'cl_lname', 'cl_me', 'cl_zip', 'clientid', 'compasid', 'middle_name', 'segment1', 'specialty', 'state_code', 'tier', 'segment2', 'segment3']


userhome = os.path.expanduser('~')
desktop = userhome + '\\Desktop\\'
downloads = userhome + '\\Downloads\\'

zipsFile = os.path.join(downloads, 'zipsImport.csv')

#Custom DataSHaring Client
with open(os.path.join(desktop, 'Ewok\\Datasharing', 'dataSharing.json'), 'r') as infile:
	config2 = json.loads(infile.read(), encoding='utf8')

specialDataSharingDict = config2

# configFile = os.path.join(desktop, 'config.json')

randomList = []
with open('G:\\Communicator Ops\\Epocrates\\Python Files\\Import Phrases\\importPhrases.csv', 'r') as myPhrases:
	reader = csv.reader(myPhrases)
	for row in reader:
		for item in row:
			randomList.append(item)

# randomList = ['Indubitably', 'The first thing you gotta do is say . . . WOULD YOU LOOK AT THAT?', 'Tootles', 'This burrito is sooooo Filling', 'Have you seen Broke Back Rhonda? It Rhond-tastic!', 'How much wood would a woodchuck chuck if a woodchuck could chuck wood?']

with open(os.path.join(desktop, 'TheEagleHasLanded.csv'), 'r') as passFile:
	reader = csv.DictReader(passFile)
	for item in reader:
		password = item['password']

utils.codeCounter()

if len(args) > 0:
	with open(os.path.join(desktop, 'Ewok\\Configs', args[0]), 'r') as infile:
		config = json.loads(infile.read(), encoding='utf8')
		foundFullName = 'n'
		if 'foundFullName' in config:
			foundFullName = config['foundFullName']
		if 'queryStates' in config:
			queryStates = str(config['queryStates'])
			queryZips = str(config['queryZips'])
			applyToClientList = str(config['applyToClientList'])
			applyToSda = str(config['applyToSda'])
			applyToBda = str(config['applyToBda'])
			if queryStates == 'Yes':
				statesToQuery = str(config['statesToQuery'])
			else:
				statesToQuery = ''
		if 'queryStates' not in config:
			queryStates = ''
			queryZips = ''
			applyToClientList = ''
			applyToSda = ''
			applyToBda = ''
			statesToQuery = ''
		caseType = str(config['caseType'])
		therapyClass = str(config['therapyChecked'])
		sDa_only = str(config['sdaOnly'])
		bDa_only = str(config['bdaOnly'])
		# finalSDATotal = int(config["totalAdditionalSDAs"]) + 1
		createPivotTable = str(config['createPivotTable'])
		if createPivotTable == 'Y':
			pivSeg1 = str(config['pivotSeg1']).lower()
			pivSeg2 = str(config['pivotSeg2']).lower()
		if createPivotTable == 'N':
			pivSeg1 = ""
			pivSeg2 = ""
		if caseType == 'listMatch':
			nbeTarget = 'No'
			suppApplied = str(config['suppressionApplied'])
			listProduct = str(config['listProduct'])
			listMatchType = str(config['listMatchType'])
			manu = str(config['Manu'])
			if listMatchType == 'Standard_Seg' or listMatchType == 'Exact_Seg':
				addSeg1 = config['finalSegs']
				addSeg = ", ".join(addSeg1).lower().replace('Group', '_group').replace('group', '_group').replace('GROUP', '_group')
				finalSeg = addSeg.split(', ')
				for seg in finalSeg:
					if seg.startswith(('0','1','2','3','4','5','6','7','8','9')):
						seg = '_' + seg
					segmentList.append(str(seg).replace(' ', '_'))
					splitList = ", ".join(segmentList)
			brand = str(config['Brand'])
			yourIn = str(config['yourIn'])
			reIn = str(config['reIn'])
			sDa = str(config['sDa'])
			name = "{requester}_{manufact}_{brand}_{dt}_{initials}".format(requester=reIn, manufact=manu, brand=brand, dt=dt, initials=yourIn)
			if sDa == 'y':
				finalSDATotal = str(int(config["totalAdditionalSDAs"]) + 1)
				SDA_Occ = str(config['SDA_Occ'])
				SDA_Spec = str(config['SDA_Spec'])
				SDA_Occ2 = SDA_Occ.replace('"', '')
			if sDa == 'n':
				finalSDATotal = '0'
				SDA_Occ = '""'
				SDA_Spec = '""'
				SDA_Occ2 = ''
			bDa = str(config['bDa'])
			if (bDa == 'y' and sDa == 'n') or (bDa == 'y' and sDa == 'y'):
				finalBDATotal = str(int(config["totalAdditionalBDAs"]) + 1)
				deDup = str(config['deDup'])
				lookUpPeriod = str(config['lookUpPeriod'])
				displayPeriod = str(int(lookUpPeriod)-1)
				totalLookUps = str(config['totalLookUps'])
				occupation = str(config['occupation'])
				specialty = str(config['specialty'])
				occupation2 = occupation.replace('"', '')
				drugList = str(config['drugList'])
				drugsnocomma = str(config['drugList']).replace("\n", ", ").replace("'", '')
			if bDa == 'n':
				finalBDATotal = '0'
				deDup = ""
				lookUpPeriod = ""
				displayPeriod = ""
				totalLookUps = ""
				occupation = '""'
				specialty = '""'
				drugList = ";"
				occupation2 = ''
				drugsnocomma = ''
			caseno = str(config['caseno'])
			mtype = str(config['mtype'])
			SE = str(config['SE'])
			email = str(config['email'])
			tableName = str(config['tableName'])
		elif caseType == 'Targeting':
			randomSplit = str(config['randomSplit'])
			openerIDs = str(config['openerScheduleIDS'])
			nbeTarget = str(config['nbeTarget'])
			suppSDAOnly = str(config['suppSDAOnly'])
			suppBDAOnly = str(config['suppBDAOnly'])
			backFill = str(config['backFill'])
			dataCap = str(config['dataCap'])
			suppApplied = str(config['suppressionApplied'])
			listProduct = str(config['listProduct'])
			listMatchType = str(config['listMatchType'])
			manu = str(config['Manu'])
			date = str(config['date'])
			brand = str(config['Brand'])
			sDa_only = str(config['sdaOnly'])
			bDa_only = str(config['bdaOnly'])

			outFileFinal2 = """P:\\Epocrates Analytics\\TARGETS\\{date}\\{manu} {brand}\\target.txt""".format(date = date, manu = manu, brand = brand)
			outCode3 = """P:\\Epocrates Analytics\\TARGETS\\{date}\\{manu} {brand}""".format(date = date, slashes = "\\", manu = manu, brand = brand)
			rawOutfile = outCode3
			sdaBDAOnly = ""
			targetFolder = manu+" "+brand
			if suppApplied == 'Yes':
				suppFileLocation = "P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Supp".format(date = date, slashes = "\\", targetFolder=targetFolder)
			else:
				suppFileLocation = ''

			if bDa_only  == 'N' and sDa_only == 'N':
				if listMatchType == 'Standard' or listMatchType == 'Exact':
					if randomSplit == 'No':
						targetNum = str(config['targetNum'])
						targetNum2 = ''
					else:
						targetNum = str(config['targetNum'])
						targetNums = targetNum.split(' ')
						targetNum = targetNums[0]
						targetNum2 = targetNums[1]
					segVariable = str(config['segVariable']).lower()
					varValues = ''
					neededValues = ''
					backFillValue = ''
					# if specialDataSharingDict[manu]:
					# 	finalSpecDataSharing = specialDataSharingDict[manu]

				if listMatchType == 'Standard_Seg' or listMatchType == 'Exact_Seg':
					targetNum = str(config['targetNum'])
					targetNum2 = ''
					segVariable = str(config['segVariable']).lower()
					varValues = str(config['varValues'])
					neededValues = str(config['neededSegs'])
					backFillValue = str(config['backFillSeg'])
					# if specialDataSharingDict[manu]:
					# 	finalSpecDataSharing = specialDataSharingDict[manu]+', '+ segVariable

			if bDa_only  == 'Y' or sDa_only == 'Y':
				segVariable = str(config['segVariable']).lower()
				varValues = ''
				neededValues = ''
				backFillValue = ''
				targetNum = ''
				targetNum2 = ''
				listMatchType = 'None'
				neededValues = ''
				backFillValue = ''
			dSharing = str(config['dSharing'])
			if dSharing == 'Y' and config['cmi_compass_client'] == 'N':
				if manu not in ['Merck', 'AstraZeneca', 'Novartis', 'GSK', 'Boehringer', 'Amgen', 'Biogen', 'Sanofi-Aventis', 'AbbVie']:
					addSeg1 = config['finalSegs']
					addSeg = ", ".join(addSeg1).lower().replace('Group', '_group').replace('group', '_group').replace('GROUP', '_group')
					if config['segVariable'] != "":
						finalSeg = addSeg.split(', ')
						finalSeg.append(segVariable)
						print(finalSeg)
						for seg in finalSeg:    
							segmentList.append(str(seg).replace(' ', '_'))
							splitList = ", ".join(segmentList)
						print(segmentList)
						print(splitList)
					
					if segVariable == '':
						finalSeg = addSeg.split(', ')
						for seg in finalSeg:    
							segmentList.append(str(seg).replace(' ', '_'))
							splitList = ", ".join(segmentList)
						print(segmentList)
						print(splitList)
				else:
					print('IM USING THE NEW FUNCTION TO MAKE DA SQL AND SEGMETNS')
					splitList = utils.prepSqlSegments(listMatchType)
					segmentList = utils.prepSasSegments(listMatchType)
					
			if dSharing == 'Y' and config['cmi_compass_client'] == 'Y':
				if manu not in ['Merck', 'AstraZeneca', 'Novartis', 'GSK', 'Boehringer', 'Amgen', 'Biogen', 'Sanofi-Aventis', 'AbbVie']:
					addSeg = cmiCompasSegmentation
					segVariable = str(config['segVariable']).lower()
					if config['segVariable'] != "":
						# finalSeg = addSeg.split(', ')
						# finalSeg.append(segVariable)
						# for seg in finalSeg:
						# 	if seg != segVariable:
						# 		segmentList.append(str(seg).replace(' ', '_'))
						cmiSegCheck = addSeg.split(', ')
						if segVariable.lower() in cmiSegCheck:
							segmentList = addSeg.split(', ')
						if segVariable.lower() not in cmiSegCheck:
							segmentList = str(addSeg + ', ' + segVariable).split(', ')

						cmiSqlCheck = cmiCompasSQL.split(', ')
						if segVariable.lower() in cmiSqlCheck:
							splitList = cmiCompasSQL
						if segVariable.lower() not in cmiSqlCheck:
							splitList = cmiCompasSQL + ', ' + segVariable

					
					if segVariable == '':
						finalSeg = addSeg.split(', ')
						for seg in finalSeg:
							segmentList.append(str(seg).replace(' ', '_'))
							splitList = cmiCompasSQL
							# splitList = splitList.replace('npi, ', '')
				else:
					print('IM USING THE NEW FUNCTION TO MAKE DA SQL AND SEGMETNS')
					splitList = utils.prepSqlSegments(listMatchType)
					segmentList = utils.prepSasSegments(listMatchType)

			if dSharing == 'N' and bDa_only  == 'N' and sDa_only == 'N':
				segmentList = str(config['segVariable']).lower().replace(' ', '_')
				keep_seg = str(config['keep_seg'])
				splitList = segmentList
				segmentList = segmentList.split()
				# if config['segVariable'] != "":
				# 	segmentList = segmentList

			if dSharing == 'N' and (bDa_only  == 'Y' or sDa_only == 'Y'):
				dSharing = 'N'
				segmentList = []
				keep_seg = str(config['keep_seg'])
			keep_seg = str(config['keep_seg'])
			yourIn = str(config['yourIn'])
			sDa = str(config['sDa'])
			name = "T_{manu}_{brand}_{dt}_{initials}".format(manu=manu, brand=brand, dt=dt, initials=yourIn)
			if sDa == 'y':
				sDa_only = sDa_only
				SDA_Occ = str(config['SDA_Occ'])
				SDA_Spec = str(config['SDA_Spec'])
				SDA_Occ2 = SDA_Occ.replace('"', '')
				SDA_Target = str(config['SDA_Target'])
			if sDa == 'n':
				sDa_only = sDa_only
				SDA_Occ = '""'
				SDA_Spec = '""'
				SDA_Occ2 = ''
				SDA_Target = ''
			bDa = str(config['bDa'])
			if (bDa == 'y' and sDa == 'n') or (bDa == 'y' and sDa == 'y'):
				bDa_only = bDa_only
				deDup = str(config['deDup'])
				lookUpPeriod = str(config['lookUpPeriod'])
				displayPeriod = str(int(lookUpPeriod)-1)
				totalLookUps = str(config['totalLookUps'])
				occupation = str(config['occupation'])
				specialty = str(config['specialty'])
				BDA_Target = str(config['BDA_Target'])
				occupation2 = occupation.replace('"', '')
				drugList = str(config['drugList'])
				drugsnocomma = str(config['drugList']).replace("\n", ", ")
				# print drugsnocomma
				# drugsnocomma = ", ".join(drugList2)
			if bDa == 'n':
				bDa_only = bDa_only
				deDup = ""
				lookUpPeriod = ""
				totalLookUps = ""
				occupation = '""'
				specialty = '""'
				BDA_Target = ''
				drugList = ""
				occupation2 = ''
				drugsnocomma = ''
			if nbeTarget == 'Yes':
				manu = str(config['Manu'])
				date = str(config['date'])
				brand = str(config['Brand'])
				# if os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\target.txt'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
				if utils.codeCountReader() > 1:
					print('Im on the second File and going to do black magic here :')
					listMatchType = str(config['organicMatchType'])
					targetNum = str(config['organicTargetNumber'])
					splitList = utils.prepSqlSegments(str(config['organicMatchType']))
					segmentList = utils.prepSasSegments(str(config['organicMatchType']))

			tableName = str(config['tableName'])


userhome = os.path.expanduser('~')
# downloads = userhome + '\\Downloads\\'
newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))
extension = os.path.splitext(os.path.join(downloads, newest))
justwork = downloads + listText

#MastDrug File
masterDrugs = 'P:\\Epocrates Analytics\\Drug Compare\\Master Drug List\\drugs.csv'

#Set input File and Output File as well as establish default list of source attributes
outFile = """P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}{slashes}""".format(folderName = name, slashes = "\\")
outFileFinal = """P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}\\target.txt""".format(folderName = name)
outCode = """P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}""".format(folderName = name)
# if caseType == 'Targeting':
# 	outFileFinal2 = """P:\\Epocrates Analytics\\TARGETS\\{date}\\{manu} {brand}\\target.txt""".format(date = date, manu = manu, brand = brand)
# 	outCode3 = """P:\\Epocrates Analytics\\TARGETS\\{date}\\{manu} {brand}""".format(date = date, slashes = "\\", manu = manu, brand = brand)
# 	rawOutfile = outCode3
# 	sdaBDAOnly = ""
# 	targetFolder = manu+" "+brand
# 	if suppApplied == 'Yes':
# 		suppFileLocation = "P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Supp".format(date = date, slashes = "\\", targetFolder=targetFolder)
# 	else:
# 		suppFileLocation = ''
if caseType == 'listMatch':
	if suppApplied == 'Yes':
		suppFileLocation = "P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}\\Supp".format(folderName = name)
	else:
		suppFileLocation = ''
segmentListSingle = []

#Set Sas Code Variables
targetAuto = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\Targeting Automation Code_OFFICIAL.sas'
targetAutoOrganic = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\Targeting Automation Code_ORGANIC.sas'
basicMatch = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\TGT_NPI_ME_3PT_20170515.sas'
dataSharing = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\TGT_NPI_ME_3PT_DataSharing_20170515.sas'
autoCode = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\Presales Automation.sas'
emailCode = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\Presales Automation_Email_Final.sas'
supressionCode = "P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\Code Housing\\for_email\\Supp_Auto_DONOTEDIT\\Presales Automation_Email_Final_Suppressed.sas"

def createFolders():
	if caseType == 'listMatch':
		if os.path.exists(os.path.join("P:\\Epocrates Analytics\\List Match\\List Match Folder", name)):
			print(colored('List Match Folder "'+name+'" Already Exists . . . Skipping Creation', 'yellow'))
			print('------------------------------------------------------------------------------------')
			print('')
		if not os.path.exists(os.path.join("P:\\Epocrates Analytics\\List Match\\List Match Folder", name)):
			os.chdir("P:\\Epocrates Analytics\\List Match\\List Match Folder\\")
			os.mkdir(name)

	if caseType == 'Targeting':
		targetFolder = manu+" "+brand
		if os.path.exists("P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}".format(date = date, slashes = "\\", targetFolder=targetFolder)):
			print(colored('TARGETS Folder '+ manu + ' ' + brand + ' Already Exists . . . Skipping Creation', 'yellow'))
		if not os.path.exists("P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}".format(date = date, slashes = "\\", targetFolder=targetFolder)):
			os.chdir("""P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}""".format(date = date, slashes = "\\"))
			os.mkdir(targetFolder)

		if nbeTarget == 'Yes':
			if os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\target.txt'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
				if os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Organic'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
					print(colored('TARGETS Folder '+ manu + ' ' + brand + ' ORGANIC Already Exists . . . Skipping Creation', 'yellow'))
				if not os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Organic'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
					os.chdir("""P:\\Epocrates Analytics\\TARGETS\\{date}\\{targetFolder}\\""".format(date = date, slashes = "\\", targetFolder=targetFolder))
					os.mkdir('Organic')

def checkDrugs():
	#read master drug file, strip white space and load into a list for comparison
	if caseType == 'listMatch' or caseType == 'Targeting':
		if bDa == 'y':
			with open(masterDrugs, 'r') as myDrugs:
				reader = csv.DictReader(myDrugs)
				for row in reader:
					finalDrugs.append(row['drugs'].strip())
					
			for inputDrugs in drugList.replace(', ', '\n').split("\n"):
				if inputDrugs.strip() not in finalDrugs:
					unmatchedDrugs.append(inputDrugs)
					
			print(colored('THESE DRUGS ARE SPELLED WRONG OR MISSING: ', 'yellow'), colored(unmatchedDrugs, 'yellow'))
			print('----------------------------------------------------------------------------------------')
			for drug in unmatchedDrugs:
				print('Possible Correct Spelling: ', colored(process.extract(drug, finalDrugs, limit=2), 'green'), colored(' - ', 'red'), colored(drug, 'red'))
				print('----------------------------------------------------------------------------------------')
		if bDa == 'n':
			pass
	else:
		pass


def getMain():
	with open (downloads + 'csvFile.csv', 'r') as inFile2, open(downloads + csvFileModTemp2, 'w') as targetFile:
		r = csv.reader(inFile2)
		headers = next(r)
		foundMain = []
		mainCols = ['npi', 'me', 'fname', 'lname', 'zip']
		for index, col in enumerate(headers):
			cellVal = str(col).lower().replace('/', '_').replace('-', '_')
			#Regular Expression Rules. We can add new Rules as we need to this list to cover more common cases.
			if cellVal == 'npi' or cellVal == 'npi_id' or re.search('.+ npi .+', cellVal) or re.search('.+_npi_.+', cellVal) or re.search('^npi.+', cellVal) or re.search('.+ npi', cellVal) or re.search('.+ npi', cellVal):
				print(cellVal, ': ',  colored('I found a NPI Number', 'green'))
				# print(colored('Test', 'green'))
				headers[index] = 'npi'
				foundMain.append('npi')
			elif cellVal == 'me' or cellVal == 'me_id' or cellVal == 'me_' or cellVal == 'meded' or cellVal == 'menum' or re.search('.+ me .+', cellVal) or  re.search('.+_me_.+', cellVal) or re.search('^me .+', cellVal) or re.search('.+ me', cellVal) or re.search('.+ me', cellVal) or re.search('^me_.+', cellVal):
				print(cellVal, ': ', colored('I found a ME Number', 'green'))
				headers[index] = 'me'
				foundMain.append('me')
			elif cellVal == 'fname' or cellVal == 'firstname' or cellVal == 'first_nm' or re.search('^first.+name', cellVal) or re.search('.+first.+name', cellVal) or re.search('.+fname', cellVal) or re.search('.+first', cellVal) or re.search('.+frst.+', cellVal):
				print(cellVal, ': ', colored('I found a First Name', 'green'))
				headers[index] = 'fname'
				foundMain.append('fname')
			elif re.search(r'^lname|^last.+name|.+last|.+last.+name|last_nm', cellVal) or cellVal == 'lastname':
				print(cellVal, ': ',  colored('I found a Last Name', 'green'))
				headers[index] = 'lname'
				foundMain.append('lname')
			elif cellVal == 'full_name' or cellVal == 'fullname' or cellVal == 'prescriber_name' or re.search('^full.+name', cellVal) or re.search('.+full.+name', cellVal):
				print(cellVal, ': ', colored('I found a Full Name', 'green'))
				headers[index] = 'full_name'
				fullNameList.append('y')
			elif cellVal == 'zip_4' or cellVal == 'zip4' or cellVal == 'zip___4':
				headers[index] = 'whatever'
			elif cellVal == 'Group' or cellVal == 'group':
				headers[index] = '_group'
			elif cellVal == 'zip' or cellVal == 'Postal' or (re.search('^zip.+', cellVal) and (cellVal != 'zip_4' or cellVal != 'zip4')) or re.search('^postal.+', cellVal) or re.search('.+_zip', cellVal) or re.search('.+ zip', cellVal) or re.search('.+_postal', cellVal) or re.search('.+ zip', cellVal) or re.search('.+ postal', cellVal):
				print(cellVal, ': ',  colored('I found a Zip/Postal Code', 'green'))
				headers[index] = 'zip'
				foundMain.append('zip')
			elif cellVal.startswith(('0','1','2','3','4','5','6','7','8','9')):
				print('I added an underscore to: ', cellVal)
				headers[index] = '_' + headers[index]

			if caseType == 'Targeting':
				if manu == 'AstraZeneca':
					if cellVal == 'client_id_1' or cellVal == 'hcp_az_cust_id' or cellVal == 'az_id':
						print(cellVal, ': ', colored('I Found a HCP_AZ_CUST_ID', 'green'))
						headers[index] = 'hcp_az_cust_id'
				# elif manu == 'Boehringer':
				# 	if cellVal == 'client_id_1':
				# 		print(cellVal, ': ', colored('I Found a Veeva_ID', 'green'))
				# 		headers[index] = 'veeva_id'
				elif manu == 'GSK':
					if cellVal == 'gskmetadatatag' or cellVal == 'metadata_code':
						print(cellVal, ': ', colored('I Found a GSK Metadata Tag', 'green'))
						headers[index] = 'gsk_metadata_tag'
					elif cellVal == 'dimcidvalue' or cellVal == 'cid' or cellVal == 'clientid' or cellVal == 'client_id':
						print(cellVal, ': ', colored('I Found a ClientID', 'green'))
						headers[index] = 'clientid'
				elif manu == 'Biogen':
					if cellVal == 'vnid' or cellVal == 'veeva_network_id':
						print(cellVal, ': ', colored('I Found a veeva_network_id', 'green'))
						headers[index] = 'veeva_network_id'
				elif manu == 'Novartis':
					if cellVal == 'mdm_id' or cellVal == 'mdm id' or cellVal == 'mdmid':
						print(cellVal, ': ', colored('I Found a MDM_ID', 'green'))
						headers[index] = 'mdm_id'
					elif cellVal == 'nov_id' or cellVal == 'nov id' or cellVal == 'novid':
						print(cellVal, ': ', colored('I Found a NOV_ID', 'green'))
						headers[index] = 'nov_id'
					elif cellVal == 'vendor_contact_event_id':
						print(cellVal, ': ', colored('I Found a vendor_contact_event_id', 'green'))
						headers[index] = 'vendor_contact_event_id'
					elif cellVal == 'fulfillment_kit_code':
						print(cellVal, ': ', colored('I Found a fulfillment_kit_code', 'green'))
						headers[index] = 'fulfillment_kit_code'




		w = csv.writer(targetFile, lineterminator='\n')
		w.writerow(headers)
		for row in r:
			w.writerow(row)

		# input('Press Enter to Continue . . . ')

		for col in mainCols:
			if col not in foundMain:
				print('Did not find Main Column: ', colored(col, 'red'))

		print('----------------------------------------------------------------------------------------------')
		print('')

	with open(downloads + csvFileModTemp2, 'r') as myFile, open(downloads + csvFileMod, 'w') as myOut:
		reader = csv.reader(myFile)
		headers = next(reader)
		headersList = []
		visited = []
		inc = 1
		for header in headers:
			headersList.append(header)
		for i, x in enumerate(headersList):
			if x not in visited:
				visited.append(headersList[i])
			else:
				dup = x +'_'+str(inc)
				if dup not in visited:
					visited.append(x+'_'+str(inc))
				else:
					inc += 1
					visited.append(x+'_'+str(inc))

		w = csv.writer(myOut, lineterminator='\n')
		w.writerow(visited)
		for row in reader:
			w.writerow(row)

def cmiCompasColumns():
	with open (downloads + csvFileMod, 'r') as inFile2, open(downloads + csvFileModTemp, 'w') as targetFile:
		r = csv.reader(inFile2)
		headers = next(r)
		for index, col in enumerate(headers):
			cellVal = str(col).lower().replace('/', '_').replace('-', '_')
			if cellVal == 'state':
				print(cellVal, colored('I Found a State_Code', 'green'))
				headers[index] = 'state_code'
			elif cellVal == 'address_1' or cellVal == 'addr1' or cellVal == 'addressline1':
				print(cellVal, colored('I Found a Address_1', 'green'))
				headers[index] = 'address1'
			elif cellVal == 'client_id' or cellVal == 'client_id_1':
				print(cellVal, colored('I Found an clientid', 'green'))
				headers[index] = 'clientid'
			elif cellVal == 'compasid' or cellVal == 'compas_id' or cellVal == 'compas id':
				print(cellVal, colored('I Found a CompasID', 'green'))
				headers[index] = 'compasid'
			elif cellVal == 'specialty' or re.search('^specialty.+', cellVal) or re.search('.+specialty.+', cellVal):
				print(cellVal, colored('I Found a Specialty', 'green'))
				headers[index] = 'specialty'
		w = csv.writer(targetFile, lineterminator='\n')
		w.writerow(headers)
		for row in r:
			w.writerow(row)
	os.remove(os.path.join(downloads, csvFileMod))
	os.rename(os.path.join(downloads, csvFileModTemp), os.path.join(downloads, csvFileMod))

def postgresConn():
	df = pandas.read_csv('{downloads}{csvFile}'.format(downloads=downloads, csvFile=csvFileMod), encoding='ISO-8859-1', dtype=str)
	myHeaders = list(df)

	if caseType == 'Targeting' and manu in ['Merck', 'AstraZeneca', 'Novartis', 'GSK', 'Boehringer', 'Amgen', 'Biogen', 'Sanofi-Aventis']:
		neededColumns = ['me', 'npi', 'fname', 'lname', 'zip'] + utils.prepSasSegments(listMatchType).split(',')
	else:
		neededColumns = ['me', 'npi', 'fname', 'lname', 'zip']

	selectMain5 = "select REPLACE(npi, '.0', '') as npi, REPLACE(me, '.0', '') as me, fname, lname, REPLACE(zip, '.0', '') as zip"
	selectMain2 = "select REPLACE(npi, '.0', '') as npi, REPLACE(me, '.0', '') as me"
	selectFullName = """SELECT [REPLACE](npi, '.0', '') AS npi,
	   [REPLACE](me, '.0', '') AS me,
	   [replace](full_name, ltrim(full_name, [replace](full_name, ' ', '') ), '') AS fname,
	   [replace](full_name, rtrim(full_name, [replace](full_name, ' ', '') ), '') AS lname,
	   [REPLACE](zip, '.0', '') AS zip"""

	selectFuzzy = "Select fname, lname, [REPLACE](zip, '.0', '') AS zip"

	conn = sqlite3.connect(os.path.join(desktop,'Ewok', 'epocrates_tables.db'))
	conn.text_factory = str
	cur = conn.cursor()

	print(colored("Connected to SQL LITE!\n", 'green'))
	print(colored('Checking if Table "{}" Exists. If so, were gonna drop dat table like 5th Period Chemistry. . .\n'.format(tableName), 'yellow'))

	dropTable = """DROP TABLE IF EXISTS {}""".format(tableName)

	cur.execute(dropTable)
	conn.commit()

	if manu == 'Biogen':
		df.to_sql('{}'.format(tableName), conn, if_exists='replace', index=False)
	else:
		df.to_sql('{}'.format(tableName), conn, if_exists='replace', index=False)

	for col in neededColumns:
		if col not in myHeaders:
			try:
				cur.executescript('ALTER TABLE {} ADD COLUMN {} text;'.format(tableName, col))
			except:
				print(col, 'Already Exists . . .', colored('Skipping', 'red'))
				continue 

	conn.commit()

	if caseType == 'Targeting':
		if manu == 'Biogen':
			fixBio = """UPDATE {tableName}
			SET veeva_network_id = '_'||veeva_network_id""".format(tableName=tableName)

			cur.execute(fixBio)
			conn.commit()

	if caseType == 'listMatch':
		if listMatchType == 'Standard_Seg':
			if foundFullName == 'n':
				export = """{select}, {seg} from {tableName};""".format(select=selectMain5, tableName=tableName, seg=splitList)
				pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

			if foundFullName == 'y':
				export = """{select}, {seg} from {tableName};""".format(select=selectFullName, tableName=tableName, seg=splitList)
				pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

		elif listMatchType =='Standard':
			if foundFullName == 'n':
				export = """{} from {};""".format(selectMain5, tableName)
				pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

			if foundFullName == 'y':
				export = """{select} from {tableName};""".format(select=selectFullName, tableName=tableName)
				pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

		elif listMatchType == 'Exact_Seg':
			export = """{select}, {seg} from {tableName};""".format(select=selectMain2, tableName=tableName, seg=splitList)
			pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

		elif listMatchType =='Exact':
			export = """{select} from {tableName};""".format(select=selectMain2, tableName=tableName)
			pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

		elif listMatchType =='Fuzzy':
			export = """{} from {};""".format(selectFuzzy, tableName)
			pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

	elif caseType == 'Targeting':
		# if not os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\target.txt'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
		if utils.codeCountReader() <= 1:
			if dSharing == 'Y':
				if listMatchType =='Standard':
					if config['cmi_compass_client'] == 'N':
						if foundFullName == 'n':
							export = """{select}, {seg} from {tableName};""".format(select=selectMain5, tableName=tableName, seg=splitList)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

						if foundFullName == 'y':
							export = """{select}, {seg} from {tableName};""".format(select=selectFullName, tableName=tableName, seg=splitList)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t') 

				elif listMatchType =='Exact':
					export = """{select}, {seg} from {tableName};""".format(select=selectMain2, tableName=tableName, seg=splitList)
					pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

				elif listMatchType =='Standard_Seg':
					if config['cmi_compass_client'] == 'N':
						if foundFullName == 'n':
							export = """{select}, {seg} from {tableName};""".format(select=selectMain5, tableName=tableName, seg=splitList)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

						if foundFullName == 'y':
							export = """{select}, {seg} from {tableName};""".format(select=selectFullName, tableName=tableName, seg=splitList)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

				elif listMatchType =='Exact_Seg':
					export = """{select}, {seg} from {tableName};""".format(select=selectMain2, tableName=tableName, seg=splitList)
					pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')


			elif dSharing == 'N':
				if listMatchType =='Standard':
					if foundFullName == 'n':
						if config['segmentListChecked'] == 'n':
							export = """{} from {};""".format(selectMain5, tableName)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

						if config['segmentListChecked'] == 'y':
							export = """{}, {} from {};""".format(selectMain5, splitList, tableName)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

					if foundFullName == 'y':
						if config['segmentListChecked'] == 'n':
							export = """{select} from {tableName};""".format(select=selectFullName, tableName=tableName)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

						if config['segmentListChecked'] == 'y':
							export = """{select}, {seg} from {tableName};""".format(select=selectFullName, tableName=tableName, seg=splitList)
							pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

				elif listMatchType =='Exact':
					if config['segmentListChecked'] == 'n':
						export = """{select} from {tableName};""".format(select=selectMain2, tableName=tableName)
						pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

					if config['segmentListChecked'] == 'y':
						export = """{select}, {seg} from {tableName};""".format(select=selectMain2, tableName=tableName, seg=splitList)
						pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

				elif listMatchType =='Standard_Seg':
					if foundFullName == 'n':
						export = """{select}, {seg} from {tableName};""".format(select=selectMain5, tableName=tableName, seg=splitList)
						pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

					if foundFullName == 'y':
						export = """{select}, {seg} from {tableName};""".format(select=selectFullName, tableName=tableName, seg=splitList)
						pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

				elif listMatchType =='Exact_Seg':
					export = """{select}, {seg} from {tableName};""".format(select=selectMain2, tableName=tableName, seg=splitList)
					pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

			if config['cmi_compass_client'] == 'Y':

				for col in cmiList:
					if col not in myHeaders:
						try:
							cur.executescript('ALTER TABLE {} ADD COLUMN {} text;'.format(tableName, col))
						except:
							print(col, 'Already Exists . . .', colored('Skipping', 'red'))
							continue

				if listMatchType =='Standard' and config['cmi_compass_client'] == 'Y':
					export = """{select}, {seg} from {tableName};""".format(select=selectMain5, seg=splitList, tableName=tableName)
					pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')


				elif listMatchType =='Standard_Seg' and config['cmi_compass_client'] == 'Y':

					export = """{select}, {seg} from {tableName};""".format(select=selectMain5, seg=splitList, tableName=tableName)
					pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')

		else:
			if str(config['organicMatchType']) == 'Standard':
				export = """{}, {} from {};""".format(selectMain5, splitList, tableName)
				pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'target.txt'), index=False, sep='\t')



	print('')
	print('SQL Export Complete\n')

	print(random.choice(randomList)+'\n')

def csv_from_excel():
	w = xlrd.open_workbook(downloads + newest)
	sh = w.sheet_by_index(0)
	your_csv_file = open (downloads + 'target.csv', 'w')
	wr = unicodecsv.writer(your_csv_file, encoding='utf8', lineterminator='\n')

	for rownum in range(sh.nrows):
		wr.writerow(sh.row_values(rownum))

	your_csv_file.close()

def removeChar():
	inputFile = open(downloads + csvFile, 'r')
	outputFile = open(downloads + 'csvFile.csv', 'w')
	conversion = '-/%$# @<>+*?&)(®'
	numbers = '0123456789'
	newtext = '_'

	index = 0
	for line in inputFile:
		if index == 0:
			for c in conversion:
				line = line.replace(c, newtext)
		outputFile.write(line)
		index += 1


def get_Cols():
	with open(downloads + csvFileMod, 'r') as f:
		reader = csv.reader(f)
		i = next(reader)
		columns = [row for row in reader]

		colLength = len(i)
		return colLength


def get_cols_names():
	with open(downloads + 'target.csv', 'r') as f:
		reader = csv.reader(f)
		i = next(reader)
		columns = [row for row in reader]

		return i

def copyTarget():
	if caseType == 'listMatch':
		# copy(downloads + listText, outFileFinal, progress)
		copyfile(downloads + listText, outFileFinal)
		if queryZips == 'Yes':
			copyfile(zipsFile, os.path.join(outCode, 'zipsImport.csv'))

	elif caseType == 'Targeting':
		# if not os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\target.txt'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
		if utils.codeCountReader() <= 1:
			copyfile(downloads + listText, outFileFinal2)
		else:
			copyfile(downloads + listText, 'P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Organic\\target.txt'.format(date = date, slashes = "\\", targetFolder=targetFolder))
		if queryZips == 'Yes':
			copyfile(zipsFile, os.path.join(outCode3, 'zipsImport.csv'))

def removeFiles():
	os.remove(os.path.join(downloads, 'target.txt'))
	os.remove(os.path.join(downloads, 'target_mod.csv'))
	os.remove(os.path.join(downloads, 'target.csv'))
	os.remove(os.path.join(downloads, 'csvFile.csv'))
	os.remove(os.path.join(downloads, 'csvFile1.csv'))
	os.remove(os.path.join(downloads, csvFileModTemp2))
	if caseType == 'Targeting' and sDa_only == 'N' and bDa_only == 'N':
		newest = str(config['loadedFile'])
		copyfile(os.path.join(downloads, newest), os.path.join(outCode3, newest))
	else:
		newest = str(config['loadedFile'])
		copyfile(os.path.join(downloads, newest), os.path.join(outCode, newest))
	if queryZips == 'Yes':
		os.remove(zipsFile)

	if caseType == 'listMatch':
		if os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
			os.remove(os.path.join(desktop, 'Ewok', 'codeCount.csv'))
		else:
			pass

	if utils.codeCountReader() > 1:
		if os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
			os.remove(os.path.join(desktop, 'Ewok', 'codeCount.csv'))
		else:
			pass

	if caseType == 'Targeting' and nbeTarget == 'No':
		if os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
			os.remove(os.path.join(desktop, 'Ewok', 'codeCount.csv'))
		else:
			pass		


def fixSas():
	#fixes the listMatch Code
	if caseType == 'listMatch':
		if listMatchType == 'Standard_Seg' or listMatchType == 'Exact_Seg':
			segList = ', '.join(segmentList)
			segList2 = ' '.join(segmentList)
		else:
			segList = ''
			segList2 = ''

		copyfile(emailCode, os.path.join(outCode, 'Presales Automation_Email_Final.sas'))
		newInput = os.path.join(outCode, 'Presales Automation_Email_Final.sas')

		line_file = open(os.path.join(newInput),'r').readlines()
		new_file = open(os.path.join(newInput),'w')
		for line_in in line_file:
			target_out = line_in.replace('/*DocORQuiz*/', listProduct)
			target_out = target_out.replace('/*listMatchType*/', listMatchType)
			target_out = target_out.replace('/*suppFile*/', suppFileLocation)
			target_out = target_out.replace('/*target_text_file*/', outCode)
			target_out = target_out.replace('/*Segments*/', segList)
			target_out = target_out.replace('/*Segments2*/', segList2)
			target_out = target_out.replace('/*Brand*/', brand)
			target_out = target_out.replace('/*MY_INIT*/', yourIn)
			target_out = target_out.replace('/*Requester_Initials*/', reIn)
			target_out = target_out.replace('/*SDA_Occ*/', SDA_Occ)
			target_out = target_out.replace('/*SDA_Spec*/', SDA_Spec)
			target_out = target_out.replace('/*yesORno*/', deDup)
			target_out = target_out.replace('/*LookUpPeriod*/', lookUpPeriod)
			target_out = target_out.replace('/*totalLoookUps*/', totalLookUps)
			target_out = target_out.replace('/*BDA_Occ*/', occupation)
			target_out = target_out.replace('/*BDA_Spec*/', specialty)
			target_out = target_out.replace('/*drugList*/', drugList)
			target_out = target_out.replace('/*caseno*/', caseno)
			target_out = target_out.replace('/*manu*/', manu)
			target_out = target_out.replace('/*mtype*/', mtype)
			target_out = target_out.replace('/*SE*/', SE)
			target_out = target_out.replace('/*username*/', email)
			target_out = target_out.replace('/*sdaocc2*/', SDA_Occ2)
			target_out = target_out.replace('/*bdaocc2*/', occupation2)
			target_out = target_out.replace('/*drugsnocomma*/', drugsnocomma)
			target_out = target_out.replace('/*dispPeriod*/', displayPeriod)
			target_out = target_out.replace('/*suppApplied*/', suppApplied)
			target_out = target_out.replace('/*supp_text_file*/', suppFileLocation)
			target_out = target_out.replace('/*supp_Match_Type*/', str(config['suppMatchType']))
			target_out = target_out.replace('/*therapyClass*/', therapyClass)
			target_out = target_out.replace('/*bda_only*/', bDa_only)
			target_out = target_out.replace('/*sda_only*/', sDa_only)
			target_out = target_out.replace('/*createPivotTable*/', createPivotTable)
			target_out = target_out.replace('/*pivYes1*/', pivSeg1)
			target_out = target_out.replace('/*pivYes2*/', pivSeg2)
			target_out = target_out.replace('/*totalSDAS*/', finalSDATotal)
			target_out = target_out.replace('/*totalBDAS*/', finalBDATotal)
			target_out = target_out.replace('/*queryStates*/', queryStates)
			target_out = target_out.replace('/*statesToQuery*/', statesToQuery)
			target_out = target_out.replace('/*queryZips*/', queryZips)
			target_out = target_out.replace('/*applyToClientList*/', applyToClientList)
			target_out = target_out.replace('/*applyToSda*/', applyToSda)
			target_out = target_out.replace('/*applytoBda*/', applyToBda)
			new_file.write(target_out)
			line_file = new_file

	elif caseType == 'Targeting': 
		targetOut = """P:\\Epocrates Analytics\\TARGETS\\{date}\\{manu} {brand}""".format(date = date, manu = manu, brand = brand)
		outCode2 = """P:\\Epocrates Analytics\\TARGETS\\{date}\\{manu} {brand}{slashes}""".format(date = date, slashes = "\\", manu = manu, brand = brand)
		# if dSharing == 'Y' and (listMatchType == 'Standard' or listMatchType == 'Standard_Seg' or listMatchType == 'Exact' or listMatchType == 'Exact_Seg'):
		if manu not in ['Merck', 'AstraZeneca', 'Novartis', 'GSK', 'Boehringer', 'Amgen', 'Biogen', 'Sanofi-Aventis', 'AbbVie']:
			segList = ', '.join(segmentList)
		else:
			segList = segmentList

		# if not os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\target.txt'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
		if utils.codeCountReader() <= 1:
			copyfile(targetAuto, os.path.join(outCode2, 'Targeting Automation Code_OFFICIAL.sas'))
			newInput = os.path.join(outCode2, 'Targeting Automation Code_OFFICIAL.sas')
		if nbeTarget == 'Yes' and utils.codeCountReader() > 1: 
			copyfile(targetAutoOrganic, os.path.join(outCode2, 'Organic', 'Targeting Automation Code_ORGANIC.sas'))
			newInput = os.path.join(outCode2, 'Organic', 'Targeting Automation Code_ORGANIC.sas')


		line_file = open(os.path.join(newInput),'r').readlines()
		new_file = open(os.path.join(newInput),'w')
		for line_in in line_file:
			target_out = line_in.replace('/*DocORQuiz*/', listProduct)
			target_out = target_out.replace('/*listMatchType*/', listMatchType)
			target_out = target_out.replace('/*target_text_file*/', outCode3)
			target_out = target_out.replace('/*Date*/', date)
			target_out = target_out.replace('/*targetFoler*/', targetOut)
			target_out = target_out.replace('/*Brand*/', brand)
			target_out = target_out.replace('?MY_INIT?', yourIn)
			target_out = target_out.replace('/*TargetNum*/', targetNum)
			target_out = target_out.replace('/*TargetNum2*/', targetNum2)
			target_out = target_out.replace('/*randomSplit*/', randomSplit)
			target_out = target_out.replace('/*segVar*/', segVariable)
			target_out = target_out.replace('/*segValues*/', varValues)
			target_out = target_out.replace('/*dataShareYorN*/', dSharing)
			target_out = target_out.replace('/*Segments*/', segList)
			target_out = target_out.replace('/*keep_seg*/', keep_seg)
			target_out = target_out.replace('/*Manu*/', manu)
			target_out = target_out.replace('/*SDAONLY*/', sDa_only)
			target_out = target_out.replace('/*SDA_Occ*/', SDA_Occ)
			target_out = target_out.replace('/*SDA_Spec*/', SDA_Spec)
			target_out = target_out.replace('/*SDATarget*/', SDA_Target)
			target_out = target_out.replace('/*BDAONLY*/', bDa_only)
			target_out = target_out.replace('/*yesORno*/', deDup)
			target_out = target_out.replace('/*LookUpPeriod*/', lookUpPeriod)
			target_out = target_out.replace('/*totalLoookUps*/', totalLookUps)
			target_out = target_out.replace('/*BDA_Occ*/', occupation)
			target_out = target_out.replace('/*BDA_Spec*/', specialty)
			target_out = target_out.replace('/*BDATarget*/', BDA_Target)
			target_out = target_out.replace('/*drugList*/', drugList)
			target_out = target_out.replace('/*suppApplied*/', suppApplied)
			target_out = target_out.replace('/*supp_text_file*/', suppFileLocation)
			target_out = target_out.replace('/*supp_Match_Type*/', str(config['suppMatchType']))
			target_out = target_out.replace('/*dataCap*/', dataCap)
			target_out = target_out.replace('/*bda_only*/', bDa_only)
			target_out = target_out.replace('/*sda_only*/', sDa_only)
			target_out = target_out.replace('/*backFill*/', backFill)
			target_out = target_out.replace('/*needVals*/', neededValues)
			target_out = target_out.replace('/*backFillVals*/', backFillValue)
			target_out = target_out.replace('/*suppSDAOnly*/', suppSDAOnly)
			target_out = target_out.replace('/*suppBDAOnly*/', suppBDAOnly)
			target_out = target_out.replace('/*queryStates*/', queryStates)
			target_out = target_out.replace('/*statesToQuery*/', statesToQuery)
			target_out = target_out.replace('/*queryZips*/', queryZips)
			target_out = target_out.replace('/*applyToClientList*/', applyToClientList)
			target_out = target_out.replace('/*applyToSda*/', applyToSda)
			target_out = target_out.replace('/*applytoBda*/', applyToBda)
			target_out = target_out.replace('/*nbeTarget*/', nbeTarget)
			target_out = target_out.replace('/*openerScheduleIDs*/', openerIDs)

			new_file.write(target_out)
			line_file = new_file

def buildSDAPreSalesMacro():
	totalIncludesBuilt = 1
	totalAdditionalSDAs = int(config['totalAdditionalSDAs'])
	sdaMacro = """%macro multipleSDAAdd_Ons;
%do i=1 %to 1;
	%if &totalSDAS. > 1 %then %do;\n"""
	macroEnd = """
	%end;
%end;
%mend;
%multipleSDAAdd_Ons;"""
	while totalIncludesBuilt <= totalAdditionalSDAs:
		includePath = '		%include "&filepath.\PS_SDA_plus_CL_Email_'+str(totalIncludesBuilt)+'.sas";'
		totalIncludesBuilt +=1
		includePath = '{}\n'.format(includePath)
		# totalIncludesBuilt +=1
		sdaMacro +=includePath
		# totalIncludesBuilt +=1
	finalSDAMacro = sdaMacro + macroEnd
	# print finalSDAMacro

	newInput = os.path.join(outCode, 'Presales Automation_Email_Final.sas')
	line_file = open(os.path.join(newInput),'r').readlines()
	new_file = open(os.path.join(newInput),'w')
	for line_in in line_file:
		target_out = line_in.replace('/*multiSDAMacro*/', finalSDAMacro)

		new_file.write(target_out)
		line_file = new_file	

def buildSDACodes():
	print('Building Additional SDA Codes. . . ')
	sdaCodeHousing = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\CUSTOM\\Email Codes\\additionalSDA'
	sdaCode = 'PS_SDA_plus_CL_Email'
	suppApplied = str(config['suppressionApplied'])
	sDa_only = str(config['sdaOnly'])
	
	# if suppApplied == 'Y':
	# 	suppFolder = config['suppSASFile']
	# 	onlyFilesSupp = [f for f in listdir(suppFolder) if isfile(join(suppFolder, f))]

	# 	for files in sorted(set(onlyFilesSupp)):
	# 		file = files.split('.')[0]
	# 		if re.search('_supp_.+', file) or re.search('_matched_.+', file):
	# 			suppFile = file
	# else:
	# 	suppFolder = ''
	# 	suppFile = ''


	totalCodesBuilt = 1
	totalAdditionalSDAs = int(config['totalAdditionalSDAs'])
	while totalCodesBuilt <= totalAdditionalSDAs:
		# occupation = str(config['SDA_Occ'])
		occupation2 = str(config['additonalSdaOcc_'+str(totalCodesBuilt)]).replace('"', '')
		# specialty = str(config['SDA_Spec'])
		specialty2 = str(config['additonalSdaSpec_'+str(totalCodesBuilt)]).replace('"', '')


		copiedSDAFile = os.path.join(outCode, sdaCode+'_'+str(totalCodesBuilt)+'.sas')
		copyfile(os.path.join(sdaCodeHousing, sdaCode+'.sas'), copiedSDAFile)
		
		newInput = copiedSDAFile
		line_file = open(os.path.join(newInput),'r').readlines()
		new_file = open(os.path.join(newInput),'w')
		for line_in in line_file:
			# target_out = line_in.replace('/*folder*/', listMatchFolder)
			# target_out = target_out.replace('/*matchedFile*/', matchedFile)
			target_out = line_in.replace('/*suppApplied*/', suppApplied)
			# target_out = target_out.replace('/*suppFolder*/', suppFolder)
			# target_out = target_out.replace('/*suppFile*/', suppFile)
			target_out = target_out.replace('/*SDA_Occ*/', config['additonalSdaOcc_'+str(totalCodesBuilt)])
			target_out = target_out.replace('/*SDA_Occ_Disp*/', occupation2)
			target_out = target_out.replace('/*SDA_Spec*/', config['additonalSdaSpec_'+str(totalCodesBuilt)])
			target_out = target_out.replace('/*SDA_Spec_Disp*/', specialty2)			
			target_out = target_out.replace('/*username*/', email)
			target_out = target_out.replace('/*inc*/', '_'+str(totalCodesBuilt))
			new_file.write(target_out)
			line_file = new_file

		totalCodesBuilt +=1


def buildBDAPreSalesMacro():
	totalIncludesBuilt = 1
	totalAdditionalBDAs = int(config['totalAdditionalBDAs'])
	bdaMacro = """%macro multipleBDAAdd_Ons;
%do i=1 %to 1;
	%if &totalBDAS. > 1 %then %do;\n"""
	macroEnd = """
	%end;
%end;
%mend;
%multipleBDAAdd_Ons;"""
	while totalIncludesBuilt <= totalAdditionalBDAs:
		includePath = '		%include "&filepath.\PS_BDA_Mult_Lookup_plus_CL_Email_'+str(totalIncludesBuilt)+'.sas";'
		totalIncludesBuilt +=1
		includePath = '{}\n'.format(includePath)
		# totalIncludesBuilt +=1
		bdaMacro +=includePath
		# totalIncludesBuilt +=1
	finalBDAMacro = bdaMacro + macroEnd
	# print finalSDAMacro

	newInput = os.path.join(outCode, 'Presales Automation_Email_Final.sas')
	line_file = open(os.path.join(newInput),'r').readlines()
	new_file = open(os.path.join(newInput),'w')
	for line_in in line_file:
		target_out = line_in.replace('/*multiBDAMacro*/', finalBDAMacro)

		new_file.write(target_out)
		line_file = new_file

def buildBDACodes():
	print('Building Additional BDA Codes. . . ')
	bdaCodeHousing = 'P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\CUSTOM\\Email Codes\\additionalBDA'
	bdaCode = 'PS_BDA_Mult_Lookup_plus_CL_Email'
	suppApplied = str(config['suppressionApplied'])
	
	# if suppApplied == 'Y':
	# 	suppFolder = config['suppSASFile']
	# 	onlyFilesSupp = [f for f in listdir(suppFolder) if isfile(join(suppFolder, f))]

	# 	for files in sorted(set(onlyFilesSupp)):
	# 		file = files.split('.')[0]
	# 		if re.search('_supp_.+', file) or re.search('_matched_.+', file):
	# 			suppFile = file
	# else:
	# 	suppFolder = ''
	# 	suppFile = ''
	finalDrugs2 = []
	unmatchedDrugs2 = []
	totalCodesBuilt = 1
	totalAdditionalBDAs = int(config['totalAdditionalBDAs'])
	while totalCodesBuilt <= totalAdditionalBDAs:

		occupation2 = str(config['additonalBdaOcc_'+str(totalCodesBuilt)]).replace('"', '')
		specialty2 = str(config['additonalBdaSpec_'+str(totalCodesBuilt)]).replace('"', '')
		therapyClass = str(config['additonalBdatherapyChecked_'+str(totalCodesBuilt)])
		lookUpPeriod = str(config['additonalBdaLookUpPeriod_'+str(totalCodesBuilt)])
		totalLookUps = str(config['additonalBdaLookUps_'+str(totalCodesBuilt)])
		displayPeriod = str(int(lookUpPeriod)-1)
		dedupe = str(config['additonalBdaDedup_'+str(totalCodesBuilt)])

		drugList = str(config['additonalBdaDrugList_'+str(totalCodesBuilt)])
		drugsnocomma = str(config['additonalBdaDrugList_'+str(totalCodesBuilt)]).replace("\n", ", ").replace("'", '')

		print('Checking Misspelled Drugs for Additional BDA '+str(totalCodesBuilt))
		# checkDrugs2()
		with open(masterDrugs, 'r') as myDrugs:
			reader = csv.DictReader(myDrugs)
			for row in reader:
				finalDrugs2.append(row['drugs'].strip())
				
		for inputDrugs in drugList.replace(', ', '\n').split("\n"):
			if inputDrugs.strip() not in finalDrugs2:
				unmatchedDrugs2.append(inputDrugs)
						
		print(colored('THESE DRUGS ARE SPELLED WRONG OR MISSING: ', 'yellow'), colored(unmatchedDrugs2, 'yellow'))
		print('----------------------------------------------------------------------------------------')
		for drug in unmatchedDrugs2:
			print('Possible Correct Spelling: ', colored(process.extract(drug, finalDrugs2, limit=2), 'green'), colored(' - ', 'red'), colored(drug, 'red'))
			print('----------------------------------------------------------------------------------------')

		finalDrugs2 = []
		unmatchedDrugs2 = []

		copiedBDAFile = os.path.join(outCode, bdaCode+'_'+str(totalCodesBuilt)+'.sas')
		copyfile(os.path.join(bdaCodeHousing, bdaCode+'.sas'), copiedBDAFile)
		
		newInput = copiedBDAFile
		line_file = open(os.path.join(newInput),'r').readlines()
		new_file = open(os.path.join(newInput),'w')
		for line_in in line_file:
			target_out = line_in.replace('/*suppApplied*/', suppApplied)
			# target_out = target_out.replace('/*suppFolder*/', suppFolder)
			# target_out = target_out.replace('/*suppFile*/', suppFile)
			target_out = target_out.replace('/*therapyClass*/', therapyClass)
			target_out = target_out.replace('/*LookUpPeriod*/', lookUpPeriod)
			target_out = target_out.replace('/*totalLookUps*/', totalLookUps)
			target_out = target_out.replace('/*BDA_Occ*/', config['additonalBdaOcc_'+str(totalCodesBuilt)])
			target_out = target_out.replace('/*BDA_Occ_Disp*/', occupation2)
			target_out = target_out.replace('/*BDA_Spec*/', config['additonalBdaSpec_'+str(totalCodesBuilt)])
			target_out = target_out.replace('/*BDA_Spec_Disp*/', specialty2)
			target_out = target_out.replace('/*dispPeriod*/', displayPeriod)
			target_out = target_out.replace('/*drugList2*/', drugsnocomma)
			target_out = target_out.replace('/*drugList*/', drugList)				
			target_out = target_out.replace('/*username*/', email)
			target_out = target_out.replace('/*inc*/', '_'+str(totalCodesBuilt))
			target_out = target_out.replace('/*Yes_OR_No*/', dedupe)
			new_file.write(target_out)
			line_file = new_file

		totalCodesBuilt +=1

def checkDrugs2():
	finalDrugs2 = []
	unmatchedDrugs2 = []

	with open(masterDrugs, 'r') as myDrugs:
		reader = csv.DictReader(myDrugs)
		for row in reader:
			finalDrugs2.append(row['drugs'].strip())
			
	for inputDrugs in drugList.replace(', ', '\n').split("\n"):
		if inputDrugs.strip() not in finalDrugs2:
			unmatchedDrugs2.append(inputDrugs)
					
			print(colored('THESE DRUGS ARE SPELLED WRONG OR MISSING: ', 'yellow'), colored(unmatchedDrugs2, 'yellow'))
			print('----------------------------------------------------------------------------------------')
			for drug in unmatchedDrugs2:
				print('Possible Correct Spelling: ', colored(process.extract(drug, finalDrugs2, limit=2), 'green'), colored(' - ', 'red'), colored(drug, 'red'))
				print('----------------------------------------------------------------------------------------')

	finalDrugs2 = []
	unmatchedDrugs2 = []

# def codeCounter():
# 	codeCount = 0
# 	if not os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
# 		with open(os.path.join(desktop, 'Ewok', 'codeCount.csv'), 'w') as outFile:
# 			writer = csv.writer(outFile, lineterminator='\n')
# 			headers = ['count']
# 			writer.writerow(headers)
# 			writer.writerow(['1'])
# 			codeCount = 1

# 	else:
# 		with open(os.path.join(desktop, 'Ewok', 'codeCount.csv'), 'r') as inFile:
# 			reader = csv.reader(inFile)
# 			headers = next(reader)
# 			for line in reader:
# 				value = int(line[0])
# 			value += 1
# 			codeCount = value
# 	print('Code Count is: ', codeCount)
# 	return codeCount

# def codeCountReader():
# 	if os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
# 		with open(os.path.join(desktop, 'Ewok', 'codeCount.csv'), 'r') as inFile:
# 			reader = csv.reader(inFile)
# 			headers = next(reader)
# 			for line in reader:
# 				value = int(line[0])

# 		return value

def deleteCodeCount():
	if os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
		os.remove(os.path.join(desktop, 'Ewok', 'codeCount.csv'))
	if os.path.exists(os.path.join(downloads, csvFileMod)):
		os.remove(os.path.join(downloads, csvFileMod))
	if os.path.exists(os.path.join(downloads, csvFileModTemp2)):
		os.remove(os.path.join(downloads, csvFileModTemp2))
	else:
		pass


if (caseType == 'listMatch' or caseType == 'Targeting') and listMatchType != 'None':
	get_cols_names()
	createFolders()
	getMain()
	if 'cmi_compass_client' in config:
		if config['cmi_compass_client'] == 'Y':
			cmiCompasColumns()
	try:
		postgresConn()
	except:
		deleteCodeCount()
	checkDrugs()
	fixSas()
	copyTarget()
	removeFiles()
if int(config['totalAdditionalSDAs']) != 0:
	buildSDACodes()
	buildSDAPreSalesMacro()
if int(config['totalAdditionalBDAs']) != 0:
	buildBDACodes()
	buildBDAPreSalesMacro()
if (caseType == 'listMatch' or caseType == 'Targeting') and listMatchType == 'None':
	createFolders()
	if bDa_only == 'Y':
		checkDrugs()
	fixSas()


if nbeTarget == 'Yes' and not os.path.exists('P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Organic'.format(date = date, slashes = "\\", targetFolder=targetFolder)):
	utils.checkExtension2(str(config['organicFileName']))
	utils.removeChar()
	utils.incDupColumns()
	subprocess.call(['python.exe', os.path.join(desktop, 'Ewok','theOne_GUI.py'), 'config.json'])

	nbeFile = str(config['organicFileName'])
	copyfile(os.path.join(downloads, nbeFile), os.path.join(outCode3, 'Organic', nbeFile))

	print('')
	print(colored('P', 'cyan')+colored('R', 'red')+colored('O', 'green')+colored('G', 'yellow')+colored('R', 'blue')+colored('A', 'magenta')+colored('M', 'cyan')+' '+colored('C', 'magenta')+colored('O', 'red')+colored('M', 'green')+colored('P', 'blue')+colored('L', 'red')+colored('E', 'cyan')+colored('T', 'yellow')+colored('E', 'white'))

if caseType == 'Presales' or nbeTarget == 'No':
	print('')
	print(colored('P', 'cyan')+colored('R', 'red')+colored('O', 'green')+colored('G', 'yellow')+colored('R', 'blue')+colored('A', 'magenta')+colored('M', 'cyan')+' '+colored('C', 'magenta')+colored('O', 'red')+colored('M', 'green')+colored('P', 'blue')+colored('L', 'red')+colored('E', 'cyan')+colored('T', 'yellow')+colored('E', 'white'))
	# print 'PROGRAM COMPLETE!'