cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: NetworkMap
metadata:
  name: vlan1
  namespace: openshift-mtv
spec:
  map:
  - destination:
      name: vlan1
      namespace: default
      type: multus
    source:
      name: VM Network
  provider:
    destination:
      name: host
      namespace: openshift-mtv
    source:
      name: vcenter-lab
      namespace: openshift-mtv
EOF




cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: NetworkMap
metadata:
  name: vlan1
  namespace: openshift-mtv
spec:
  map:
  - destination:
      name: network-attachment-vlan1
      namespace: default
      type: multus
    source:
      id: network-1051
  provider:
    destination:
      name: host
      namespace: openshift-mtv
    source:
      name: vcenter-lab
      namespace: openshift-mtv
EOF
