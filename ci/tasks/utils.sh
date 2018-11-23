#!/usr/bin/env bash

manifest_path() {
  bosh-go int bosh-director-deployment/bosh.yml --path="$1"
}

creds_path() {
  bosh-go int bosh-director-deployment/credentials.yml --path="$1"
}

optional_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ] || [ "$value" == 'null' ]; then
    echo "unsetting optional environment variable $name"
    unset $name
  fi
}

init_openstack_cli_env(){
    : ${BOSH_OPENSTACK_AUTH_URL:?}
    : ${BOSH_OPENSTACK_USERNAME:?}
    : ${BOSH_OPENSTACK_API_KEY:?}
    : ${BOSH_OPENSTACK_PROJECT:?}
    : ${BOSH_OPENSTACK_DOMAIN_NAME:?}
    optional_value BOSH_OPENSTACK_CA_CERT

    export OS_DEFAULT_DOMAIN=$BOSH_OPENSTACK_DOMAIN_NAME
    export OS_AUTH_URL=$BOSH_OPENSTACK_AUTH_URL
    export OS_USERNAME=$BOSH_OPENSTACK_USERNAME
    export OS_PASSWORD=$BOSH_OPENSTACK_API_KEY
    export OS_PROJECT_NAME=$BOSH_OPENSTACK_PROJECT
    export OS_DOMAIN_NAME=$BOSH_OPENSTACK_DOMAIN_NAME
    export OS_IDENTITY_API_VERSION=3
    export OS_INTERFACE=$BOSH_OPENSTACK_INTERFACE

    if [ -n "$BOSH_OPENSTACK_CA_CERT" ]; then
      tmpdir=$(mktemp -dt "$(basename $0).XXXXXXXXXX")
      cacert="$tmpdir/cacert.pem"
      echo "Writing cacert.pem to $cacert"
      echo "$BOSH_OPENSTACK_CA_CERT" > $cacert
      export OS_CACERT=$cacert
    fi

}

prepare_bosh_release() {
    local distribution=${1}
    local bosh_release_version=${2}
    local stemcell_version=${3}

    use_compiled_release=true

    local s3_path_to_bosh_release=$(find_bosh_compiled_release ${distribution} ${bosh_release_version} ${stemcell_version})

    if [ ! -z ${s3_path_to_bosh_release} ];then
        echo "Using compiled BOSH release: s3://bosh-compiled-release-tarballs/$s3_path_to_bosh_release"
        aws --no-sign-request s3 cp s3://bosh-compiled-release-tarballs/${s3_path_to_bosh_release} ${deployment_dir}/bosh-release.tgz
    else
        use_compiled_release=false
    fi

    if [ "${use_compiled_release}" = "false" ];then
       echo "Using BOSH release from sources"
       if [ -z ${bosh_release_version} ];then
        cp ./bosh-release/release.tgz ${deployment_dir}/bosh-release.tgz
       else
         wget https://bosh.io/d/github.com/cloudfoundry/bosh?v=${bosh_release_version} -O ${deployment_dir}/bosh-release.tgz
         echo "$old_bosh_release_sha1 $deployment_dir/bosh-release.tgz" | sha1sum -c -
       fi
    fi
}

find_bosh_compiled_release(){
    local distribution=$1
    local bosh_release_version=${2:-`cat ./bosh-release/version`}
    local stemcell_version=${3:-`cat ./stemcell-director/version`}

    local s3_path_to_bosh_release=`aws --no-sign-request s3 ls s3://bosh-compiled-release-tarballs | grep -oE "[^ ](\w|-)*$bosh_release_version.+$distribution.+$stemcell_version.*\.tgz" | sort -r | head -1`
    echo ${s3_path_to_bosh_release}
}

export_terraform_variable() {
    local variable_name=$1
    local prefix=$2
    export ${prefix}${variable_name}=$(cat ${metadata} | jq -c --raw-output ".${variable_name}")
}
