apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: my-ip-space
      protocol: arp
      arp-network: ${KUBE_SERVICE_MLB_IP_RANGE}
      cidr:
      - ${KUBE_SERVICE_MLB_IP_RANGE}
---
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metallb-system:controller
rules:
- apiGroups: [\"\"]
  resources: ["services"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: [\"\"]
  resources: ["services/status"]
  verbs: ["update"]
- apiGroups: [\"\"]
  resources: ["events"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metallb-system:speaker
rules:
- apiGroups: [\"\"]
  resources: ["services", "endpoints", "nodes"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: metallb-system
  name: leader-election
rules:
- apiGroups: [\"\"]
  resources: ["endpoints"]
  resourceNames: ["metallb-speaker"]
  verbs: ["get", "update"]
- apiGroups: [\"\"]
  resources: ["endpoints"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: metallb-system
  name: config-watcher
rules:
- apiGroups: [\"\"]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [\"\"]
  resources: ["events"]
  verbs: ["create"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: metallb-system
  name: controller
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: metallb-system
  name: speaker
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metallb-system:controller
subjects:
- kind: ServiceAccount
  namespace: metallb-system
  name: controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metallb-system:controller
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metallb-system:speaker
subjects:
- kind: ServiceAccount
  namespace: metallb-system
  name: speaker
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metallb-system:speaker
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: metallb-system
  name: config-watcher
subjects:
- kind: ServiceAccount
  name: controller
- kind: ServiceAccount
  name: speaker
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: config-watcher
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: metallb-system
  name: leader-election
subjects:
- kind: ServiceAccount
  name: speaker
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: leader-election
---
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  namespace: metallb-system
  name: controller
  labels:
    app: metallb
    component: controller
  annotations:
    prometheus.io/scrape: \"true\"
    prometheus.io/port: \"7472\"
spec:
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: metallb
      component: controller
  template:
    metadata:
      labels:
        app: metallb
        component: controller
    spec:
      serviceAccountName: controller
      terminationGracePeriodSeconds: 0
      containers:
      - name: controller
        image: metallb/controller:v0.4.3
        imagePullPolicy: IfNotPresent
        args:
        - --port=7472
        ports:
        - name: monitoring
          containerPort: 7472
        resources:
          limits:
            cpu: 100m
            memory: 100Mi

        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - all
          readOnlyRootFilesystem: true
---
apiVersion: apps/v1beta2
kind: DaemonSet
metadata:
  namespace: metallb-system
  name: speaker
  labels:
    app: metallb
    component: speaker
spec:
  selector:
    matchLabels:
      app: metallb
      component: speaker
  template:
    metadata:
      labels:
        app: metallb
        component: speaker
      annotations:
        prometheus.io/scrape: \"true\"
        prometheus.io/port: \"7472\"
    spec:
      serviceAccountName: speaker
      terminationGracePeriodSeconds: 0
      hostNetwork: true
      containers:
      - name: speaker
        image: metallb/speaker:v0.4.3
        imagePullPolicy: IfNotPresent
        args:
        - --port=7472
        env:
        - name: METALLB_NODE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: METALLB_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        ports:
        - name: monitoring
          containerPort: 7472
        resources:
          limits:
            cpu: 100m
            memory: 100Mi

        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - all
            add:
            - net_raw

