#!/usr/bin/env bash

set -e

export GITHUB_TOKEN=${github_token}

pushd ${head_repo}
  head_commit=$(git rev-parse origin/${head_branch})
popd

cd ${base_repo}
git fetch origin ${base_branch}:refs/remotes/origin/${base_branch}
git checkout ${base_branch}
no_new_commits_available=$(git cat-file -e ${head_commit} ; echo $?)
pull_request=$(hub issue | grep "${pr_message}") || no_pull_request=$?
if [[ "${no_new_commits_available}" -eq "0" ]]; then
  echo "No new commits available"
else
  if [ -v no_pull_request ]; then
    echo "Creating pull-request"
    hub pull-request -b ${base_branch} -h ${head_owner}:${head_branch} -m "${pr_message}"
  else
    echo "Open pull-request found: ${pull_request}"
  fi
fi
