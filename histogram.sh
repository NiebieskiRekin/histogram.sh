#!/usr/bin/bash

# histogram.sh - simple word counter that can read text from multiple .txt, .pdf or .ps files, and export to .csv or plaintext.
# Author: Tomasz Pawłowski

# DEPENDENCIES 
# bash 4+
# pdftotext
# ps2pdf

# TODO: further testing

# ---------------------------------------------------------------------------------------------------

# GLOBAL VARIABLES
# hash map of words (converted to uppercase) and their counts, bash 4+ only 
declare -A dictionary
document_type=txt
text=""
output="/dev/stdout"
has_output_file=false
csv=false
next_arg_csv_name=false
force_overwrite=false

# counts words in a given text and saves the counts in an associative array "dictionary"
function count_words {
  for word in $@
  do
    # clear whitespace, numbers and punctuation, make all letters lowercase and also remove unprintable characters
    token=$(echo "$word" | tr '[:upper:]' '[:lower:]' | tr -d "[:punct:][:blank:][:digit:]" | sed "s/[^[:print:]]//g")
    # increase count for the current word
    if [ "$token" != "" ]; then
      ((dictionary[$token]++))
    fi 
  done
}

# deduces document type based on file extension
function find_document_type {
  file=$1
  filename=$(basename -- "$file")
  extension="${filename##*.}"

  if [ "$extension" = "$filename" ]; then
    # file doesn't have extension
    extension=""
  fi
  
  if [ "$extension" = "pdf" ] || [ "$extension" = "ps" ] || [ "$extension" = "txt" ]; then
    document_type=$extension
  elif [ "$extension" = "" ]; then # files without extension are treated as plaintext
    document_type="txt"
  elif [ "$extension" = "csv" ]; then
    document_type=$extension
  else  # files different than plaintext, pdf, ps for input and plaintext, csv for output are invalid
    document_type="INVALID"
  fi
}

# gets text from the document
function retrieve_text {
  file=$1

  #check if file is present
  if ! head -n 1 "$file" > "/dev/null" 2>&1 ; then
    echo "Error: File $file not found" 1>&2
    exit 5
  fi 
  
  if [ "$document_type" = "txt" ]; then # plaintext
    text=$(cat "$file")
  elif [ "$document_type" = "ps" ]; then # postscript needs converting twice, requires: ps2pdf & pdftotext
    filename=$(basename -- "$file")
    filename="${filename%.*}"

    # temporary directory to avoid name conflicts
    tmpdir=$(mktemp -d "/tmp/histogram.XXXXXXXXXXXX")


    # convert ps to pdf, and then pdf to plaintext,
    # if any conversion script isn't available throws an exception 
    ps2pdf "${file}" "${tmpdir}${filename}.pdf" || (echo "Error: ps2pdf not found" 1>&2 ; exit 11) 
    pdftotext "${tmpdir}${filename}.pdf" "${tmpdir}${filename}.txt" || (echo "Error: pdftotext not found" 1>&2 ; exit 12) 

    # read text from converted file
    text=$(cat "${tmpdir}${filename}.txt")

    # remove temporary directory
    rm -r "$tmpdir"
        
  elif [ "$document_type" = "pdf" ]; then # pdf also requires conversion, pdftotext is necessary
    filename=$(basename "$file")
    filename="${filename%.*}"

    # temporary directory to avoid name conflicts
    tmpdir=$(mktemp -d "/tmp/histogram.XXXXXXXXXXXX")

    # convert pdf to plaintext, 
    pdftotext "${file}" "${tmpdir}${filename}.txt" || (echo "Error: pdftotext not found" 1>&2 ; exit 12) 

    # read text from converted file
    text=$(cat "${tmpdir}${filename}.txt")

    # remove temporary directory
    rm -r "$tmpdir"
    
  else 
    echo "Error: Incorrect input file format. Only .txt, .pdf, .ps formats are supported."
    exit 10
  fi
}

 

function print_help {
  echo "histogram.sh"
  echo "Simple word counter that can read text from multiple .txt, .pdf or .ps files, and export to .csv or plaintext."
  echo "Author: Tomasz Pawłowski" 
  echo ""
  echo "USAGE: "
  echo -e "$0 [FLAGS] [FILES]"
  echo ""
  echo "FLAGS: "
  echo -e "\t -h, --help \t\t\t Print help information"
  echo -e "\t --csv [FILENAME] \t\t Write output to a .csv file (default: out.csv)"
  echo -e "\t -o, --output [FILENAME] \t Specify output file (default: out.txt)"
  echo -e "\t -r, --raw-text \"[TEXT]\" \t Take raw input as the text for analysis"
  echo -e "\t -f \t\t\t\t Overwrite output file (default: ask user)"
  exit 0
}

# Main driver 

if [ $# -eq 0 ]; then
  print_help
fi


for arg in $@
do
  if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
    print_help
  elif [ "$arg" = "-f" ]; then
    force_overwrite=true
  elif [ "$arg" = "--csv" ]; then
    next_arg_csv_name=true
    csv=true
    output="out.csv"
  elif [ $next_arg_csv_name = true ]; then # set filename for .csv output
    next_arg_csv_name=false
    filename=${arg%%.*}
    output="${filename}.csv"
  elif [ "$arg" = "--output" ] || [ "$arg" = "-o" ]; then
    has_output_file=true
    output="out.txt"
  elif [ "$has_output_file" = "true" ]; then
    has_output_file=false;
    output="$arg"
    find_document_type "$output"
    if [ "$document_type" = "csv" ]; then
      filename=${arg%%.*}
      output="${filename}.csv"
      csv=true
    fi
  elif [ "$arg" = "--raw-text" ] || [ "$arg" = "-r" ]; then
    raw_text=true
  elif [ "$raw_text" = true ]; then # directly count words in the input onwards
    count_words "$arg"
  elif [ "${arg:0:1}" = "-"  ]; then
    echo "Unrecognized option $arg."
    echo "See --help for more details."
    exit 3
  else      # if not a switch or its complement, then arg is considered to be an input file
    find_document_type "$arg"
    retrieve_text "$arg"
    count_words "$text"      
  fi
done



# check if output file is empty, warn if it's not, and ask the user if we wants to overwrite file
touch "$output" # create file if it doesn't exist 
if [ $has_output_file = true ]  &&  [ $force_overwrite = "false" ] && [ "$(cat $output)" != "" ]; then   # if file is not empty
  echo 2>&1 "Output file '$output' is not empty."
  read -p "Do you want to overwrite the file? " -n 1 -r # ask user what to do
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]] # if first character of the answer isn't y or Y then exit
  then
    echo 2>&1 "Exiting"
    exit 1 
  fi
  echo "" > "$output" # clear file
fi



if [ $csv = true ]; then
  # csv output format
  for word in ${!dictionary[@]}
  do 
    echo ",${word},${dictionary[$word]}" 
  done | sort -r -t ',' -n -k3  >> "$output" # sorting, words appearing the most often are on top
else
  # plaintext output format
  for word in ${!dictionary[@]}
  do
    echo "${word} ${dictionary[$word]}" 
  done | sort -r -k2 -n >> "$output" # sorting, words appearing the most often are on top
fi

