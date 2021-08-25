#!/usr/bin/python3

def reportOneMod(modPresentBool, modNameString):
    if modPresentBool:
        modOut = ""
    else:
        modOut = " not"

    print("module " + modNameString + modOut + " present")

try:
  import psycopg2

  psycopg = True
except ModuleNotFoundError:
  psycopg = False

reportOneMod(psycopg, "psycopg2")

try:
    import sqlalchemy

    salchemy = True
except ModuleNotFoundError:
    salchemy = False

reportOneMod(salchemy, "sqlalchemy")
