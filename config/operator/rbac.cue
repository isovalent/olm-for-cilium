// Copyright 2017-2020 Authors of Cilium
// SPDX-License-Identifier: Apache-2.0

package operator

_leaderElectionRules: [
	{
		apiGroups: [
			"",
		]
		resources: [
			"configmaps",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"patch",
			"delete",
		]
	},
	// {
	//         apiGroups: [
	//                 "",
	//         ]
	//         resources: [
	//                 "configmaps/status",
	//         ]
	//         verbs: [
	//                 "get",
	//                 "update",
	//                 "patch",
	//         ]
	// },
	{
		apiGroups: [
			"",
		]
		resources: [
			"events",
		]
		verbs: [
			"create",
		]
	},
]

_helmOperatorClusterRules: [
	{
		// Operator is deployed with `hostNetwork: true`, so it needs to use the
		// hostnetwork SCC
		apiGroups: [
			"security.openshift.io",
		]
		resources: [
			"securitycontextconstraints",
		]
		resourceNames: [
			"hostnetwork",
		]
		verbs: [
			"use",
		]
	},
	{
		// Operator needs to manage cilium RBAC resources
		apiGroups: [
			"rbac.authorization.k8s.io",
		]
		resources: [
			"roles",
			"rolebindings",
			"clusterroles",
			"clusterrolebindings",
		]
		verbs: [
			"create",
			"get",
			"patch",
			"update",
			"delete",
			"list",
			"watch",
		]
		// resourceNames: [
		//  "cilium",
		//  "cilium-operator",
		//  "hubble-relay",
		//  "hubble-ui",
		// ]
	},
	{
		// Write access to services/status (needed for BGP as of Cilium 1.10.0)
		apiGroups: [
			"",
		]
		resources: [
			"services/status",
		]
		verbs: [
			"patch",
			"update",
		]
	},
]

_ciliumClusterRules: [
	// These rules are required for the operator to install Cilium itself,
	// yet the operator will not act on any of these resources, for clarity
	// it helps to define these rules seperately and make them part of a
	// dedicated role.
	// These are a little broad and only specify groups that Cilium needs
	// access to in order to allow for variance between different versions
	// of Cilium. Overall, the purpose is to allow full access to just
	// any API, like CR or workloads that Cilium doesn't have anything to
	// do with. It does need access to pods, but podSpec is read-only, so
	// it wouldn't ever overwrite it.
	{
		// Full access to all cilium.io CRs
		apiGroups: [
			"cilium.io",
		]
		resources: [
			"*",
		]
		verbs: [
			"*",
		]
	},
	{
		apiGroups: [
			"apiextensions.k8s.io",
		]
		resources: [
			"customresourcedefinitions",
		]
		verbs: [
			"*",
		]
	},
	{
		apiGroups: [
			"coordination.k8s.io",
		]
		resources: [
			"leases",
		]
		verbs: [
			"create",
			"get",
			"update",
			"list",
			"delete",
		]
	},
	{
		// Write access to services/status (needed for BGP as of Cilium 1.10.0)
		apiGroups: [
			"",
		]
		resources: [
			"services/status",
		]
		verbs: [
			"patch",
			"update",
		]
	},
	{
		// Read-write access to pods as Cilium sets ownerRerfernces on pods
		apiGroups: [
			"",
		]
		resources: [
			"pods",
			"pods/status",
			"pods/finalizers",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
			"delete",
		]
	},
	{
		// Read-write access to nodes without deletion
		apiGroups: [
			"",
		]
		resources: [
			"nodes",
			"nodes/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
			"patch",
		]
	},
	{
		// Read-only access to namespaces, services, endpoints and componentstatuses
		apiGroups: [
			"",
		]
		resources: [
			"namespaces",
			"services",
			"endpoints",
			"componentstatuses",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	},
	{
		// Read-only access to endpointslices
		apiGroups: [
			"discovery.k8s.io",
		]
		resources: [
			"endpointslices",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	},
	{
		// Read-only access to networkpolicies
		apiGroups: [
			"networking.k8s.io",
		]
		resources: [
			"networkpolicies",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	},
]

_helmOperatorRules: [
	{
		// Operator needs to get own namespace to check that it actually exists
		apiGroups: [
			"",
		]
		resources: [
			"namespaces",
		]
		verbs: [
			"get",
		]
	},
	{
		// Operator needs to list all ciliumconfig
		apiGroups: [
			"cilium.io",
		]
		resources: [
			"ciliumconfigs",
			"ciliumconfigs/status",
		]
		verbs: [
			"list",
		]
	},
	{
		// Operator needs to manage ciliumconfig
		apiGroups: [
			"cilium.io",
		]
		resources: [
			"ciliumconfigs",
			"ciliumconfigs/status",
			"ciliumconfigs/finalizers",
		]
		verbs: [
			"get",
			"patch",
			"update",
			"watch",
			"list",
			"delete",
		]
		// resourceNames: [
		//  "cilium",
		// ]
	},
	{
		// Operator needs to create events on ciliumconfig about things happening during reconciliation
		apiGroups: [
			"",
		]
		resources: [
			"events",
		]
		verbs: [
			"create",
		]
	},
	{
		// Operator needs to manage Helm release secrets
		apiGroups: [
			"",
		]
		resources: [
			"secrets",
		]
		verbs: [
			"*",
		]
	},
	{
		// Cilium installation comprises of these resources
		apiGroups: [
			"",
		]
		resources: [
			"serviceaccounts",
			"configmaps",
			"secrets",
			"services",
		]
		verbs: [
			"*",
		]
	},
	{
		// Cilium installation comprises of these resources
		apiGroups: [
			"apps",
		]
		resources: [
			"deployments",
			"daemonsets",
		]
		verbs: [
			"*",
		]
	},
	{
		// Operator needs to manage servicemonitors if prometheus is enabled
		apiGroups: [
			"monitoring.coreos.com",
		]
		resources: [
			"servicemonitors",
		]
		verbs: [
			"*",
		]
	},
]

_commonSubjects: [{
	kind:      "ServiceAccount"
	name:      constants.name
	namespace: parameters.namespace
}]

_roles: [
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			name:      "\(constants.name)-leader-election"
			namespace: parameters.namespace
		}
		rules: _leaderElectionRules
	},
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			name:      constants.name
			namespace: parameters.namespace
		}
		rules: _helmOperatorRules
	},
]

_roleBindings: [
	{
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      "leader-election"
			namespace: parameters.namespace
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "Role"
			name:     "leader-election"
		}
		subjects: _commonSubjects
	},
	{
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name:      constants.name
			namespace: parameters.namespace
		}
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "Role"
			name:     constants.name
		}
		subjects: _commonSubjects
	},
]

_clusterRoles: [
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "\(parameters.namespace)-\(constants.name)"
		rules: _helmOperatorClusterRules
	},
	{

		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: "\(parameters.namespace)-cilium"
		rules: _ciliumClusterRules
	},
]

_clusterRoleBindings: [
	{
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: name: "\(parameters.namespace)-\(constants.name)"
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "\(parameters.namespace)-\(constants.name)"
		}
		subjects: _commonSubjects
	},
	{
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: name: "\(parameters.namespace)-cilium"
		roleRef: {
			apiGroup: "rbac.authorization.k8s.io"
			kind:     "ClusterRole"
			name:     "\(parameters.namespace)-cilium"
		}
		subjects: _commonSubjects
	},
]
