# histogram.sh

### A simple word counter that can read text from multiple .txt, .pdf or .ps files, and export to .csv or plaintext.
#### Author: Tomasz Pawłowski

## DEPENDENCIES: 
- bash 4+
- pdftotext
- ps2pdf


## USAGE 
```bash
  histogram.sh [FLAGS] [FILES]
```


## FLAGS: 
    -h, --help                 Print help information
    --csv [FILENAME]           Write output to a .csv file (default: out.csv)
    -o, --output [FILENAME]    Specify output file (default: out.txt)
    -r, --raw-text "[TEXT]"    Take raw input as the text for analysis
    -f                         Overwrite output file (default: ask user)

