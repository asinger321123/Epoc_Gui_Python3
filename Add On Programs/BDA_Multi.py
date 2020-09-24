import pandas
from openpyxl import Workbook, load_workbook
import re
import numpy
from os import listdir
from os.path import isfile, join
import os
import sys
import xlrd
import csv
from shutil import copyfile
from fuzzywuzzy import fuzz
from fuzzywuzzy import process
import psycopg2
import unicodecsv
import pprint
from collections import Counter
import datetime
import json


userhome = os.path.expanduser('~')
desktop = userhome + '\\Desktop\\'
args = sys.argv[1:]
drugList = []
drugList2 = []
bdaCode = "P:\\Epocrates Analytics\\Code_Library\\Standard_Codes\\Pre Sales\\DocAlert_Python_Reference\\CUSTOM\\Email Codes\\PS_BDA_Mult_Lookup_plus_CL_Email.sas"

if len(args) > 0:
	with open(os.path.join(desktop, 'Ewok\\Configs', args[0]), 'r') as infile:
		config = json.loads(infile.read(), encoding='utf8')

		if 'excludeStates' in config:
			statesToExclude = config['excludeStates']
		if 'excludeStates' not in config:
			statesToExclude = """\"Colorado", "Vermont\""""

		totalAdditionalBDAs = int(config['totalAdditionalBDAs'])
		activeUserDate = str(config['activeUserDate'])
		listMatchFolder = config['matchedFile']
		therapyClass = str(config['therapyChecked'])
		suppApplied = str(config['suppressionApplied'])
		onlyFiles = [f for f in listdir(listMatchFolder) if isfile(join(listMatchFolder, f))]
		if suppApplied == 'Yes':
			suppFolder = config['suppSASFile']
			onlyFilesSupp = [f for f in listdir(suppFolder) if isfile(join(suppFolder, f))]

			for files in sorted(set(onlyFilesSupp)):
				file = files.split('.')[0]
				if re.search('_supp_.+', file) or re.search('_matched_.+', file):
					suppFile = file
		else:
			suppFolder = ''
			suppFile = ''

		for files in sorted(set(onlyFiles)):
			file = files.split('.')[0]
			if re.search('_matched_.+', file):
				matchedFile = file

		matchFilePath = os.path.join(listMatchFolder, matchedFile)

		lookUpPeriod = str(config['lookUpPeriod'])
		displayPeriod = str(int(lookUpPeriod)-1)

		totalLookUps = config['totalLookUps']

		occupation = str(config['occupation'])
		occupation2 = occupation.replace('"', '')

		specialty = str(config['specialty'])
		specialty2 = specialty.replace('"', '')
		email = str(config['email'])

		drugList = str(config['drugList'])
		drugsnocomma = str(config['drugList']).replace("\n", ", ").replace("'", '')



copyfile(bdaCode, os.path.join(listMatchFolder, 'PS_BDA_Mult_Lookup_plus_CL_Email.sas'))
newInput = os.path.join(listMatchFolder, 'PS_BDA_Mult_Lookup_plus_CL_Email.sas')

line_file = open(os.path.join(newInput),'r').readlines()
new_file = open(os.path.join(newInput),'w')
for line_in in line_file:

	#target_out = line_in.replace('/*DocORQuiz*/', listProduct).replace('/*listMatchType*/', listMatchType).replace('/*target_text_file*/', outCode).replace('/*Segments*/', '').replace('/*Segments2*/', '').replace('/*Brand*/', brand).replace('/*MY_INIT*/', yourIn).replace('/*Requester_Initials*/', reIn).replace('/*SDA_Occ*/', '').replace('/*SDA_Spec*/', '').replace('/*yesORno*/', deDup).replace('/*LookUpPeriod*/', lookUpPeriod).replace('/*totalLoookUps*/', totalLookUps).replace('/*BDA_Occ*/', occupation).replace('/*BDA_Spec*/', specialty).replace('/*drugList*/', drugList)
	target_out = line_in.replace('/*folder*/', listMatchFolder)
	target_out = target_out.replace('/*matchedFile*/', matchFilePath)
	target_out = target_out.replace('/*BDA_Total*/', str(totalAdditionalBDAs))
	target_out = target_out.replace('/*suppApplied*/', suppApplied)
	target_out = target_out.replace('/*suppFolder*/', suppFolder)
	target_out = target_out.replace('/*suppFile*/', suppFile)
	target_out = target_out.replace('/*therapyClass*/', therapyClass)
	target_out = target_out.replace('/*LookUpPeriod*/', lookUpPeriod)
	target_out = target_out.replace('/*totalLookUps*/', totalLookUps)
	target_out = target_out.replace('/*BDA_Occ*/', occupation)
	target_out = target_out.replace('/*BDA_Occ_Disp*/', occupation2)
	target_out = target_out.replace('/*BDA_Spec*/', specialty)
	target_out = target_out.replace('/*BDA_Spec_Disp*/', specialty2)
	target_out = target_out.replace('/*dispPeriod*/', displayPeriod)
	target_out = target_out.replace('/*drugList2*/', drugsnocomma)
	target_out = target_out.replace('/*drugList*/', drugList)				
	target_out = target_out.replace('/*username*/', email)
	target_out = target_out.replace('/*statesToExclude*/', statesToExclude)
	target_out = target_out.replace('/*activeUserDate*/', activeUserDate)
	new_file.write(target_out)
	line_file = new_file

print("BDA Program Complete")