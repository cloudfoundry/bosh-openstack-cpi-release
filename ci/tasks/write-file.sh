#!/usr/bin/env bash

set -e

: ${file_content:?}

mkdir -p write-file
echo ${file_content} > write-file/file