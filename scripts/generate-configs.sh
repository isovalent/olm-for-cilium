#!/bin/bash

# Copyright 2017-2020 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset
set -x
shopt -s expand_aliases

alias yq='docker run --rm -v "${PWD}":/workdir --user "$(id -u):$(id -g)" mikefarah/yq:4.27.3'

cilium_version="${2}"

root_dir="$(git rev-parse --show-toplevel)"

case "${cilium_version}" in
  *-rc*)
    operator_image="$(head -1 "${1}")"
    ;;
  *)
    operator_image="registry.connect.redhat.com/isovalent/cilium-olm:$(head -1 "${1}" | cut -d ':' -f 2)"
    ;;
esac

function get_image() {
    local image="$1"
    local tag="$2"
    local manifest
    local hash
    manifest="$(docker manifest inspect "$image:$tag" -v)"
    hash="$(echo "$manifest" | jq -r '.Descriptor.digest' 2>/dev/null || echo "$manifest" | jq -r '.[0].Descriptor.digest' 2> /dev/null || "")"
    if [[ "$hash" ]]; then
        echo "$image""@$hash"
    else
        docker pull "$image:$tag" > /dev/null
        echo "$image""@$(docker inspect "$image:$tag" | jq -r '.[0].RepoDigests[0]' | cut -d'@' -f2)"
    fi
}

cd "${root_dir}"

rm -rf "manifests/cilium.v${cilium_version}" "bundles/cilium.v${cilium_version}/manifests" "bundles/cilium.v${cilium_version}/metadata" "bundles/cilium.v${cilium_version}/tests"

values_file="operator/cilium.v${cilium_version}/cilium/values.yaml"

cilium_image="$(yq e '.image.repository' "$values_file")@$(yq e '.image.digest' "$values_file")"
hubble_relay_image="$(yq e '.hubble.relay.image.repository' "$values_file")@$(yq e '.hubble.relay.image.digest' "$values_file")"
cilium_operator_image="$(yq e '.operator.image.repository' "$values_file")-generic@$(yq e '.operator.image.genericDigest' "$values_file")"
preflight_image="$(yq e '.preflight.image.repository' "$values_file")@$(yq e '.preflight.image.digest' "$values_file")"
clustermesh_image="$(yq e '.clustermesh.apiserver.image.repository' "$values_file")@$(yq e '.clustermesh.apiserver.image.digest' "$values_file")"

# These images don't have their digests in the values file, we need to retrieve them
certgen_image="$(get_image "$(yq e '.certgen.image.repository' "$values_file")" "$(yq e '.certgen.image.tag' "$values_file")")"
hubble_ui_be_image="$(get_image "$(yq e '.hubble.ui.backend.image.repository' "$values_file")" "$(yq e '.hubble.ui.backend.image.tag' "$values_file")")"
hubble_ui_fe_image="$(get_image "$(yq e '.hubble.ui.frontend.image.repository' "$values_file")" "$(yq e '.hubble.ui.frontend.image.tag' "$values_file")")"
etcd_operator_image="$(get_image "$(yq e '.etcd.image.repository' "$values_file")" "$(yq e '.etcd.image.tag' "$values_file")")"
nodeinit_image="$(get_image "$(yq e '.nodeinit.image.repository' "$values_file")" "$(yq e '.nodeinit.image.tag' "$values_file")")"
clustermesh_etcd_image="$(get_image "$(yq e '.clustermesh.apiserver.etcd.image.repository' "$values_file")" "$(yq e '.clustermesh.apiserver.etcd.image.tag' "$values_file")")"

cilium_major_minor="$(echo "${cilium_version}" | cut -d . -f -2)"
# to not make 1.13.0 as previous release cause failure
set +o pipefail
set +o errexit
#shellcheck disable=SC2003
previous_version="${cilium_major_minor}.$(expr "$(echo "${cilium_version}" | cut -d . -f 3)" - 1)"
#shellcheck disable=SC2003
previous_version="${cilium_major_minor}.$(expr "$(echo "${cilium_version}" | cut -d . -f 3)" - 1)"
set -o pipefail
set -o errexit
if [[ -d "bundles/cilium.v${previous_version}" ]]; then
    previous_name="$(yq .metadata.name "bundles/cilium.v${previous_version}/manifests/cilium.clusterserviceversion.yaml")"
fi

generate_instaces_cue() {
cat << EOF
package operator

instances: [
  {
    output: "manifests/cilium.v${cilium_version}/cluster-network-06-cilium-%s.yaml"
    parameters: {
      replaces: "${previous_name:-nothing}"
      image: "${operator_image}"
      test: false
      onlyCSV: false
      ciliumVersion: "${cilium_version}"
      ciliumMajorMinor: "${cilium_major_minor}"
      configVersionSuffix: "${1:-}"
      ciliumVersion: "${cilium_version}"
      ciliumImage: "${cilium_image}"
      hubbleRelayImage: "${hubble_relay_image}"
      operatorImage: "${cilium_operator_image}"
      preflightImage: "${preflight_image}"
      clustermeshImage: "${clustermesh_image}"
      certgenImage: "${certgen_image}"
      hubbleUIBackendImage: "${hubble_ui_be_image}"
      hubbleUIFrontendImage: "${hubble_ui_fe_image}"
      etcdOperatorImage: "${etcd_operator_image}"
      nodeInitImage: "${nodeinit_image}"
      clustermeshEtcdImage: "${clustermesh_etcd_image}"
    }
  },
  {
    output: "bundles/cilium.v${cilium_version}/manifests/cilium.clusterserviceversion.yaml"
    parameters: {
      replaces: "${previous_name:-nothing}"
      namespace: "placeholder"
      image: "${operator_image}"
      test: false
      onlyCSV: true
      ciliumVersion: "${cilium_version}"
      ciliumMajorMinor: "${cilium_major_minor}"
      configVersionSuffix: "${1:-}"
      ciliumImage: "${cilium_image}"
      hubbleRelayImage: "${hubble_relay_image}"
      operatorImage: "${cilium_operator_image}"
      preflightImage: "${preflight_image}"
      clustermeshImage: "${clustermesh_image}"
      certgenImage: "${certgen_image}"
      hubbleUIBackendImage: "${hubble_ui_be_image}"
      hubbleUIFrontendImage: "${hubble_ui_fe_image}"
      etcdOperatorImage: "${etcd_operator_image}"
      nodeInitImage: "${nodeinit_image}"
      clustermeshEtcdImage: "${clustermesh_etcd_image}"
    }
  },
]
EOF
}

combined_hash_sources() {
  generate_instaces_cue
  cat "bundles/cilium.v${cilium_version}/Dockerfile"
  cat "config/operator/operator.cue"
  cat "config/operator/rbac.cue"
  cat "config/operator/olm.cue"
}

config_version_suffix_hash="$(combined_hash_sources | git hash-object --stdin)"

generate_instaces_cue "${config_version_suffix_hash:0:7}" > config/operator/instances.cue

if [ -n "${GOPATH+x}" ] ; then
  export PATH="${PATH}:${GOPATH}/bin"
fi

kuegen -input-directory ./config/operator -output-directory ./

cp ./config/crd/cilium.io_cilumconfigs.yaml "manifests/cilium.v${cilium_version}/cluster-network-03-cilium-ciliumconfigs-crd.yaml"

cilium_minor_version=$(cut -d '.' -f 1,2 <<< "$cilium_version")
ciliumconfig="ciliumconfig.v${cilium_minor_version}.yaml"
if [ ! -f "${ciliumconfig}" ]
then
  echo "ERROR: You need to create ${ciliumconfig} first"
  exit 1
fi

cp "${ciliumconfig}" "manifests/cilium.v${cilium_version}/cluster-network-07-cilium-ciliumconfig.yaml"

cp ./config/crd/cilium.io_cilumconfigs.yaml "bundles/cilium.v${cilium_version}/manifests/cilium.operator.cilium.io.crd.yaml"
mkdir -p "bundles/cilium.v${cilium_version}/metadata"
cat > "bundles/cilium.v${cilium_version}/metadata/annotations.yaml" << EOF
annotations:
  operators.operatorframework.io.bundle.channel.default.v1: "${cilium_major_minor}"
  operators.operatorframework.io.bundle.channels.v1: "${cilium_major_minor}"
  operators.operatorframework.io.bundle.manifests.v1: manifests/
  operators.operatorframework.io.bundle.mediatype.v1: registry+v1
  operators.operatorframework.io.bundle.metadata.v1: metadata/
  operators.operatorframework.io.bundle.package.v1: cilium
  operators.operatorframework.io.metrics.builder: operator-sdk-v1.0.1
  operators.operatorframework.io.metrics.mediatype.v1: metrics+v1
  operators.operatorframework.io.metrics.project_layout: helm.sdk.operatorframework.io/v1
  com.redhat.openshift.versions: "v4.9"
EOF

# We use yq to modify bundle and manifest files as a part of the release process.
# It produces large diffs because these yaml files are indented differently than
# how yq indents them. Run bundle and manifest yaml files through yq here so that
# using yq later on these files doesn't produce unnecessary diffs.
#
# Ref: https://github.com/mikefarah/yq/issues/825
find "bundles/cilium.v${cilium_version}" -name "*.yaml" | while read -r file; do yq e -i "$file"; done
find "manifests/cilium.v${cilium_version}" -name "*.yaml" | while read -r file; do yq e -i "$file"; done
