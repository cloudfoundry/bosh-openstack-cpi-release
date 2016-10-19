def errors_to_bosh_tasks_cmds(cli_output)
  rows_with_error = -> (row) { row[2] != 'done' }
  to_task_number = -> (row) { row[1] }
  to_stripped_columns = -> (row) { row.split('|').map(&:strip) }
  to_bosh_command = -> (task) { "bosh task #{task} --debug" }
  table_rows = -> (line) { line.start_with?('|') }

  cli_output
    .split("\n")
    .select(&table_rows)
    .map(&to_stripped_columns)
    .select(&rows_with_error)
    .map(&to_task_number)
    .sort
    .map(&to_bosh_command)
end
