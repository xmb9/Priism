#!/bin/bash

source autobuild-conf.sh

if [[ $shim_directory == "SHIMS~-NOT~-SET" ]]; then
    while true; do
        echo "Where are your shims located? (Must be an ABSOLUTE path and not have quotes!)"
        read -p "> " choice
        if [[ -d $choice ]]; then
            sed -i 's/SHIMS~-NOT~-SET/"${choice}"/g' autobuild-conf.sh
            echo "Re-run this script to start building."
            exit
        else
            echo "Invalid directory."
        fi
    done
else
    if [ "$EUID" -ne 0 ]; then echo "Please run as root."; exit 1; fi
    echo "Beginning autobuild..."
    for f in ${shim_directory}/*
    do
         echo "Building ${f}"
         bash priism_builder.sh "$f"
    done
fi
