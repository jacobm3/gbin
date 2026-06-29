#!/usr/bin/env
#
# pdf2text.py -- extract the plain text out of a PDF file and print it.
#
# What it does: opens the PDF named on the command line, reads every page, pulls
# the text content from each page, joins it all together, and prints it to
# standard output. You can redirect that into a .txt file.
#
# How to run it:
#   python3 pdf2text.py somefile.pdf
#   python3 pdf2text.py somefile.pdf > somefile.txt
# (Note: the shebang line above is incomplete -- it says `#!/usr/bin/env` with
#  no interpreter -- so run this explicitly with `python3` rather than `./`.)
#
# Prerequisites: the PyPDF2 library (install with: pip install PyPDF2).
# Caveat: this uses the OLD PyPDF2 API (PdfFileReader, numPages, getPage,
# extractText), which newer PyPDF2 versions renamed/removed. It needs an older
# PyPDF2 (roughly 1.x) to run as-is. Text extraction quality varies and won't
# work on scanned/image-only PDFs (those need OCR).

# PyPDF2: third-party library for reading and manipulating PDF files.
import PyPDF2
# sys: used here to read command-line arguments and to exit on error.
import sys

# Read all text from one PDF file and return it as a single string.
def extract_text_from_pdf(pdf_file):
    # Open the PDF in binary read mode ('rb'); PDFs are not plain text.
    # `with` makes sure the file is closed automatically when we're done.
    with open(pdf_file, 'rb') as file:
        # Create a reader object that understands the PDF structure.
        reader = PyPDF2.PdfFileReader(file)
        # Accumulate page text into this string.
        text = ''
        # numPages is the total page count; range(...) gives 0,1,2,...,n-1.
        for page_num in range(reader.numPages):
            # Grab one page object by its index.
            page = reader.getPage(page_num)
            # Pull the text from that page and append it to our running string.
            text += page.extractText()
    # Hand back everything we collected.
    return text

def main():
    # sys.argv is the list of command-line words; argv[0] is the script name,
    # so a single file argument means the list has length 2. If not, show usage
    # and exit with status 1 (non-zero = error).
    if len(sys.argv) != 2:
        print("Usage: python extract_text_from_pdf.py <pdf_file>")
        sys.exit(1)

    # The first (and only) argument is the path to the PDF.
    pdf_file = sys.argv[1]
    # Do the actual extraction...
    text = extract_text_from_pdf(pdf_file)
    # ...and print all of it to standard output.
    print(text)

# Standard Python entry-point guard: only run main() when this file is executed
# directly, not when it is imported as a module by another script.
if __name__ == '__main__':
    main()
