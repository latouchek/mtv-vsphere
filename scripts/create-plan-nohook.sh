cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: Plan
metadata:
  name: test
  namespace: openshift-mtv
spec:
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
  - hooks: []
    name: centos8
  warm: false
EOF
