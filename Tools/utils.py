from openpyxl import Workbook, load_workbook
import re
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
from pyxlsb import open_workbook
import pandas as pd
# from colorama import init, Fore, Back, Style
# from termcolor import colored

# init(autoreset=True)

userhome = os.path.expanduser('~')
downloads = userhome + '\\Downloads\\'
desktop = userhome + '\\Desktop\\'
csvFile = 'target.csv'
# newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))


def fetchColumns():
	with open(downloads + 'csvFile.csv', 'r') as f:
		reader = csv.reader(f)
		i = next(reader)
		columns = [row for row in reader]

		return i

def checkExtension():
	newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))
	filename, extension = os.path.splitext(os.path.join(downloads, newest))
	# print extension
	extension = extension.lower()
	if extension == '.xlsx':
		csv_from_excel()

	elif extension == '.xlsb':
		xlsb_to_csv()
	elif extension == '.txt':
		with open(os.path.join(downloads, newest), 'r') as f:
			f = f.read()
			totalpipecount = 0
			totaltabcount = 0
			for char in f:
				if char == '\t':
					totaltabcount += 1
				if char == '|':
					totalpipecount += 1
			if totalpipecount > totaltabcount:
				pipe_to_csv()
			if totaltabcount > totalpipecount:
				tab_to_csv()
	elif extension == '.csv':
		raw = pd.read_csv(os.path.join(downloads, newest))
		raw.to_csv(os.path.join(downloads, 'target.csv'), index=None, encoding='utf-8')
		# raw.to_csv(downloads + 'target.csv', index=None, header=True, encoding='utf-8')
		# with open(os.path.join(downloads, newest), 'r', encoding='utf-8') as inFile, open(os.path.join(downloads, 'target.csv'), 'w', encoding='utf-8') as out:
		# 	reader = csv.reader(inFile)
		# 	writer = csv.writer(out, lineterminator='\n')
		# 	for row in reader:
		# 		print(row)
		# 		writer.writerows([row])
	else:
		with open(os.path.join(downloads, 'target.csv'), 'w') as out:
			writer = csv.writer(out, lineterminator='\n')
			writer.writerows([['No File Found']])

def xlsb_to_csv():
	newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))
	with open_workbook(os.path.join(downloads, newest)) as wb, open(os.path.join(downloads, 'target.csv'), 'w') as out:
		writer = csv.writer(out, lineterminator='\n')

		# for sheetname in wb.sheets:
		sheet = wb.get_sheet(1)
		for row in sheet.rows():
			values = [r.v for r in row]  # retrieving content
			writer.writerow(values)

def pipe_to_csv():
	newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))
	with open(os.path.join(downloads, newest), 'r') as f, open(os.path.join(downloads, 'target.csv'), 'w', encoding='utf-8') as out:
		pipereader = csv.reader(f, delimiter='|')
		csvwriter = csv.writer(out, delimiter=',', lineterminator='\n')
		for row in pipereader:
			csvwriter.writerow(row)

def tab_to_csv():
	newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))
	with open(os.path.join(downloads, newest), 'r') as f, open(os.path.join(downloads, 'target.csv'), 'w', encoding='utf-8') as out:
		tabreader = csv.reader(f, delimiter='\t')
		csvwriter = csv.writer(out, delimiter=',', lineterminator='\n')
		for row in tabreader:
			csvwriter.writerow(row)

def countSheets():
	totalSheets = len(w.sheet_names())
	return

def csv_from_excel():
	newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))
	raw = pd.read_excel(downloads + newest, dtype=str)
	raw.to_csv(downloads + 'target.csv', index=None, header=True, encoding='utf-8')


def csv_from_excel2(test=None):
	matched = test
	# newest = max(os.listdir(downloads), key=lambda f: os.path.getmtime("{}/{}".format(downloads, f)))
	raw = pd.read_excel(downloads + matched, dtype=str)
	raw.to_csv(downloads + 'target.csv', index=None, header=True, encoding='utf-8')

def checkExtension2(test=None):
	matched = test
	filename, extension = os.path.splitext(os.path.join(downloads, matched))
	# print extension
	extension = extension.lower()
	if extension == '.xlsx':
		csv_from_excel2(matched)
	elif extension == '.txt':
		with open(os.path.join(downloads, matched), 'r', encoding='utf-8') as f:
			f = f.read()
			totalpipecount = 0
			totaltabcount = 0
			for char in f:
				if char == '\t':
					totaltabcount += 1
				if char == '|':
					totalpipecount += 1
			if totalpipecount > totaltabcount:
				pipe_to_csv2(matched)
			if totaltabcount > totalpipecount:
				tab_to_csv2(matched)
	elif extension == '.csv':

		raw = pd.read_csv(os.path.join(downloads, matched))
		raw.to_csv(os.path.join(downloads, 'target.csv'), index=None, encoding='utf-8')
		# with open(os.path.join(downloads, matched), 'r') as inFile, open(os.path.join(downloads, 'target.csv'), 'w', encoding='utf-8') as out:
		# 	reader = csv.reader(inFile)
		# 	writer = csv.writer(out, lineterminator='\n')
		# 	for row in reader:
		# 		writer.writerows(row)
		# copyfile(os.path.join(downloads, matched), os.path.join(downloads, 'target.csv'))
	else:
		with open(os.path.join(downloads, 'target.csv'), 'w') as out:
			writer = csv.writer(out, lineterminator='\n')
			writer.writerows([['No File Found']])

def tab_to_csv2(test=None):
	matched = test
	with open(os.path.join(downloads, matched), 'r') as f, open(os.path.join(downloads, 'target.csv'), 'w') as out:
		tabreader = csv.reader(f, delimiter='\t')
		csvwriter = csv.writer(out, delimiter=',', lineterminator='\n')
		for row in tabreader:
			csvwriter.writerow(row)

def pipe_to_csv2(test=None):
	matched = test
	with open(os.path.join(downloads, matched), 'r') as f, open(os.path.join(downloads, 'target.csv'), 'w') as out:
		pipereader = csv.reader(f, delimiter='|')
		csvwriter = csv.writer(out, delimiter=',', lineterminator='\n')
		for row in pipereader:
			csvwriter.writerow(row)

def removeChar():
	inputFile = open(downloads + csvFile, 'r', encoding='utf-8')
	outputFile = open(downloads + 'csvFile1.csv', 'w')
	conversion = '-/%$# @<>+*?&)('
	numbers = '0123456789'
	newtext = '_'

	index = 0
	for line in inputFile:
		if index == 0:
			for c in conversion:
				line = line.replace(c, newtext)
		outputFile.write(line)
		index += 1

def incDupColumns():
	with open(downloads + 'csvFile1.csv', 'r') as myFile, open(downloads + 'csvFile.csv', 'w') as myOut:
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



def cmiCompasCheck():
	cmiColumns = []
	with open(downloads + 'csvFile.csv', 'r') as f:
		reader = csv.reader(f)
		i = next(reader)
		columns = [row for row in reader]
		for col in columns:
			cellVal = str(col).lower().replace('/', '_').replace('-', '_')
			if cellVal == 'state' or cellVal == 'state_code':
				cmiColumns.append(cellVal)
			elif cellVal == 'address_1' or cellVal == 'address 1' or cellVal == 'address1':
				cmiColumns.append(cellVal)
			elif cellVal == 'client_id' or cellVal == 'client_id_1':
				cmiColumns.append(cellVal)
			elif cellVal == 'segment1' or cellVal == 'segment2' or cellVal == 'segment' or re.search('^segment.+', cellVal) or re.search('.+segment.+', cellVal):
				cmiColumns.append(cellVal)

	return cmiColumns


def importDrugs():
	drugComplete = []
	with open("P:\\Epocrates Analytics\\Drug Compare\\Master Drug List\\drugs.csv", 'r') as inFile:
		reader = csv.DictReader(inFile)
		for item in reader:
			drugs = item['drugs']
			drugComplete.append(drugs)
	return drugComplete

def prepSasSegments(lmType, isProact):
	if isProact == 'No':
		cmiCompasSegmentation = "npi, address1, campaign_type, city, cl_fname, cl_lname, cl_me, cl_zip, clientid, compasid, middle_name, segment1, cl_specialty, state_code, tier, segment2, segment3"
	else:
		cmiCompasSegmentation = "npi, address1, campaign_type, city, cl_fname, cl_lname, cl_me, cl_zip, clientid, compasid, middle_name, segment1, cl_specialty, state_code, tier, segment2, segment3, keycode2"


	with open(os.path.join(desktop,'Ewok\\Datasharing', 'dataSharing.json'), 'r') as infile:
		config = json.loads(infile.read(), encoding='utf8')

	specialDataSharingDict = config
	with open(os.path.join(desktop, 'Ewok\\Configs', 'config.json'), 'r') as infile:
		config3 = json.loads(infile.read(), encoding='utf8')
		manu = str(config3['Manu'])
		segVariable = str(config3['segVariable']).lower()
		if lmType == 'Standard' or lmType == 'Exact':
			if config3['cmi_compass_client'] == 'N':
				if manu == 'Merck':
					sasSegments = specialDataSharingDict[manu]
				if manu == 'AstraZeneca':
					sasSegments = specialDataSharingDict[manu]
				if manu == 'Novartis':
					sasSegments = specialDataSharingDict[manu]
				if manu == 'Boehringer':
					sasSegments = specialDataSharingDict[manu]
				if manu == 'GSK':
					# if config3['gskEpsilonClient'] == 'N':
					sasSegments = specialDataSharingDict[manu]
					# else:
					# 	sasSegments = gskEpsilonSegments
				if manu == 'Amgen':
					sasSegments = specialDataSharingDict[manu]
				if manu == 'Sanofi-Aventis':
					sasSegments = specialDataSharingDict[manu]
				if manu == 'Biogen':
					sasSegments = specialDataSharingDict[manu]
				if manu == 'AbbVie':
					sasSegments = specialDataSharingDict[manu]

			if config3['cmi_compass_client'] == 'Y':
				if manu == 'Merck':
					sasSegments = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu]
				if manu == 'AstraZeneca':
					sasSegments = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu]
				if manu == 'Novartis':
					sasSegments = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu]
				if manu == 'Boehringer':
					sasSegments = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu]
				if manu == 'GSK':
					breakUP = specialDataSharingDict[manu].split(', ')
					breakUP.remove('clientid')
					sasSegments = cmiCompasSegmentation + ', ' + ', '.join(breakUP)
					# print(sasSegments)

		elif lmType == 'Standard_Seg' or lmType == 'Exact_Seg':
			if config3['cmi_compass_client'] == 'N':
				if manu == 'Merck':
					segList = specialDataSharingDict[manu].split(', ')
					if segVariable in segList:
						sasSegments = ', '.join(segList)
					else:
						sasSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'AstraZeneca':
					sasSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'Novartis':
					sasSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'Boehringer':
					sasSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'GSK':
					# if config3['gskEpsilonClient'] == 'N':
					sasSegments = specialDataSharingDict[manu] + ', ' + segVariable
					# else:
					# 	sasSegments = gskEpsilonSegments + ', {}'.format(segVariable)

				if manu == 'Amgen':
					sasSegments = segVariable + ', ' + specialDataSharingDict[manu]
				if manu == 'Sanofi-Aventis':
					sasSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'Biogen':
					sasSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'AbbVie':
					sasSegments = specialDataSharingDict[manu] + ', ' + segVariable

			if config3['cmi_compass_client'] == 'Y':
				if manu == 'Merck':
					sasSegments = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'AstraZeneca':
					breakUP = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu]
					breakUP = breakUP.split(', ')
					if segVariable in breakUP:
						sasSegments = ', '.join(breakUP)
					else:
						sasSegments = ', '.join(breakUP) + ', ' + segVariable
				if manu == 'Novartis':
					sasSegments = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'Boehringer':
					sasSegments = cmiCompasSegmentation + ', ' + specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'GSK':
					breakUP = specialDataSharingDict[manu].split(', ')
					breakUP.remove('clientid')					
					breakUP = cmiCompasSegmentation.split(', ') + breakUP
					# print(breakUP)
					# breakUP = breakUP.split(', ')
					if segVariable in breakUP:
						sasSegments = ', '.join(breakUP)
					else:
						sasSegments = ', '.join(breakUP) + ', ' + segVariable

	return sasSegments

def prepSqlSegments(lmType, isProact):
	foundIMSDR = 'No'
	with open(os.path.join(downloads,'csvFile.csv'), 'r') as infile:
		reader = csv.reader(infile)
		headers = next(reader)
		finalHeaders = [header.lower() for header in headers]
		if 'imsdr' in finalHeaders:
			foundIMSDR = 'Yes'
	with open(os.path.join(desktop,'Ewok\\Datasharing', 'dataSharing.json'), 'r') as infile:
		config = json.loads(infile.read(), encoding='utf8')

	specialDataSharingDict = config
	with open(os.path.join(desktop, 'Ewok\\Configs', 'config.json'), 'r') as infile:
		config3 = json.loads(infile.read(), encoding='utf8')
		manu = str(config3['Manu'])
		segVariable = str(config3['segVariable']).lower()
		if lmType == 'Standard' or lmType == 'Exact':
			if config3['cmi_compass_client'] == 'N':
				if manu == 'Merck':
					sqlSegments = specialDataSharingDict[manu]
				if manu == 'AstraZeneca':
					print('Found IMSDR: ', foundIMSDR)
					if foundIMSDR == 'Yes':
						sqlSegments = specialDataSharingDict['azSegmentationIMSDR']
					if foundIMSDR == 'No':
						sqlSegments = specialDataSharingDict['azSegmentationNPI']
				if manu == 'Novartis':
					sqlSegments = specialDataSharingDict['novartisSegmentation']
				if manu == 'Boehringer':
					sqlSegments = specialDataSharingDict[manu]
				if manu == 'GSK':
					# if config3['gskEpsilonClient'] == 'N':
					sqlSegments = specialDataSharingDict['GSKSegmentation']
					# else:
						# sqlSegments = specialDataSharingDict['gskEpsilon']
				if manu == 'Amgen':
					sqlSegments = specialDataSharingDict['amgenSegmentation']
				if manu == 'Sanofi-Aventis':
					sqlSegments = specialDataSharingDict['Sanofi-AventisSegmentation']
				if manu == 'Biogen':
					sqlSegments = specialDataSharingDict[manu]
				if manu == 'AbbVie':
					sqlSegments = specialDataSharingDict['abbvieSegmentation']

			if config3['cmi_compass_client'] == 'Y':
				if manu == 'Merck':
					sqlSegments = specialDataSharingDict[manu]
				if manu == 'AstraZeneca':
					sqlSegments = specialDataSharingDict['azCompassSegmentation']
				if manu == 'Novartis':
					sqlSegments = specialDataSharingDict['novartisCompassSegmentation']
				if manu == 'Boehringer':
					sqlSegments = specialDataSharingDict['boehringerCompassSegmentation']
				if manu == 'GSK':
					if isProact == 'No':
						sqlSegments = specialDataSharingDict['gskCompassSegmentation'] + ', ' + specialDataSharingDict['GSKSegmentation'].replace('clientid, ', '')
					else:
						sqlSegments = specialDataSharingDict['gskCompassSegmentation'] + ', keycode2' + ', ' + specialDataSharingDict['GSKSegmentation'].replace('clientid, ', '')
				if manu == 'Amgen':
					sqlSegments = specialDataSharingDict['amgenSegmentation']
				if manu == 'Sanofi-Aventis':
					sqlSegments = specialDataSharingDict[manu]
				if manu == 'Biogen':
					sqlSegments = specialDataSharingDict[manu]

		elif lmType == 'Standard_Seg' or lmType == 'Exact_Seg':
			if config3['cmi_compass_client'] == 'N':
				if manu == 'Merck':
					segList = specialDataSharingDict[manu].split(', ')
					if segVariable in segList:
						sqlSegments = ', '.join(segList)
					else:
						sqlSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'AstraZeneca':
					print('Found IMSDR: ', foundIMSDR)
					if foundIMSDR == 'Yes':
						sqlSegments = specialDataSharingDict['azSegmentationIMSDR'] + ', ' + segVariable
					if foundIMSDR == 'No':
						sqlSegments = specialDataSharingDict['azSegmentationNPI'] + ', ' + segVariable
				if manu == 'Novartis':
					sqlSegments = specialDataSharingDict['novartisSegmentation'] + ', ' + segVariable
				if manu == 'Boehringer':
					sqlSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'GSK':
					# if config3['gskEpsilonClient'] == 'N':
					sqlSegments = specialDataSharingDict['GSKSegmentation'] + ', ' + segVariable
					# else:
					# 	sqlSegments = specialDataSharingDict['gskEpsilon'] + ', ' + segVariable
				if manu == 'Amgen':
					sqlSegments = segVariable + ', ' + specialDataSharingDict['amgenSegmentation']
				if manu == 'Sanofi-Aventis':
					sqlSegments = specialDataSharingDict['Sanofi-AventisSegmentation'] + ', ' + segVariable
				if manu == 'Biogen':
					sqlSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'AbbVie':
					sqlSegments = specialDataSharingDict['abbvieSegmentation'] + ', ' + segVariable

			if config3['cmi_compass_client'] == 'Y':
				if manu == 'Merck':
					sqlSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'AstraZeneca':
					breakUP = specialDataSharingDict['azCompassSegmentation'].split(', ')
					if segVariable in breakUP:
						sqlSegments = ', '.join(breakUP)
					else:
						sqlSegments = ', '.join(breakUP) + ', ' + segVariable
				if manu == 'Novartis':
					breakUP = specialDataSharingDict['novartisCompassSegmentation'].split(', ')
					if segVariable in breakUP:
						sqlSegments = ', '.join(breakUP)
					else:
						sqlSegments = ', '.join(breakUP) + ', ' + segVariable
				if manu == 'Boehringer':
					breakUP = specialDataSharingDict['boehringerCompassSegmentation'].split(', ')
					if segVariable in breakUP:
						sqlSegments = ', '.join(breakUP)
					else:
						sqlSegments = ', '.join(breakUP) + ', ' + segVariable
				if manu == 'GSK':
					if isProact == 'No':
						breakUP = specialDataSharingDict['gskCompassSegmentation'].split(', ') + str(specialDataSharingDict['GSKSegmentation'].replace('clientid, ', '')).split(', ')
					else:
						breakUP = specialDataSharingDict['gskCompassSegmentation'].split(', ') + ['keycode2'] + str(specialDataSharingDict['GSKSegmentation'].replace('clientid, ', '')).split(', ')
					if segVariable in breakUP:
						sqlSegments = ', '.join(breakUP)
					else:
						sqlSegments = ', '.join(breakUP) + ', ' + segVariable
				if manu == 'Amgen':
					breakUP = specialDataSharingDict['amgenSegmentation'].split(', ')
					if segVariable in breakUP:
						sqlSegments = ', '.join(breakUP)
					else:
						sqlSegments = ', '.join(breakUP) + ', ' + segVariable
				if manu == 'Sanofi-Aventis':
					sqlSegments = specialDataSharingDict[manu] + ', ' + segVariable
				if manu == 'Biogen':
					sqlSegments = specialDataSharingDict[manu] + ', ' + segVariable

		return sqlSegments

def codeCounter():
	codeCount = 0
	if not os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
		with open(os.path.join(desktop, 'Ewok', 'codeCount.csv'), 'w') as outFile:
			writer = csv.writer(outFile, lineterminator='\n')
			headers = ['count']
			writer.writerow(headers)
			writer.writerow(['1'])
			codeCount = 1

	else:
		with open(os.path.join(desktop, 'Ewok', 'codeCountTEMP.csv'), 'w') as outFile2:
			tempWriter = csv.writer(outFile2, lineterminator='\n')
			headers = ['count']
			tempWriter.writerow(headers)
			with open(os.path.join(desktop, 'Ewok', 'codeCount.csv'), 'r') as inFile:
				reader = csv.reader(inFile)
				headers = next(reader)
				for row in reader:
					value = int(row[0])
					value += 1

			tempWriter.writerow([value])

		os.remove(os.path.join(desktop, 'Ewok', 'codeCount.csv'))
		os.rename(os.path.join(desktop, 'Ewok', 'codeCountTEMP.csv'), os.path.join(desktop, 'Ewok', 'codeCount.csv'))

		print('Code Count is: ', value)
	# 					# print(row[self.returnSourceIndexes()[0]], selectedItems)
	# 					row[self.returnSourceIndexes()[0]] = str(self.renameValueEdit.text())
	# 				row_writer.writerow(row)

	# 		for line in reader:
	# 			value = int(line[0])
	# 		value += 1
	# 		codeCount = value
	# print('Code Count is: ', codeCount)
	# return codeCount

def codeCountReader():
	if os.path.exists(os.path.join(desktop, 'Ewok', 'codeCount.csv')):
		with open(os.path.join(desktop, 'Ewok', 'codeCount.csv'), 'r') as inFile:
			reader = csv.reader(inFile)
			headers = next(reader)
			for line in reader:
				value = int(line[0])
		# print('Reader Value:', value)
		return value

	else:
		return 0


def state_to_abbrev(myFile, tnum=None, manu=None):
	us_state_abbrev = {
		'alabama': 'AL', 
		'alaska': 'AK', 
		'arizona': 'AZ',
		'arkansas': 'AR',
		'california': 'CA',
		'colorado': 'CO',
		'connecticut': 'CT',
		'delaware': 'DE',
		'district of columbia': 'DC',
		'dist. of columbia': 'DC',
		'florida': 'FL',
		'georgia': 'GA',
		'guam': 'GU',
		'hawaii': 'HI',
		'idaho': 'ID',
		'illinois': 'IL',
		'indiana': 'IN',
		'iowa': 'IA',
		'kansas': 'KS',
		'kentucky': 'KY',
		'louisiana': 'LA',
		'maine': 'ME',
		'maryland': 'MD',
		'massachusetts': 'MA',
		'michigan': 'MI',
		'minnesota': 'MN',
		'mississippi': 'MS',
		'missouri': 'MO',
		'montana': 'MT',
		'nebraska': 'NE',
		'nevada': 'NV',
		'new hampshire': 'NH',
		'new jersey': 'NJ',
		'new mexico': 'NM',
		'new york': 'NY',
		'north carolina': 'NC',
		'north dakota': 'ND',
		'northern mariana sslands':'MP',
		'ohio': 'OH',
		'oklahoma': 'OK',
		'oregon': 'OR',
		'palau': 'PW',
		'pennsylvania': 'PA',
		'puerto rico': 'PR',
		'rhode island': 'RI',
		'south carolina': 'SC',
		'south dakota': 'SD',
		'tennessee': 'TN',
		'texas': 'TX',
		'utah': 'UT',
		'vermont': 'VT',
		'virgin islands': 'VI',
		'virginia': 'VA',
		'washington': 'WA',
		'west virginia': 'WV',
		'wisconsin': 'WI',
		'wyoming': 'WY'}

	statesChanged = False
	myFilePart = myFile.split('.csv')[0]
	keys = us_state_abbrev.keys()
	stateEditsNeeded = False

	with open(myFile, 'r') as inFile:#, open(os.path.join(downloads, 'csvFile_STATES.csv'), 'w') as outFile:
		reader = csv.reader(inFile)
		found_state = False

		headers = next(reader)
		for index, col in enumerate(headers):
			cellVal = str(col).lower().replace('/', '_').replace('-', '_')
			if cellVal == 'state':
				found_state = True
				state_index = index
				break
		if found_state == False:
			for index, col in enumerate(headers):
				cellVal = str(col).lower().replace('/', '_').replace('-', '_')
				if re.search('^state.+', cellVal) or re.search('.+state.+', cellVal):
					found_state = True
					state_index = index
					break
		# print('Found State Column')

		if found_state == True:
			for row in reader:
				if row[state_index].lower() in keys:
					stateEditsNeeded = True
					# print('i found', row[state_index].lower())


	if stateEditsNeeded == True:
		with open(os.path.join(myFile), 'r') as inFile, open('{}_STATES.csv'.format(myFilePart), 'w') as outFile:
			reader = csv.reader(inFile)
			headers = next(reader)
			writer = csv.writer(outFile, lineterminator='\n')
			writer.writerow(headers)
			for row in reader:
				if row[state_index].lower() in keys:
					statesChanged = True
					row[state_index] = us_state_abbrev[row[state_index].lower()]
					writer.writerow(row)
				else:
					writer.writerow(row)


	else:
		if found_state == False:
			print('No State Column Found\n')
		else:
			print('No Edits Needed to State Column\n')


	if stateEditsNeeded == True:
		if tnum == None and manu == None:
			if os.path.exists('{}_STATES.csv'.format(myFilePart)):
				os.remove(myFile)
				os.rename('{}_STATES.csv'.format(myFilePart), myFile)

		else:
			#no zip fixes needed
			if os.path.exists('{}_STATES.csv'.format(myFilePart)):
				os.remove(myFile)
				if myFilePart.endswith('FIXED'):		
					os.rename('{}_STATES.csv'.format(myFilePart), '{}.csv'.format(myFilePart))
				else:
					os.rename('{}_STATES.csv'.format(myFilePart), '{}_MW_FIXED.csv'.format(myFilePart))

	if statesChanged == True:
		if tnum != None and manu != None:
			print(tnum, 'For', manu, '- State Names Were Converted to Abbrevations. . . Please Quickly Check All Were Converted!\n')
		else:
			print('State Names Were Converted to Abbrevations. . . Please Quickly Check All Were Converted!\n')

def format_zips(myFile, keepOld=None, tnum=None, manu=None):
	zipsChanged = False
	editsNeeded = False
	alleditsNeeded = False
	someEditsNeeded = False
	myFilePart = myFile.split('.csv')[0]

	with open(os.path.join(myFile), 'r') as inFile:
		reader = csv.reader(inFile)
		found_zip = False

		leadingZeros = 0
		missingHyphens = 0
		not5Digits = 0
		headers = next(reader)

		for index, col in enumerate(headers):
			cellVal = str(col).lower().replace('/', '_').replace('-', '_')
			if cellVal == 'zip' or cellVal == 'Postal' or (re.search('^zip.+', cellVal) and (cellVal != 'zip_4' or cellVal != 'zip4')) or re.search('^postal.+', cellVal) or re.search('.+_zip', cellVal) or re.search('.+ zip', cellVal) or re.search('.+_postal', cellVal) or re.search('.+ zip', cellVal) or re.search('.+ postal', cellVal):
				# headers[index] = 'zip'
				# zip_index = index
				zip_index = index
				found_zip = True
				break

		if found_zip == True:
			for row in reader:
				if row[zip_index] != '':
					if tnum == None and manu == None:
						if len(str(row[zip_index])) < 5 or (len(str(row[zip_index])) == 9 and not re.search('-', row[zip_index])) or (len(str(row[zip_index])) != 5 and (len(str(row[zip_index])) != 10 and not re.search('-', row[zip_index]))):
							alleditsNeeded = True
							editsNeeded = True
							break

					else:
						if len(str(row[zip_index])) == 9 and not re.search('-', row[zip_index]):
							someEditsNeeded = True
							editsNeeded = True
							break

	if editsNeeded == True:
		if alleditsNeeded == True:
			with open(os.path.join(myFile), 'r') as inFile, open('{}_ZIPS.csv'.format(myFilePart), 'w') as outFile:
				reader = csv.reader(inFile)
				headers = next(reader)
				writer = csv.writer(outFile, lineterminator='\n')
				writer.writerow(headers)
				for row in reader:
					if row[zip_index] != '':
						if len(str(row[zip_index])) < 5:
							newzip = str(row[zip_index]).zfill(5)
							row[zip_index] = str(row[zip_index]).zfill(5)
							leadingZeros += 1
							writer.writerow(row)
							zipsChanged = True

						elif len(str(row[zip_index])) < 10 and re.search('-', row[zip_index]):
							row[zip_index] = str(row[zip_index]).zfill(10)
							leadingZeros += 1
							writer.writerow(row)
							zipsChanged = True

						elif len(str(row[zip_index])) == 9 and not re.search('-', row[zip_index]):
							newzip = '-'.join([row[zip_index][:5], row[zip_index][5:9]])
							row[zip_index] = '-'.join([row[zip_index][:5], row[zip_index][5:9]])
							missingHyphens += 1
							writer.writerow(row)
							zipsChanged = True

						elif len(str(row[zip_index])) == 5:
							writer.writerow(row)

						elif len(str(row[zip_index])) == 10 and re.search('-', row[zip_index]):
								writer.writerow(row)
						else:
							row[zip_index] = row[zip_index][:5]
							not5Digits += 1
							writer.writerow(row)
							zipsChanged = True
					else:
						writer.writerow(row)

		elif someEditsNeeded == True:
			with open(os.path.join(myFile), 'r') as inFile, open('{}_ZIPS.csv'.format(myFilePart), 'w') as outFile:
				reader = csv.reader(inFile)
				headers = next(reader)
				writer = csv.writer(outFile, lineterminator='\n')
				writer.writerow(headers)
				for row in reader:
					if row[zip_index] != '':
						if len(str(row[zip_index])) == 9 and not re.search('-', row[zip_index]):
							newzip = '-'.join([row[zip_index][:5], row[zip_index][5:9]])
							row[zip_index] = '-'.join([row[zip_index][:5], row[zip_index][5:9]])
							missingHyphens += 1
							writer.writerow(row)
							zipsChanged = True

						elif len(str(row[zip_index])) == 5:
							writer.writerow(row)

						elif len(str(row[zip_index])) == 10 and re.search('-', row[zip_index]):
								writer.writerow(row)
						else:
							row[zip_index] = row[zip_index][:5]
							not5Digits += 1
							writer.writerow(row)
							zipsChanged = True
					else:
						writer.writerow(row)

	else:
		if found_zip == True:
			print('No edits needed to Zipcodes')
		else: 
			print('No Zipcode Column Found')

	if keepOld == None:
		if os.path.exists('{}_ZIPS.csv'.format(myFilePart)):
			os.remove(myFile)
			os.rename('{}_ZIPS.csv'.format(myFilePart), myFile)

	if keepOld == 'Yes':
		if os.path.exists('{}_ZIPS.csv'.format(myFilePart)):
			os.rename('{}_ZIPS.csv'.format(myFilePart), '{}_MW_FIXED.csv'.format(myFilePart))

	if zipsChanged == True:
		if tnum ==None and manu == None:
			print(leadingZeros, 'Leading 0\'s were added to zipcodes')
			print(missingHyphens, 'Hyphens were added to 9 Digit Zipcodes')
			print(not5Digits, 'Were corrected to 5 digit Zipcodes')
			print('Zips Were Formated. . . Please Quickly Check All Were Converted!\n')

		else:
			print(tnum, 'for', manu, 'needed the following updates')
			print(leadingZeros, 'Leading 0\'s were added to zipcodes')
			print(missingHyphens, 'Hyphens were added to 9 Digit Zipcodes')
			print(not5Digits, 'Were corrected to 5 digit Zipcodes')
			print('Zips Were Formated. . . Please Quickly Check All Were Converted!\n')
			state_to_abbrev('{}_MW_FIXED.csv'.format(myFilePart), tnum, manu)
	else:
		if tnum != None and manu != None:
			# print('THis is the section that runs to trigger state abbrev fixes if no zip fixes were needed')
			state_to_abbrev(myFile, tnum, manu)


def main():
	codeCounter()
	codeCountReader()
	fetchColumns()
	checkExtension()
	pipe_to_csv()
	tab_to_csv()
	csv_from_excel2(test)
	checkExtension2(test)
	pipe_to_csv2(test)
	tab_to_csv2(test)
	csv_from_excel()
	removeChar()
	incDupColumns()
	cmiCompasCheck()
	sqlSegments()
	state_to_abbrev()
	format_zips()



if __name__ == "__main__":
	main()





# w = xlrd.open_workbook(downloads + newest)
# sh = w.sheet_by_index(0)
# your_csv_file = open (downloads + 'target.csv', 'w')
# wr = csv.writer(your_csv_file, lineterminator='\n')
# reader = csv.reader(open(downloads + 'target.csv', 'r'))

# for rownum in range(sh.nrows):
# 	for item in sh.row_values(rownum):
# 		item = str(item).replace('\x8D', '')
# 	# print ", ".join(map(str, sh.row_values(rownum)))
# 	# if ", ".join(map(str, sh.row_values(rownum))).strip().strip(", ") != "":
# 	wr.writerow(sh.row_values(rownum))

# your_csv_file.close()




