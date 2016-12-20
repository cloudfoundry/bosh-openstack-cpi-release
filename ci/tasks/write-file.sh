#!/usr/bin/env bash

set -e

: ${file_content:?}

echo ${file_content} > file