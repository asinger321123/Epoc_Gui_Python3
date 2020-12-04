import sys
import os
from PyQt4 import QtCore, QtGui, uic
from PyQt4.QtGui import *
from PyQt4.QtCore import *
from PyQt4.QtWebKit import QWebView
import pandas as pd
import json

userhome = os.path.expanduser('~')
desktop = userhome + '\\Desktop\\'

#store path to UI File that is loaded on start up
qtCreatorFile = os.path.join(desktop,'GitHub_Python\\Targeting\\TestList','dataviewer.ui') # Enter file here.
Ui_MainWindow, QtBaseClass = uic.loadUiType(qtCreatorFile)


class PandasModel(QtCore.QAbstractTableModel):
	"""
	Class to populate a table view with a pandas dataframe
	"""
	def __init__(self, data, parent=None):
		QtCore.QAbstractTableModel.__init__(self, parent)
		self._data = data

	def rowCount(self, parent=None):
		return self._data.shape[0]

	def columnCount(self, parent=None):
		return self._data.shape[1]

	def data(self, index, role=QtCore.Qt.DisplayRole):
		if index.isValid():
			if role == QtCore.Qt.DisplayRole:
				return str(self._data.iloc[index.row(), index.column()])
		return None

	def headerData(self, col, orientation, role):
		if orientation == QtCore.Qt.Horizontal and role == QtCore.Qt.DisplayRole:
			return self._data.columns[col]
		return None


	def flags(self, index):
		flags = super(self.__class__, self).flags(index)
		flags |= QtCore.Qt.ItemIsEditable
		flags |= QtCore.Qt.ItemIsSelectable
		flags |= QtCore.Qt.ItemIsEnabled
		flags |= QtCore.Qt.ItemIsDragEnabled
		flags |= QtCore.Qt.ItemIsDropEnabled
		return flags

	def sort(self, Ncol, order):
		"""Sort table by given column number.
		"""
		try:
			self.layoutAboutToBeChanged.emit()
			self._data = self._data.sort_values(self._data.columns[Ncol], ascending=not order)
			self.layoutChanged.emit()
		except Exception as e:
			print(e)




class MyApp(QtGui.QMainWindow, Ui_MainWindow):
	def __init__(self):
		QtGui.QMainWindow.__init__(self)
		Ui_MainWindow.__init__(self)
		self.setupUi(self)
		self.setAttribute(QtCore.Qt.WA_DeleteOnClose)

		args = sys.argv[1:]

		# with open(os.path.join(desktop, 'GitHub_Python\\Targeting\\TestList', 'dataFrames.json'), 'r') as infile:
		with open(os.path.join(desktop, 'GitHub_Python\\Targeting\\TestList', args[0]), 'r') as infile:
			self.dataframeDict = json.loads(infile.read())


		#declare UI objects through find child statement
		self.dataframes = self.findChild(QListWidget, 'dataframe_listWidget')
		self.dataTable = self.findChild(QTableView, 'dataTable_tableView')
		self.rowCount = self.findChild(QLabel, 'rowCount_Label')


		for k in self.dataframeDict.keys():
			self.dataframes.addItem(k)


		#callbacks
		self.dataframes.itemClicked.connect(self.json_to_dataframe)


	def json_to_dataframe(self):
		selectedItem = sorted([index.row() for index in self.dataframes.selectedIndexes()], reverse=True)
		for i in selectedItem:
			selectedDF = self.dataframes.item(i).text()
		
		convertedDF = pd.read_json(self.dataframeDict[selectedDF])
		self.updateDateframeCount(convertedDF)

		model = PandasModel(convertedDF)
		self.dataTable.setModel(model)

	def updateDateframeCount(self, dataframe):
		dfCount = len(dataframe.index)
		self.rowCount.setText("Count: " + str(dfCount))


#Standard Block of Code that initiates the code on start up of the python code. Might not ever need to make changes to this
if __name__ == "__main__":
	app = QtGui.QApplication(sys.argv)
	window = MyApp()
	QtGui.QApplication.setStyle(QtGui.QStyleFactory.create('plastique'))

	window.show()
	sys.exit(app.exec_())