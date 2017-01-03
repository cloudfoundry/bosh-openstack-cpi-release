#!/usr/bin/env bash

optional_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
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
    export OS_VOLUME_API_VERSION=1
    export OS_DOMAIN_NAME=$BOSH_OPENSTACK_DOMAIN_NAME
    export OS_IDENTITY_API_VERSION=3

    if [ -n "$BOSH_OPENSTACK_CA_CERT" ]; then
      tmpdir=$(mktemp -dt "$(basename $0).XXXXXXXXXX")
      cacert="$tmpdir/cacert.pem"
      echo "Writing cacert.pem to $cacert"
      echo "$BOSH_OPENSTACK_CA_CERT" > $cacert
      export OS_CACERT=$cacert
    fi

}

prepare_bosh_release() {
    use_compiled_release=true

    local s3_path_to_bosh_release=$(find_bosh_compiled_release ${distro} ${old_bosh_release_version} ${old_bosh_stemcell_version})

    if [ ! -z ${s3_path_to_bosh_release} ];then
        echo "Using compiled BOSH release: s3://bosh-compiled-release-tarballs/$s3_path_to_bosh_release"
        aws --no-sign-request s3 cp s3://bosh-compiled-release-tarballs/${s3_path_to_bosh_release} ${deployment_dir}/bosh-release.tgz
    else
        use_compiled_release=false
    fi

    if [ "${use_compiled_release}" = "false" ];then
       echo "Using BOSH release from sources"
       if [ -z ${old_bosh_release_version} ];then
        cp ./bosh-release/release.tgz ${deployment_dir}/bosh-release.tgz
       else
         wget https://bosh.io/d/github.com/cloudfoundry/bosh?v=${old_bosh_release_version} -O ${deployment_dir}/bosh-release.tgz
         echo "$old_bosh_release_sha1 $deployment_dir/bosh-release.tgz" | sha1sum -c -
       fi
    fi

}

find_bosh_compiled_release(){
    local distro=$1
    local bosh_release_version=${2:-`cat ./bosh-release/version`}
    local stemcell_version=${3:-`cat ./stemcell/version`}

    local s3_path_to_bosh_release=`aws --no-sign-request s3 ls s3://bosh-compiled-release-tarballs | grep -oE "[^ ](\w|-)*$bosh_release_version.+$distro.+$stemcell_version.*\.tgz" | sort -r | head -1`
    echo ${s3_path_to_bosh_release}
}

export_terraform_variable() {
    local variable_name=$1
    export ${variable_name}=$(cat ${metadata} | jq --raw-output ".${variable_name}")
}

generateCert() {
    ip=$1

    cat >openssl-exts.conf <<-EOL
extensions = san
[san]
subjectAltName = IP:${ip}
EOL

    echo "Generating private key..."
    openssl genrsa -out bosh-ssl.key 2048

    echo "Generating certificate signing request for ${ip}..."
    # golang requires to have SAN for the IP
    openssl req -new -nodes -key bosh-ssl.key -out bosh-ssl.csr -subj "/C=US/O=BOSH/CN=${ip}"

    echo "Generating certificate ${ip}..."
    openssl x509 -req -in bosh-ssl.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out bosh-ssl.crt -days 99999 -extfile ./openssl-exts.conf

    echo "Deleting certificate signing request and config..."
    rm bosh-ssl.csr
    rm ./openssl-exts.conf
}