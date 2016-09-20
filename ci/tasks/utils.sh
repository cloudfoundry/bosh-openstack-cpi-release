#!/usr/bin/env bash

ensure_not_replace_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

optional_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "unsetting optional environment variable $name"
    unset $name
  fi
}

prepare_bosh_release() {
    if [ ! -z ${s3_compiled_bosh_release_access_key} ] && [ ! -z ${s3_compiled_bosh_release_secret_key} ];then
        configure_s3cmd

        local s3_path_to_bosh_release=$(find_bosh_compiled_release ${old_bosh_release_version} ${old_bosh_stemcell_version})

        if [ ! -z ${s3_path_to_bosh_release} ];then
            s3cmd get ${s3_path_to_bosh_release} ${deployment_dir}/bosh-release.tgz
            echo "Using compiled BOSH release: $s3_path_to_bosh_release"
        else
            use_compiled_release=false
        fi
    else
       use_compiled_release=false
    fi

    if [ ${use_compiled_release} = false ];then
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
    local bosh_release_version=${1:-`cat ./bosh-release/version`}
    local stemcell_version=${2:-`cat ./stemcell/version`}

    local s3_path_to_bosh_release=`s3cmd ls s3://bosh-compiled-release-tarballs | sort -r | grep -oE "s3:\/\/.+$bosh_release_version.+ubuntu.+$stemcell_version.+\.tgz" | head -1`
    echo ${s3_path_to_bosh_release}
}

configure_s3cmd() {
    cat > /root/.s3cfg <<EOF
[default]
access_key = ${s3_compiled_bosh_release_access_key}
access_token =
add_encoding_exts =
add_headers =
bucket_location = US
ca_certs_file =
cache_file =
check_ssl_certificate = True
check_ssl_hostname = True
cloudfront_host = cloudfront.amazonaws.com
default_mime_type = binary/octet-stream
delay_updates = False
delete_after = False
delete_after_fetch = False
delete_removed = False
dry_run = False
enable_multipart = True
encoding = UTF-8
encrypt = False
expiry_date =
expiry_days =
expiry_prefix =
follow_symlinks = False
force = False
get_continue = False
gpg_command = None
gpg_decrypt = %(gpg_command)s -d --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_encrypt = %(gpg_command)s -c --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
gpg_passphrase =
guess_mime_type = True
host_base = s3.amazonaws.com
host_bucket = %(bucket)s.s3.amazonaws.com
human_readable_sizes = False
invalidate_default_index_on_cf = False
invalidate_default_index_root_on_cf = True
invalidate_on_cf = False
kms_key =
limitrate = 0
list_md5 = False
log_target_prefix =
long_listing = False
max_delete = -1
mime_type =
multipart_chunk_size_mb = 15
multipart_max_chunks = 10000
preserve_attrs = True
progress_meter = True
proxy_host =
proxy_port = 0
put_continue = False
recursive = False
recv_chunk = 65536
reduced_redundancy = False
requester_pays = False
restore_days = 1
secret_key = ${s3_compiled_bosh_release_secret_key}
send_chunk = 65536
server_side_encryption = False
signature_v2 = False
simpledb_host = sdb.amazonaws.com
skip_existing = False
socket_timeout = 300
stats = False
stop_on_error = False
storage_class =
urlencoding_mode = normal
use_https = True
use_mime_magic = True
verbosity = WARNING
website_endpoint = http://%(bucket)s.s3-website-%(location)s.amazonaws.com/
website_error =
website_index = index.html
EOF
}
