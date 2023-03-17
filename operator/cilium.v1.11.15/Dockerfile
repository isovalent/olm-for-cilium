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
LABEL name="Cilium" \
      version="v1.11.15" \
      vendor="Isovalent" \
      release="1" \
      summary="Cilium OLM operator" \
      description="This operator mamaged Cilium installation and it is OLM-compliant"

USER helm
ENV HOME=/opt/helm
COPY watches.yaml ${HOME}/watches.yaml
WORKDIR ${HOME}

COPY cilium ${HOME}/helm-charts/cilium
