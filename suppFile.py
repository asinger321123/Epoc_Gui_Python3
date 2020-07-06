import pandas
from openpyxl import Workbook, load_workbook
import re
import numpy
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
from termcolor import *
from colorama import init, Fore, Back, Style
import sqlite3

init(autoreset=True)

listText = 'supp.txt'
colList = []
finalDrugs = []
unmatchedDrugs = []
segmentList = []
segmentListSingle = []
colLength = None
csvFile = 'target.csv'
csvFileMod = 'target_mod.csv'
csvFileFinal = 'target_final.csv'
csvFileModTemp2 = 'target_mod_temp2.csv'
dt = str(datetime.datetime.now().strftime("%Y%m%d"))

args = sys.argv[1:]

userhome = os.path.expanduser('~')
downloads = userhome + '\\Downloads\\'
desktop = userhome + '\\Desktop\\'
newest = max(os.listdir(downloads), key=lambda f: os.path.getctime("{}/{}".format(downloads, f)))
stupid = ''

with open(os.path.join(desktop, 'TheEagleHasLanded.csv'), 'r') as passFile:
	reader = csv.DictReader(passFile)
	for item in reader:
		password = item['password']

if len(args) > 0:
	with open(os.path.join(desktop, 'Ewok\\Configs', args[0]), 'r') as infile:
		config = json.loads(infile.read(), encoding='utf8')

		listMatchType = str(config['suppMatchType'])
		if str(config['caseType']) == 'Targeting':
			date = str(config['date'])
		brand = str(config['Brand'])
		manu = str(config['Manu'])
		yourIn = str(config['yourIn'])
		if str(config['caseType']) == 'listMatch':
			reIn = str(config['reIn'])
			name = "{requester}_{manufact}_{brand}_{dt}_{initials}".format(requester=reIn, manufact=manu, brand=brand, dt=dt, initials=yourIn)
		tableName = str(config['tableName'])+'_supp'

def csv_from_excel():
	newest = str(config['suppFileName'])
	w = xlrd.open_workbook(downloads + newest)
	sh = w.sheet_by_index(0)
	your_csv_file = open (downloads + 'target.csv', 'w')
	wr = csv.writer(your_csv_file, lineterminator='\n')

	for rownum in range(sh.nrows):
		wr.writerow(sh.row_values(rownum))

	your_csv_file.close()

def checkExtension():
	newest = str(config['suppFileName'])
	filename, extension = os.path.splitext(os.path.join(downloads, newest))
	print(extension)
	if extension == '.xlsx':
		csv_from_excel()
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
	else:
		with open(os.path.join(downloads, 'target.csv'), 'w') as out:
			writer = csv.writer(out, lineterminator='\n')
			writer.writerows([['No File Found']])


def pipe_to_csv():
	newest = str(config['suppFileName'])
	with open(os.path.join(downloads, newest), 'r') as f, open(os.path.join(downloads, 'target.csv'), 'w') as out:
		pipereader = csv.reader(f, delimiter='|')
		csvwriter = csv.writer(out, delimiter=',', lineterminator='\n')
		for row in pipereader:
			csvwriter.writerow(row)

def tab_to_csv():
	newest = str(config['suppFileName'])
	with open(os.path.join(downloads, newest), 'r') as f, open(os.path.join(downloads, 'target.csv'), 'w') as out:
		tabreader = csv.reader(f, delimiter='\t')
		csvwriter = csv.writer(out, delimiter=',', lineterminator='\n')
		for row in tabreader:
			csvwriter.writerow(row)


def getMain():
	with open (downloads + 'csvFile.csv', 'r') as inFile2, open(downloads + csvFileModTemp2, 'w') as targetFile:
		r = csv.reader(inFile2)
		headers = next(r)
		for index, col in enumerate(headers):
			cellVal = str(col).lower().replace('/', '_').replace('-', '_')
			#Regular Expression Rules. We can add new Rules as we need to this list to cover more common cases.
			if cellVal == 'npi' or cellVal == 'npi_id' or re.search('.+ npi .+', cellVal) or re.search('.+_npi_.+', cellVal) or re.search('^npi.+', cellVal) or re.search('.+ npi', cellVal) or re.search('.+ npi', cellVal):
				print(cellVal, ': ',  'I found a NPI Number')
				headers[index] = 'npi'
			elif cellVal == 'me' or cellVal == 'me_id' or cellVal == 'meded' or re.search('.+ me .+', cellVal) or  re.search('.+_me_.+', cellVal) or re.search('^me .+', cellVal) or re.search('.+ me', cellVal) or re.search('.+ me', cellVal) or re.search('^me_.+', cellVal):
				print(cellVal, ': ', 'I found a ME Number')
				headers[index] = 'me'
			elif cellVal == 'fname' or re.search('^first.+name', cellVal) or re.search('.+first.+name', cellVal) or re.search('.+fname', cellVal) or re.search('.+first', cellVal) or re.search('.+frst.+', cellVal):
				print(cellVal, ': ', 'I found a First Name')
				headers[index] = 'fname'
			elif re.search(r'lname|^l.+name|.+last|.+lname|.+last.+name', cellVal):
				print(cellVal, ': ',  'I found a Last Name')
				headers[index] = 'lname'
			elif cellVal == 'zip_4' or cellVal == 'zip4':
				headers[index] = 'whatever'
			elif cellVal == 'Group' or cellVal == 'group':
				headers[index] = '_group'
			elif cellVal == 'zip' or cellVal == 'Postal' or (re.search('^zip.+', cellVal) and (cellVal != 'zip_4' or cellVal != 'zip4')) or re.search('^postal.+', cellVal) or re.search('.+_zip', cellVal) or re.search('.+ zip', cellVal) or re.search('.+_postal', cellVal) or re.search('.+ zip', cellVal) or re.search('.+ postal', cellVal):
				print(cellVal, ': ',  'I found a Zip/Postal Code')
				headers[index] = 'zip'
			elif cellVal.startswith(('0','1','2','3','4','5','6','7','8','9')):
				print('I added an underscore to: ', cellVal)
				headers[index] = '_' + headers[index]

		w = csv.writer(targetFile, lineterminator='\n')
		w.writerow(headers)
		for row in r:
			w.writerow(row)

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

def postgresConn():
	df = pandas.read_csv('{downloads}{csvFile}'.format(downloads=downloads, csvFile=csvFileMod), encoding='ISO-8859-1', dtype=str)
	myHeaders = list(df)


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

	df.to_sql('{}'.format(tableName), conn, if_exists='replace', index=False)

	neededColumns = ['me', 'npi', 'fname', 'lname', 'zip']
	for col in neededColumns:
		if col not in myHeaders:
			try:
				cur.executescript('ALTER TABLE {} ADD COLUMN {} text;'.format(tableName, col))
			except:
				print(col, 'Already Exists . . .', colored('Skipping', 'red'))
				continue 

	conn.commit()

	if listMatchType =='Standard':
		# if foundFullName == 'n':
		export = """{} from {};""".format(selectMain5, tableName)
		pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'supp.txt'), index=False, sep='\t')

		# if foundFullName == 'y':
		# 	export = """{select} from {tableName};""".format(select=selectFullName, tableName=tableName)
		# 	pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'supp.txt'), index=False, sep='\t')

	elif listMatchType =='Exact':
		export = """{select} from {tableName};""".format(select=selectMain2, tableName=tableName)
		pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'supp.txt'), index=False, sep='\t')

	elif listMatchType =='Fuzzy':
		export = """{} from {};""".format(selectFuzzy, tableName)
		pandas.read_sql_query(export, conn).to_csv(os.path.join(downloads, 'supp.txt'), index=False, sep='\t')

	print('')
	print('SQL Export Complete\n')


def removeChar():
	inputFile = open(downloads + csvFile, 'r')
	outputFile = open(downloads + 'csvFile.csv', 'w')
	conversion = '-/%$# @<>+*?&'
	newtext = '_'

	index = 0
	for line in inputFile:
		if index == 0:
			for c in conversion:
				line = line.replace(c, newtext)

		outputFile.write(line)
		index += 1



def get_Cols():
	with open(downloads + 'target.csv', 'r') as f:
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


def removeFiles():
	# os.remove(os.path.join(downloads, 'target.txt'))
	os.remove(os.path.join(downloads, 'target_mod.csv'))
	os.remove(os.path.join(downloads, 'target.csv'))
	os.remove(os.path.join(downloads, 'csvFile.csv'))
	if str(config['caseType']) == 'Targeting':
		targetFolder = manu+" "+brand
		os.chdir("P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}".format(date = date, slashes = "\\", targetFolder=targetFolder))
		if os.path.exists("P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Supp".format(date = date, slashes = "\\", targetFolder=targetFolder)):
			print('Supp Folder already exist. Skipping creating this folder')
		if not os.path.exists("P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Supp".format(date = date, slashes = "\\", targetFolder=targetFolder)):
			os.mkdir('Supp')
		copyfile(downloads + listText, "P:\\Epocrates Analytics\\TARGETS\\{date}{slashes}{targetFolder}\\Supp\\supp.txt".format(date = date, slashes = "\\", targetFolder=targetFolder))
	else:
		os.chdir("""P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}""".format(folderName = name))
		if os.path.exists("P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}\\Supp".format(slashes = "\\", folderName=name)):
			print('Supp Folder already exist. Skipping creating this folder')
		if not os.path.exists("P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}\\Supp".format(slashes = "\\", folderName=name)):
			os.mkdir('Supp')
		copyfile(downloads + listText, "P:\\Epocrates Analytics\\List Match\\List Match Folder\\{folderName}\\Supp\\supp.txt".format(slashes = "\\", folderName=name))
	os.remove(os.path.join(downloads, listText))
	if os.path.exists(os.path.join(downloads, 'csvFile1.csv')):
		os.remove(os.path.join(downloads, 'csvFile1.csv'))
	if os.path.exists(os.path.join(downloads, csvFileModTemp2)):
		os.remove(os.path.join(downloads, csvFileModTemp2))

# def copyTarget():
# 	copyfile(downloads + listText, outFileFinal)

	print('')
	print('')
	print('Suppression Program completed')

# csv_from_excel()

checkExtension()
removeChar()
get_Cols()
get_cols_names()
getMain()
postgresConn()
removeFiles()
