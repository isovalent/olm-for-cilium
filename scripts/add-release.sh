#!/bin/bash

# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 1 ] ; then
  echo "$0 supports exactly 1 argument"
  echo "example: '$0 1.9.1'"
  exit 1
fi

if ! command -v jq &> /dev/null ; then
    echo "\"jq\" must be installed to create an offline \
    deployment."
fi

cilium_version="${1}"

chart_url="https://github.com/cilium/charts/raw/master/cilium-${cilium_version}.tgz"
operator_dir="operator/cilium.v${cilium_version}"
bundle_dir="bundles/cilium.v${cilium_version}"

root_dir="$(git rev-parse --show-toplevel)"

cd "${root_dir}"

if ! mkdir "${operator_dir}" 2> /dev/null ; then
  echo "version ${cilium_version} has already been added"
  echo "if you want to re-add it, you can to run 'rm -rf ${operator_dir}' and edit 'Makefile.releases'"
  exit 3
fi

curl --silent --fail --show-error --location "${chart_url}" --output /tmp/cilium-chart.tgz

tar -xf /tmp/cilium-chart.tgz -C "${operator_dir}"

rm -f /tmp/cilium-chart.tgz

cp LICENSE "${operator_dir}/LICENSE"

cat > "${operator_dir}/watches.yaml" << EOF
# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

- group: cilium.io
  version: v1alpha1
  kind: CiliumConfig
  chart: helm-charts/cilium
  overrideValues:
    image.override: \$RELATED_IMAGE_CILIUM
    hubble.relay.image.override: \$RELATED_IMAGE_HUBBLE_RELAY
    operator.image.override: \$RELATED_IMAGE_CILIUM_OPERATOR
    preflight.image.override: \$RELATED_IMAGE_PREFLIGHT
    clustermesh.apiserver.image.override: \$RELATED_IMAGE_CLUSTERMESH
    certgen.image.override: \$RELATED_IMAGE_CERTGEN
    hubble.ui.backend.image.override: \$RELATED_IMAGE_HUBBLE_UI_BE
    hubble.ui.frontend.image.override: \$RELATED_IMAGE_HUBBLE_UI_FE
    hubble.ui.proxy.image.override: \$RELATED_IMAGE_HUBBLE_UI_PROXY
    etcd.image.override: \$RELATED_IMAGE_ETCD_OPERATOR
    nodeinit.image.override: \$RELATED_IMAGE_NODEINIT
    clustermesh.apiserver.etcd.image.override: \$RELATED_IMAGE_CLUSTERMESH_ETCD
EOF

cat > "${operator_dir}/Dockerfile" << EOF
# Copyright 2017-2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

FROM quay.io/operator-framework/helm-operator:v1.22

# This make the build time-variant, but there is not easy
# way around this yet, as the helm-operator image does
# often have outdatated packages
# (For a potneial solution see https://github.com/errordeveloper/imagine/issues/27)
USER root
RUN microdnf update

# Required Licenses
COPY LICENSE /licenses/LICENSE.cilium-olm

# Required OpenShift Labels
LABEL name="Cilium" \\
      version="v${cilium_version}" \\
      vendor="Isovalent" \\
      release="1" \\
      summary="Cilium OLM operator" \\
      description="This operator mamaged Cilium installation and it is OLM-compliant"

USER helm
ENV HOME=/opt/helm
COPY watches.yaml \${HOME}/watches.yaml
WORKDIR \${HOME}

COPY cilium \${HOME}/helm-charts/cilium
EOF

mkdir -p "${bundle_dir}"

get_append_line () {
    local current="$1" line r releases smallest

    # Get all releases by parsing Makefile.releases
    mapfile releases < <(sed -n 's/^# Cilium v\([0-9.]*\)$/\1/p' Makefile.releases)
    for r in "${releases[@]}"; do
        # Compare release numbers by sorting them and checking whether our new
        # entry is the smallest
        smallest="$(printf "%s\n%s\n" "${current}" "${r}" | sort -V | head -n1)"
        if [[ "${smallest}" == "${current}" ]]; then
            # If we've found a greater version number, we want to insert the
            # new entry just before
            line=$(grep -n "^# Cilium v${r}\$" Makefile.releases | cut -d: -f1)
            # Go back three lines: we want the line above, and then we skip two
            # blank lines
            echo $((line - 3))
            return
        fi
    done
    # If no greater version number was found, append at the end of the file
    wc -l Makefile.releases | cut -d' ' -f1
}

line=$(get_append_line "$cilium_version")
sed -i "${line} a \
\\\n\
\\n\
# Cilium v${cilium_version}\\n\
\\n\
images.all: images.operator.v${cilium_version}\\n\
\\n\
images.operator.all: images.operator.v${cilium_version} generate.configs.v${cilium_version}\\n\
generate.configs.all: generate.configs.v${cilium_version}\\n\
\\n\
images.operator.v${cilium_version} generate.configs.v${cilium_version}: cilium_version=${cilium_version}
" Makefile.releases

template_dir="${operator_dir}/cilium/templates"

if [[ ${cilium_version} == 1.9.* ]]; then
    # certgen
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.certgen.image.override }}"|' "${template_dir}/_clustermesh-apiserver-generate-certs-job-spec.tpl"
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.certgen.image.override }}"|' "${template_dir}/_hubble-generate-certs-job-spec.tpl"

    # cilium
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.image.override }}"|' "${template_dir}/cilium-agent-daemonset.yaml"

    # etcd-operator
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.etcd.image.override }}"|' "${template_dir}/cilium-etcd-operator-deployment.yaml"

    # nodeinit
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.nodeinit.image.override }}"|' "${template_dir}/cilium-nodeinit-daemonset.yaml"

    # operator
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.operator.image.override }}"|' "${template_dir}/cilium-operator-deployment.yaml"

    # preflight
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.preflight.image.override }}"|' "${template_dir}/cilium-preflight-daemonset.yaml"
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.preflight.image.override }}"|' "${template_dir}/cilium-preflight-deployment.yaml"

    # clustermesh
    sed -i 's|^\([[:blank:]]*\)image: {{ \.Values\.clustermesh\.apiserver\.etcd.*$|\1image: "{{ .Values.clustermesh.apiserver.etcd.image.override }}"|' "${template_dir}/clustermesh-apiserver-deployment.yaml"
    sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.clustermesh\.apiserver\.image.*$|\1image: "{{ .Values.clustermesh.apiserver.image.override }}"|' "${template_dir}/clustermesh-apiserver-deployment.yaml"

    # hubble-relay
    sed -i 's|^\([[:blank:]]*\)image:.*$|\1image: "{{ .Values.hubble.relay.image.override }}"|' "${template_dir}/hubble-relay-deployment.yaml"

    # hubble-ui
    sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.frontend.*$|\1image: "{{ .Values.hubble.ui.frontend.image.override }}"|' "${template_dir}/hubble-ui-deployment.yaml"
    sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.backend.*$|\1image: "{{ .Values.hubble.ui.backend.image.override }}"|' "${template_dir}/hubble-ui-deployment.yaml"
    sed -i 's|^\([[:blank:]]*\)image: "{{ \.Values\.hubble\.ui\.proxy.*$|\1image: "{{ .Values.hubble.ui.proxy.image.override }}"|' "${template_dir}/hubble-ui-deployment.yaml"
fi

git add Makefile.releases "${operator_dir}" "${bundle_dir}"

git commit --message "Add Cilium v${cilium_version}"

make "images.operator.v${cilium_version}" WITHOUT_TAG_SUFFIX=true
make "generate.configs.v${cilium_version}" WITHOUT_TAG_SUFFIX=true

git add "manifests/cilium.v${cilium_version}" "${bundle_dir}"

git commit --amend --all --message "Add Cilium v${cilium_version}"
