#!/usr/bin/env bash

set -e

optional_value file_content

mkdir -p write-file
echo "$(echo ${file_content} | sed -r  -e 's/ /\n/g ' -e 's/\nCERTIFICATE-----/ CERTIFICATE-----/g')" > write-file/file