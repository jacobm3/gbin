#!/usr/bin/env python3
#
# xsheets2csvs.py -- split an Excel workbook into one CSV file per worksheet.
#
# What it does: opens the Excel file you name on the command line, then for each
# tab (worksheet) inside it, writes a separate .csv file named
# "<excelbasename>_<sheetname>.csv" in the current directory.
#
# Example: a workbook "budget.xlsx" with sheets "Jan" and "Feb" produces
#   budget_Jan.csv  and  budget_Feb.csv
#
# How to run it:
#   ./xsheets2csvs.py budget.xlsx     (or: python3 xsheets2csvs.py budget.xlsx)
#
# Prerequisites: pandas, plus an Excel engine such as openpyxl for .xlsx files
#   (install with: pip install pandas openpyxl).
# Caveat: the CSV name uses everything before the FIRST dot in the filename, so
# a name like "2024.budget.xlsx" would be truncated at "2024".

# pandas: data-analysis library; used here to read Excel and write CSV.
import pandas as pd
# sys: used to read the command-line argument and to exit on error.
import sys

# Convert every sheet of one Excel file into its own CSV file.
def excel_to_csv(excel_file):
    # Load the entire Excel file
    # ExcelFile opens the workbook once so we can list and read its sheets.
    xls = pd.ExcelFile(excel_file)

    # Loop through each sheet in the Excel file
    # sheet_names is a list of the tab names in the workbook.
    for sheet_name in xls.sheet_names:
        # Read the specific sheet
        # parse() loads one worksheet into a DataFrame (an in-memory table).
        df = xls.parse(sheet_name)

        # Create a CSV filename based on the Excel filename and sheet name
        # excel_file.split('.')[0] takes the part before the first '.', then we
        # append "_<sheetname>.csv".  e.g. "budget" + "_" + "Jan" + ".csv".
        csv_file = f"{excel_file.split('.')[0]}_{sheet_name}.csv"

        # Save the DataFrame to a CSV file
        # index=False omits pandas' automatic row-number column from the output.
        df.to_csv(csv_file, index=False)
        # Tell the user which file was written.
        print(f"Saved {csv_file}")

# Only run the following when this file is executed directly (not imported).
if __name__ == "__main__":
    # sys.argv[0] is the script name; we need at least one more item (the Excel
    # filename). If it's missing, show a message and exit with error status 1.
    if len(sys.argv) < 2:
        print("Please provide an Excel filename as an argument.")
        sys.exit(1)

    # Take the first argument as the workbook path and process it.
    excel_file = sys.argv[1]
    excel_to_csv(excel_file)
