# How to update example log files for `get_api_calls_spec.rb`

use `update_api_call.sh` to extract new examples for the tests.
To add new entries or adjust syntax, please enhance the script instead of manually adjusting the files.

The script executes the following steps:
* Download lifecycle.log from concourse pipeline
* Get current line of catalog v2 and v3 log
* Retrieve / update reasonable selection from lifecycle logs
* Remove landscape specifics from example log entries

The expected output needs to be updated manually.