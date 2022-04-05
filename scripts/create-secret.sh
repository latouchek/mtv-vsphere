SSHBASE64=$(cat .ssh/id_ed25519 |base64 -w0)
cat << EOF | oc create -f -
apiVersion: v1
data:
  key: $SSHBASE64
kind: Secret
metadata:
  name: ssh-credentials
  namespace: openshift-mtv
type: Opaque
EOF
