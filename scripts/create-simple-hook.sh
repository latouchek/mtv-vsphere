
PLAYBOOKBASE64=$(cat playbook/simple-playbook.yaml|base64 -w0)

cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: Hook
metadata:
  name: simplehook
  namespace: openshift-mtv
spec:
  image: quay.io/konveyor/hook-runner:nmcli
  playbook: |
    $PLAYBOOKBASE64
  serviceAccount: forklift-controller
EOF


cat << EOF | oc create -f -
apiVersion: forklift.konveyor.io/v1beta1
kind: Hook
metadata:
  name: simplehook
  namespace: openshift-mtv
spec:
  image: quay.io/konveyor/hook-runner:nmcli
  playbook: |
    LS0tCi0gaG9zdHM6IGxvY2FsaG9zdAogIGNvbm5lY3Rpb246IGxvY2FsCiAgdGFza3M6CiAgICAtIG5hbWU6ICJQcmludCBhbGwiCiAgICAgIHNldHVwOgogICAgLSBuYW1lOiBEdW1wCiAgICAgIGRlYnVnOgogICAgICAgIHZhcjogaG9zdHZhcnNbaW52ZW50b3J5X2hvc3RuYW1lXQ==
  serviceAccount: forklift-controller
EOF
