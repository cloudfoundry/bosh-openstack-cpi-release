#!/usr/bin/env bash

set -euxo pipefail

export GITHUB_TOKEN="${bosh_openstack_cpi_release_github_token}"
export SSH_KEY="ssh.key"
echo "${bosh_openstack_cpi_release_github_key}" > "${SSH_KEY}"
eval $(ssh-agent)
chmod go-r ${SSH_KEY}
ssh-add ${SSH_KEY}

mkdir -p ~/.ssh
ssh-keyscan github.com > ~/.ssh/known_hosts

cd "${pr_type}-src-out"
echo "Check if latest auto-update commit has already been merged to master"
git fetch origin master:refs/remotes/origin/master
git checkout -b master origin/master

master_contains_auto_update=$(git branch master --contains $(git rev-parse origin/"${pr_type}"-auto-update))
pull_request=$(hub issue | grep "Bump ${pr_type}") || no_pull_request=$?

if [ -z "${master_contains_auto_update}" ]; then
  if [ -v no_pull_request ]; then
    echo "Creating pull-request"
    git checkout "${pr_type}-auto-update"
    hub pull-request -b master -h "${pr_type}-auto-update" -m "Bump ${pr_type}"
  else
    echo "Open pull-request found: ${pull_request}"
  fi
else
  echo "No new commits available"
fi
