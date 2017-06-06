def errors_to_bosh_tasks_cmds(cli_output_json)
  tasks_in_error = -> (row) { row.fetch('state') == 'error' }
  to_task_id = -> (row) { row.fetch('id') }
  to_bosh_command = -> (task) { "bosh-go task #{task} --debug" }

  cli_output_json
    .fetch('Tables')
    .first
    .fetch('Rows')
    .select(&tasks_in_error)
    .map(&to_task_id)
    .map(&to_bosh_command)
end