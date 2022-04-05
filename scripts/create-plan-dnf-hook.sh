cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: Plan
metadata:
  name: test-dnf
  namespace: openshift-mtv
spec:
  archived: false
  description: ""
  map:
    network:
      name: vlan1
      namespace: openshift-mtv
    storage:
      name: vsan
      namespace: openshift-mtv
  provider:
    destination:
      name: host
      namespace: openshift-mtv
    source:
      name: vcenter-lab
      namespace: openshift-mtv
  targetNamespace: default
  vms:
  - hooks:
    - hook:
        name: dnf-hook
        namespace: openshift-mtv
      step: PreHook
    name: centos8
  warm: false
EOF



