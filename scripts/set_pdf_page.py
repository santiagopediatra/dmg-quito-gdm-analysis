import sys
import pikepdf

filename, width, height = sys.argv[1:]
with pikepdf.open(filename, allow_overwriting_input=True) as document:
    document.pages[0].MediaBox = pikepdf.Array([0, 0, float(width), float(height)])
    document.save(filename)
