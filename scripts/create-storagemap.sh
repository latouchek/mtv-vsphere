cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: StorageMap
metadata:
  name: vsan
  namespace: openshift-mtv
spec:
  map:
  - destination:
      accessMode: ReadWriteMany
      storageClass: ocs-storagecluster-ceph-rbd
    source:
      name: vsanDatastore
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
kind: StorageMap
metadata:
  name: vsan
  namespace: openshift-mtv
spec:
  map:
  - destination:
      storageClass: ocs-storagecluster-ceph-rbd
    source:
      id: datastore-1048
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
kind: StorageMap
metadata:
  name: vsan
  namespace: openshift-mtv
spec:
  map:
  - destination:
      storageClass: ocs-storagecluster-ceph-rbd
    source:
      name: vsanDatastore
  provider:
    destination:
      name: host
      namespace: openshift-mtv
    source:
      name: vcenter-lab
      namespace: openshift-mtv
EOF
