
PLAYBOOKBASE64=$(cat playbook/dnf-playbook.yaml|base64 -w0)

cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: Hook
metadata:
  name: dnf-hook
  namespace: openshift-mtv
spec:
  image: quay.io/konveyor/hook-runner:nmcli
  playbook: |
    $PLAYBOOKBASE64
  serviceAccount: forklift-controller
EOF
