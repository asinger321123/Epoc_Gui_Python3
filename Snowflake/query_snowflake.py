import snowflake.connector
import pandas as pd
from collections import defaultdict
from snowflake.sqlalchemy import URL
from sqlalchemy import create_engine

#query: placeholder/description of what the arguement needs to be/ takes the query as an arguement
def querySnowflake(query, returnType):
    
    #con = variable short for connection/ 9-14: arguements used to establish a connection. 
    con = snowflake.connector.connect(
    user = 'EpocratesComData',
    password = 'Epocrates123!',
    account = 'athenahealth',
    database = 'EPOCRATES_PROD',
    warehouse = 'EPOCRATES_ANALYTICS_PROD')

    #con.cursor().execute: how you execute a cursor/cursor: simulates user experience 
    con.cursor().execute('USE ROLE EPOC_ANALYTICS_R')
    # con.cursor().execute('USE DATABASE EPOCRATES_PROD')
    con.cursor().execute('USE WAREHOUSE EPOCRATES_ANALYTICS_PROD')
    con.cursor().execute('USE SCHEMA EPOC_ANALYTICS')
    cur = con.cursor()

    # use pandas to read SQL Cursor to pandas DF
    resultsDF = pd.read_sql_query(query, con)
    # pandas DF to Dictionary
    resultsDFDict = pd.read_sql_query(query, con).to_dict('records')

    #returns a both the Dictionary and dataframe results as Tuple so we can use both if needed
    # print(resultsDFDict)
    if returnType == 'dataFrame':
        return resultsDF
    elif returnType == 'dict':
        return resultsDFDict
    else:
        return resultsDFDict, resultsDF


def writeSnowflake(inputDataFrame,tableName):
    # Fill in your SFlake details here
    engine = create_engine(URL(
        account = 'athenahealth',
        user = 'EpocratesComData',
        password = 'Epocrates123!',
        database = 'EPOCRATES_PROD',
        schema = 'EPOC_ANALYTICS',
        warehouse = 'EPOCRATES_ANALYTICS_PROD',
        role='EPOC_ANALYTICS_RW'
    ))
    # ), echo=True) 
    # ^the echo=True function tells us which query is being run on snowflake; needed to share with Raj via JIRA ticket
    # Echo=true: to retrieve creation query "if_exists=" (below) should be set to replace. Otherwise, the funciton returns insert queries (not relevant)
    
    print('Engine Created\n')
    
    connection = engine.connect()
    trans = connection.begin()
    print('Connected to Engine\n')


    # THIS LETS US RUN SQL FORMATED QUERIES DIRECTLY TO SNOWFLAKE
    # engine.execute("""
    # UPDATE DLA_DASH
    # SET ONE = 54321
    # WHERE ONE = 10
    # """)
    # trans.commit()



    # THIS WILL TAKE A PANDAS DATA FRAME AND APPEND THE DATA TO AN EXISTING TABLE ON SNOWFLAKE
    inputDataFrame.to_sql('{}'.format(tableName), con=engine, index=False, if_exists='append') #make sure index is False, Snowflake doesnt accept indexes
    #df = data frame; to_sql: takes the argument of a dataframe; when pushing SF data, index ALWAYS false;  
    # if_exists= if table exists (options are 'append' or 'replace')
    # possibility to create duplicate rows
    print('Data Pushed To Snowflake')
    
    connection.close()
    engine.dispose()

def main():
    #""" allows for formatted queries that have line breaks
    querySnowflake(query)
    writeSnowflake(inputDataFrame,tableName)

#'==' check the string/value of the variable only run query if name 
if __name__ == "__main__":
    main()

