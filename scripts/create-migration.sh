cat << EOF | oc apply -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: Migration
metadata:
  name: migration-test
  namespace: openshift-mtv
spec:
  plan:
    name: test
    namespace: openshift-mtv
EOF
