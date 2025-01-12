#!/bin/bash

if [[ $- == *i* ]]; then
        echo "This file is meant to be sourced."
        return 1
fi

shim_directory="SHIMS~-NOT~-SET"

