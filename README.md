# Migrating  VMs from Vsphere to OpenShift CNV with Migration Toolkit for Virtualization (MTV)

## Introduction

This post will walk you through  VM migration  from Vsphere to Openshift Virtualisation (Kubevirt) by using  Migration Toolkit for Virtualization (MTV). It gatherered everything I could find on the subject during an engagment for a customer of mine.

MTV is **Red Hat**'s supported version of upstream project **Forklift** and migrates virtualized workloads from different sources to Kubernetes using KubeVirt. It is designed to make the task simple so that you can migrate anything from one or two machines to hundreds of them.
Migration is a simple, three-stage process:

- Connect to an existing virtualization platform (known as a "source provider") and to a Kubernetes environment (a "target provider").
  
- Map network and storage resources from the source provider to the target provider, looking for equivalent resources in both.

- Select virtual machines to migrate and assign the network and storage mappings to formulate a migration plan. Then run it.

## Prerequisites

- OCP 4.9+
- An internal OpenShift image registry or a secure external registry
- Vsphere API accesible form the OCP cluster
  
## Part I

## CNV (Kubevirt) installation and configuration

In this part we are going to setup OCP so Kubevirt VMs can be plugged into multiple Networks.

- Install the CNV (Kubevirt) Operator

  ```bash
  cat << EOF | oc create -f -
  apiVersion: v1
  kind: Namespace
  metadata:
    name: openshift-cnv
  ---
  apiVersion: operators.coreos.com/v1
  kind: OperatorGroup
  metadata:
    name: kubevirt-hyperconverged-group
    namespace: openshift-cnv
  spec:
    targetNamespaces:
      - openshift-cnv
  ---
  apiVersion: operators.coreos.com/v1alpha1
  kind: Subscription
  metadata:
    name: hco-operatorhub
    namespace: openshift-cnv
  spec:
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    name: kubevirt-hyperconverged
    startingCSV: kubevirt-hyperconverged-operator.v4.9.3
    channel: "stable"
  EOF

  ```

- Check installation

  ```bash
  [root@registry ~] oc get csv -n openshift-cnv
  NAME                                      DISPLAY                    VERSION   REPLACES                                  PHASE
  kubevirt-hyperconverged-operator.v4.9.3   OpenShift Virtualization   4.9.3     kubevirt-hyperconverged-operator.v4.9.2   Succeeded
  ```

- Create hyperconverged object to instantiate the operator

  ```bash

  cat << EOF | oc create -f -
  apiVersion: hco.kubevirt.io/v1beta1
  kind: HyperConverged
  metadata:
    name: kubevirt-hyperconverged
    namespace: openshift-cnv
  EOF

  ```

- Setup bridge interface on Worker Nodes

  In this scenario, Kubevirt VMs will be attached to multiple Vlans. This is achieved by creating a linux bridge and a Network attachment.

  A Network attachment definition is a custom resource that exposes layer-2 devices to a specific namespace in your OpenShift Virtualization cluster.

  ```bash  

  cat << EOF | oc create -f -
  apiVersion: nmstate.io/v1beta1
  kind: NodeNetworkConfigurationPolicy
  metadata:
    name: br1-ens224-policy-workers
  spec:
    nodeSelector:
      node-role.kubernetes.io/worker: ""
    desiredState:
      interfaces:
        - name: linux-br1
          description: Linux bridge with ens224 as a port
          type: linux-bridge
          state: up
          ipv4:
            enabled: false
          bridge:
            options:
              stp:
                enabled: false
            port:
              - name: ens224
  EOF
  ```

- Setup Network Attachment using previously created bridge
  
  ```bash
    cat << EOF | oc apply -f -
    apiVersion: "k8s.cni.cncf.io/v1"
    kind: NetworkAttachmentDefinition
    metadata:
      name: network-attachment-vlan1
      annotations:
        k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/linux-br1
    spec:
      config: '{
        "cniVersion": "0.3.1",
        "name": "network-attachment-vlan1",
        "plugins": [
          {
            "type": "cnv-bridge",
            "bridge": "linux-br1"
          },
          {
            "type": "tuning"
          }
        ]
      }'
    EOF
  ```

- Set a trunk bridge on workers

  In the same manner a trunk bridge can be configured so we can then create multiple vlan network attachment to connect VMs or/and Pods

  ```bash
  cat << EOF | oc create -f -
  apiVersion: nmstate.io/v1beta1
  kind: NodeNetworkConfigurationPolicy
  metadata:
    name: br0-ens2f0np0-policy-workers
  spec:
    nodeSelector:
      node-role.kubernetes.io/worker: ""
    desiredState:
      interfaces:
        - name: linux-br0
          description: Linux bridge with ens2f0np0 as a port
          type: linux-bridge
          state: up
          ipv4:
            enabled: false
          ipv6:
            enabled: false
          bridge:
            options:
              stp:
                enabled: false
            port:
            - name: ens2f0np0
              vlan:
                enable-native: false
                mode: trunk
  EOF
  ```

- Vlan Network attachment
  
  In this example we create a network attachment so VMs can connect to Vlan 113

  ```bash
  cat << EOF | oc create -f -
  apiVersion: "k8s.cni.cncf.io/v1"
  kind: NetworkAttachmentDefinition
  metadata:
    name: net-vlan113
    annotations:
      k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/linux-br0
  spec:
    config: '{
      "cniVersion": "0.3.1",
      "name": "net-vlan113", 
      "type": "cnv-bridge", 
      "bridge": "linux-br0",
      "vlan": 113 
    }'
  EOF
  ```

## Part II

## **MTV (Forklift) installation and configuration**

- Install the MTV Operator

  ```bash
  cat << EOF | oc apply -f -
  apiVersion: project.openshift.io/v1
  kind: Project
  metadata:
    name: openshift-mtv

  ----
  apiVersion: operators.coreos.com/v1
  kind: OperatorGroup
  metadata:
    name: migration
    namespace: openshift-mtv
  spec:
    targetNamespaces:
      - openshift-mtv

  ---
  apiVersion: operators.coreos.com/v1alpha1
  kind: Subscription
  metadata:
    name: mtv-operator
    namespace: openshift-mtv
  spec:
    channel: release-v2.2.0
    installPlanApproval: Automatic
    name: mtv-operator
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    startingCSV: "mtv-operator.2.2.0"
  ```

- Check Operator is ready

  ```bash
  [root@registry AI-Vsphere]oc get csv -n openshift-mtv
  NAME                  DISPLAY                                         VERSION   REPLACES   PHASE
  mtv-operator.v2.2.0   Migration Toolkit for Virtualization Operator   2.2.0                Succeeded
  ```

- Instantiate by creating ForkliftController CR

  ```bash
  cat << EOF | oc apply -f -
  apiVersion: forklift.konveyor.io/v1beta1
  kind: ForkliftController
  metadata:
    name: forklift-controller
    namespace: openshift-mtv
  spec:
    olm_managed: true
  EOF
  ```

- Download  VMware VDDK download page <https://code.vmware.com/sdk/vddk>
- Extract the VDDK archive and cd into the extracted folder

  ```bash
  cat > Dockerfile <<EOF
  FROM registry.access.redhat.com/ubi8/ubi-minimal
  COPY vmware-vix-disklib-distrib /vmware-vix-disklib-distrib
  RUN mkdir -p /opt
  ENTRYPOINT ["cp", "-r", "/vmware-vix-disklib-distrib", "/opt"]
  EOF

- Build vddk image and push it to local registry

  **⚠**  Change registry's FQDN to match your environment

  ```bash

  podman build . -t default-route-openshift-image-registry.apps.ocpd.lab.local/default/vddk:latest
  podman push default-route-openshift-image-registry.apps.ocpd.lab.local/default/vddk:latest  --tls-verify=false

  ```

- Edit hyperconverged CR and add vddkInitImage

  ```yaml
  apiVersion: hco.kubevirt.io/v1beta1
  kind: HyperConverged
  metadata:
    name: kubevirt-hyperconverged
    namespace: openshift-cnv
  spec:
    vddkInitImage: default-route-openshift-image-registry.apps.ocpd.lab.local/default/vddk:latest 
  ```

- Create the Vsphere provider

   We must base64 encode Vsphere user, password and thumbprint and create a secret that is going to be used in the **provider** CR

    **⚠**   **Change values to match your environment**

    ```bash
    PASSWD=$(echo 'vspherepassword'|tr -d "\n" |base64 -w0)

    USER=$(echo 'vsphereadminuser'|tr -d "\n"|base64 -w0)

    THUMBPRINT=$(openssl s_client -connect 192.168.8.30:443 < /dev/null 2>/dev/null \ | openssl x509 -fingerprint -noout -in /dev/stdin \ | cut -d '=' -f 2|tr -d "\n"|base64 -w0)
    VCENTERURL='https://192.168.8.30/sdk' 
    ```

  Then we create the secret

    ```bash
    cat << EOF | oc create -f -
    apiVersion: v1
    data:
      password: $PASSWD
      thumbprint: $THUMBPRINT
      user: $USER
    kind: Secret
    metadata:
      name: vcenter-lab
      namespace: openshift-mtv
    type: Opaque
    EOF

    ```

  and the **Vsphere provider**

  ```bash
    cat << EOF | oc create -f -
    apiVersion: forklift.konveyor.io/v1beta1
    kind: Provider
    metadata:
      name: vcenter-lab
      namespace: openshift-mtv
    spec:
      secret:
        name: vcenter-lab
        namespace: openshift-mtv
      type: vsphere
      url: $VCENTERURL
    EOF

  ```

- Check results with CLI or GUI

  ```bash
  [root@registry ~] oc get provider
  NAME          TYPE        READY   CONNECTED   INVENTORY   URL                        AGE
  host          openshift   True    True        True                                   2d20h
  vcenter-lab   vsphere     True    True        True        https://192.168.8.30/sdk   3m14s
  ```
  
  A route for MTV GUI is created in the **openshift-mtv** Namespace

    ```bash
  [root@registry AI-Vsphere]# oc get route
  NAME                 HOST/PORT                                              PATH   SERVICES             PORT    TERMINATION          WILDCARD
  forklift-inventory   forklift-inventory-openshift-mtv.apps.ocpd.lab.local          forklift-inventory   <all>   reencrypt/Redirect   None
  virt                 virt-openshift-mtv.apps.ocpd.lab.local                        forklift-ui          <all>   reencrypt/Redirect   None
  ```

  We can now access the GUI
  
  **⚠**  The route will be dirent in your environment

  <https://virt-openshift-mtv.apps.ocpd.lab.local/providers/vsphere>
  
  ![image info](./pictures/mtvgui-provider-vsphere.png)

- Create Mapping

  We need to map network and storage resources from the source provider to the target provider, looking for equivalent resources in both

  - Create Storage mapping

    ```bash

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
    ```

  - Create a Network mapping

    ```bash
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

  - Observe the results in the GUI

    ![image info](./pictures/storagemapping.png)

    ![image info](./pictures/networkmapping.png)

    or use the CLI:

    ```bash
    [root@registry ~] oc describe storagemaps.forklift.konveyor.io vsan 
    Name:         vsan
    Namespace:    openshift-mtv
    Labels:       <none>
    Annotations:  forklift.konveyor.io/shared: true
    API Version:  forklift.konveyor.io/v1beta1
    Kind:         StorageMap
    Metadata:
      UID:               d2174ae9-2b3c-402c-be94-fa83a4a0c814
      .....

    ```

    ```bash
    Spec:
      Map:
        Destination:
          Storage Class:  ocs-storagecluster-ceph-rbd
        Source:
          Id:  datastore-1048
    ```

    We can see that the datastore **Name** has been replaced by its **Id**. The same thing can be observed with Network Mapping

    ```bash
    Spec:
      Map:
        Destination:
          Name:       vlan1
          Namespace:  default
          Type:       multus
        Source:
          Id:  network-1051
      Provider:
        Destination:
          Name:       host
          Namespace:  openshift-mtv
        Source:
          Name:       vcenter-lab
          Namespace:  openshift-mtv
    Status:
      Conditions:
        Category:              Required
        Last Transition Time:  2022-03-23T21:55:04Z
        Message:               The network map is ready.
    ```

## **Part III**

## Create an MTV/Forklift Plan

 A migration plan describe how one or more VMs will be migrated. It specifies what mapping and providers are to be used and what VMs are to be migrated. It leverages on the objects we previously created

- A simple plan
  
  Prepare and observe the **migration plan** CR structure.

  - The map block specifies what mapping to use for storage and network. We use the name of the mapping created previously

    ```yaml

    apiVersion: forklift.konveyor.io/v1beta1
    kind: Plan                             
    metadata:
      name: test
      namespace: openshift-mtv
    spec:
      archived: false
      description: ""
      map:
        network:
          name: vlan1  ##### Name of the network mapping we previously created ###
          namespace: openshift-mtv
        storage:
          name: vsan 
          namespace: openshift-mtv
    ```

  - The Provider block indicates the source provider of our VM **vcenter-lab** and its destination **host** as well as the namespace where you want your Kubevirt VM to run. That is **vcenter-lab**, **host** and  **default** in this case

    ```yaml
      provider:
        destination:
          name: host   
          namespace: openshift-mtv
        source:
          name: vcenter-lab    #####your source provider goes here ###
          namespace: openshift-mtv
      targetNamespace: default   ####The namespace you want your VM to run in ####
    ```

  - The **vms** block allows us to specify what vm to migrate

    ```yaml
      vms:
      - hooks: []
        name: centos8    ####Name of the vm to be migrated. Lowercases names only  !!!
      warm: false #### The VM will be stop before migration
    EOF
    ```

- Create the plan

   ```bash
  cat << EOF | oc create -f -
  apiVersion: forklift.konveyor.io/v1beta1
  kind: Plan
  metadata:
    name: test
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
    - hooks: []
      name: centos8
    warm: false
  EOF
  ```

- Check the plan status with the CLI and the GUI
  
  ```bash
  root@registry AI-Vsphere]# oc get plan
  NAME   READY   EXECUTING   SUCCEEDED   FAILED   AGE
  test   True                                     9s
  ```

  ![image info](./pictures/migrationtestsimpleready.png)
- Run the Plan
  
  To run the plan, a **Migration** CR is needed

  ```bash
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

  ```

- Observe the migration happening
  ![image info](./pictures/migrationtestsimpledone.png)

  Plan is starting

  ```bash
  [root@registry AI-Vsphere]oc get plan
  NAME   READY   EXECUTING   SUCCEEDED   FAILED   AGE
  test   True    True                             13m
  ```

  A PVC is created in the  namespace we chose and the migrating VM disk is being copied to it

  ```bash
  root@registry AI-Vsphere]oc get pvc -n default
  NAME                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                  AGE
  test-vm-5058-6glbc   Bound    pvc-f0042e2f-e8ea-48e0-a8d3-dbd9c3159290   6Gi        RWO            ocs-storagecluster-ceph-rbd   105s
  ```

  The VM has been created

  ```bash
  [root@registry AI-Vsphere]oc get vm -n default
  NAME      AGE     STATUS    READY
  centos8   3m51s   Stopped   False
  ```

  Migration completed

  ```bash
  [root@registry AI-Vsphere]# oc get plan
  NAME   READY   EXECUTING   SUCCEEDED   FAILED   AGE
  test   True                True                 16m
  ```

- Check the new VM

  The newly created VM is connected to the desired network and is 1to1 copy of the original
  
  ```bash
  [root@registry AI-Vsphere]oc describe vm centos8 -n default
  Name:         centos8
  Namespace:    default

  .....................Truncated.................
  Spec:
    Running:  true
    Template:
      Metadata:
        Creation Timestamp:  <nil>
      Spec:
        Domain:
          Clock:
            Timer:
            Timezone:  UTC
          Cpu:
            Cores:    1
            Sockets:  1
          Devices:
            Disks:
              Disk:
                Bus:  virtio
              Name:   vol-0
            Inputs:
              Bus:   virtio
              Name:  tablet
              Type:  tablet
            Interfaces:
              Bridge:
              Mac Address:  00:50:56:9c:45:bb 
              Model:        virtio
              Name:         net-0
          Features:
            Acpi:
          Firmware:
            Bootloader:
              Bios:
            Serial:  421c483c-c989-2d26-e036-c36e59faba52
          Machine:
            Type:  q35
          Resources:
            Requests:
              Memory:  1Gi
        Networks:
          Multus:
            Network Name:  default/vlan1  
          Name:            net-0
        Volumes:
          Data Volume:
            Name:  test-vm-5058-6glbc
          Name:    vol-0 
  ```
  
## **Part IV**

Coming soon

### Thank you for reading

## References

- [Forklift Documentation
](https://forklift-docs.konveyor.io/)
- [Installing and using the Migration Toolkit for Virtualization](https://access.redhat.com/documentation/en-us/migration_toolkit_for_virtualization/2.2/html/installing_and_using_the_migration_toolkit_for_virtualization/index)
