// Copyright 2017-2021 Authors of Cilium
// SPDX-License-Identifier: Apache-2.0

package operator

constants: {
	name: "cilium-olm"
}

_commonMetadata: {
	name: constants.name
	labels: name: constants.name
	namespace: parameters.namespace
}

_workload: {
	metadata: _commonMetadata
	spec:     _workloadSpec
}

_related_images_env_vars: [{
		name: "RELATED_IMAGE_CILIUM"
		value: parameters.ciliumImage
	},
	{
		name: "RELATED_IMAGE_HUBBLE_RELAY"
		value: parameters.hubbleRelayImage
	},
	{
		name: "RELATED_IMAGE_CILIUM_OPERATOR"
		value: parameters.operatorImage
	},
	{
		name: "RELATED_IMAGE_PREFLIGHT"
		value: parameters.preflightImage
	},
	{
		name: "RELATED_IMAGE_CLUSTERMESH"
		value: parameters.clustermeshImage
	},
	{
		name: "RELATED_IMAGE_CERTGEN"
		value: parameters.certgenImage
	},
	{
		name: "RELATED_IMAGE_HUBBLE_UI_BE"
		value: parameters.hubbleUIBackendImage
	},
	{
		name: "RELATED_IMAGE_HUBBLE_UI_FE"
		value: parameters.hubbleUIFrontendImage
	},
	{
		name: "RELATED_IMAGE_ETCD_OPERATOR"
		value: parameters.etcdOperatorImage
	},
	{
		name: "RELATED_IMAGE_NODEINIT"
		value: parameters.nodeInitImage
	}]

_extra_related_images_env_vars: [
	if parameters.clustermeshEtcdImage != "nothing" {
		{
			name: "RELATED_IMAGE_CLUSTERMESH_ETCD"
			value: parameters.clustermeshEtcdImage
		},
	},
]

_workloadSpec: {
	template: {
		metadata: labels: _commonMetadata.labels
		spec: {
			hostNetwork: true
			tolerations: [{operator: "Exists"}]
			serviceAccount: constants.name
			volumes: [{
				name: "tmp"
				emptyDir: {}
			}]
			containers: [{
				name:    "operator"
				command: _command
				image:   parameters.image
				ports: [{
					containerPort: 9443
					name:          "https"
					protocol:      "TCP"
				}]
				env: [{
					name: "WATCH_NAMESPACE"
					valueFrom: fieldRef: fieldPath: "metadata.namespace"
				}] + _related_images_env_vars + _extra_related_images_env_vars
				volumeMounts: [{
					name:      "tmp"
					mountPath: "/tmp"
				}]
				resources: {
					requests: {
						cpu:    "100m"
						memory: "512Mi"
					}
				}
			}]
			terminationGracePeriodSeconds: 10
		}
	}
}

_command: [...string]

if !parameters.test {
	_workload: {
		apiVersion: "apps/v1"
		kind:       "Deployment"
	}
	_workloadSpec: {
		replicas: 1
		selector: matchLabels: _commonMetadata.labels
		template: {
			metadata: labels: _commonMetadata.labels
		}
	}
	_command: [
		"/usr/local/bin/helm-operator",
		"run",
		"--watches-file=watches.yaml",
		"--enable-leader-election",
		"--leader-election-id=\(constants.name)",
		"--zap-devel",
		"--metrics-addr=localhost:8082",
		"--health-probe-bind-address=localhost:8081",
	]
}

if parameters.test {
	_workload: {
		apiVersion: "batch/v1"
		kind:       "Job"
	}

	_workloadSpec: {
		backoffLimit: 0
		template: spec: restartPolicy: "Never"
	}
	_command: [
		"test.\(constants.name)-controllers",
		"-test.v",
		"-test.timeout=25m", // this must be kept greater then the sum of all polling timeouts
	]
}

_serviceAccount: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata:   _commonMetadata
}

_serviceSelector: {
	if !parameters.test {
		name: constants.name
	}
	if parameters.test {
		"job-name": constants.name
	}
}

_service: {
	apiVersion: "v1"
	kind:       "Service"
	metadata:   _commonMetadata
	spec: {
		selector: _serviceSelector
		ports: [{
			name:       "https"
			port:       443
			targetPort: 9443
		}]
	}
}

_rbac_ClusterRoleBinding: {
	apiVersion: "rbac.authorization.k8s.io/v1beta1"
	kind:       "ClusterRoleBinding"
	metadata: {
		name:   "\(parameters.namespace)-\(constants.name)"
		labels: _commonMetadata.labels
	}
	roleRef: {
		kind:     "ClusterRole"
		name:     constants.name
		apiGroup: "rbac.authorization.k8s.io"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      constants.name
		namespace: parameters.namespace
	}]
}

namespace: [...{}]

if parameters.namespace != "kube-system" {
	namespace: [{
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			name: parameters.namespace
			annotations: {
				// node selector is required to make cilium-operator run on control plane nodes
				"openshift.io/node-selector": ""
			}
			labels: {
				name: parameters.namespace
				// run level sets priority for Cilium to be deployed prior to other components
				"openshift.io/run-level": "0"
				// enable cluster logging for Cilium namespace
				"openshift.io/cluster-logging": "true"
				// enable cluster monitoring for Cilium namespace
				"openshift.io/cluster-monitoring": "true"
			}
		}
	}]
}
_rbac_items: _roles + _roleBindings + _clusterRoles + _clusterRoleBindings

_core_items: namespace + [
		_serviceAccount,
		_workload,
		_service,
] + _rbac_items + _olm_items

#WorkloadTemplate: {
	kind:       "List"
	apiVersion: "v1"
	items:      _core_items
}

#WorkloadParameters: {
	replaces:              string
	image:                 string
	test:                  bool
	ciliumVersion:         string
	ciliumMajorMinor:      string
	onlyCSV:               bool
	namespace:             string | *"cilium"
	configVersionSuffix:   string
        ciliumImage:           string | *""
        hubbleRelayImage:      string | *""
        operatorImage:         string | *""
        preflightImage:        string | *""
        clustermeshImage:      string | *""
        certgenImage:          string | *""
        hubbleUIBackendImage:  string | *""
        hubbleUIFrontendImage: string | *""
        etcdOperatorImage:     string | *""
        nodeInitImage:         string | *""
        clustermeshEtcdImage:  string | *""
}

parameters: #WorkloadParameters

template: {}

if parameters.onlyCSV {
	template: #CSVWorkloadTemplate
}

if !parameters.onlyCSV {
	template: #WorkloadTemplate
}
