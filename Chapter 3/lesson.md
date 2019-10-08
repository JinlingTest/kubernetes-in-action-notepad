以YAML描述文件创建Pod
Pod和其他K8S资源通常通过向K8S Rest API提供YAML文件来创建
或者直接使用kubectl run

另外使用YAML定义 可以存储在版本控制系统中 充分利用版本控制代来的便利
你需要要了解K8S API对象 以便配置

检查现有pod的yaml 描述文件

[kubeadm@masnode1 ~]$ kubectl get pod kubia-dn9rb -o yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2019-09-30T07:33:54Z"
  generateName: kubia-
  labels:
    run: kubia
  name: kubia-dn9rb
  namespace: default
  ownerReferences:
  - apiVersion: v1
    blockOwnerDeletion: true
    controller: true
    kind: ReplicationController
    name: kubia
    uid: 0c0478c5-a636-4137-a332-2ba1ab917a33
  resourceVersion: "71594"
  selfLink: /api/v1/namespaces/default/pods/kubia-dn9rb
  uid: 7ac0d5df-e572-4f6a-9041-71a710174a9c
spec:
  containers:
  - image: luksa/kubia
    imagePullPolicy: Always
    name: kubia
    ports:
    - containerPort: 8080
      protocol: TCP
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-m9z4j
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  nodeName: wornode3.example.com
  priority: 0
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext: {}
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
  tolerations:
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
  volumes:
  - name: default-token-m9z4j
    secret:
      defaultMode: 420
      secretName: default-token-m9z4j
status:
  conditions:
  - lastProbeTime: null
    lastTransitionTime: "2019-09-30T07:33:54Z"
    status: "True"
    type: Initialized
  - lastProbeTime: null
    lastTransitionTime: "2019-09-30T07:35:37Z"
    status: "True"
    type: Ready
  - lastProbeTime: null
    lastTransitionTime: "2019-09-30T07:35:37Z"
    status: "True"
    type: ContainersReady
  - lastProbeTime: null
    lastTransitionTime: "2019-09-30T07:33:54Z"
    status: "True"
    type: PodScheduled
  containerStatuses:
  - containerID: docker://07dfc340f25435780888598d86e3bc8c52b68a4964a53b00fdb055fac0136db6
    image: luksa/kubia:latest
    imageID: docker-pullable://luksa/kubia@sha256:3f28e304dc0f63dc30f273a4202096f0fa0d08510bd2ee7e1032ce600616de24
    lastState: {}
    name: kubia
    ready: true
    restartCount: 0
    state:
      running:
        startedAt: "2019-09-30T07:35:36Z"
  hostIP: 192.168.0.103
  phase: Running
  podIP: 10.244.3.13
  qosClass: BestEffort
  startTime: "2019-09-30T07:33:54Z"


自己定义代码清单
apiVersion: v1
kind: Pod
metadata:
  name: kubia-manual
spec:
  containers:
  - image: luksa/kubia
    name: kubia
    ports:
    - containerPort: 8080
      protocol: TCP
指定容器端口 纯属展示性质 忽略它们 不会带来任何影响
但可以带来一个效果 就是允许为端口指定一个名称 方便我们使用

使用kubectl explain pod 可以发现可能的API对象字段
kubectl explain pod.spec



使用apply创建pod 注意可以create
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-manual.yaml
pod/kubia-manual created


查看日志
[kubeadm@masnode1 ~]$ kubectl get pod
NAME           READY   STATUS    RESTARTS   AGE
kubia-manual   1/1     Running   0          8m7s
kubia-rz6ff    1/1     Running   0          38m
[kubeadm@masnode1 ~]$ kubectl logs kubia-manual
Kubia server starting...

Pod被删除 它的日志也会被删除 如果希望pod删除后日志保留要设置集群范围的日志系统 17章

向Pod发出请求
这里有个不太常用的方法 端口转发
[kubeadm@masnode1 ~]$ kubectl port-forward kubia-manual 9999:8080 &
[1] 47074
[kubeadm@masnode1 ~]$ Forwarding from 127.0.0.1:9999 -> 8080
Forwarding from [::1]:9999 -> 8080

[kubeadm@masnode1 ~]$ curl localhost:9999
Handling connection for 9999
You've hit kubia-manual


使用标签组织Pod
[kubeadm@masnode1 ~]$ cat kubia-manual-with-labels.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubia-manual-v2
  labels:
    creation_method: manual
    env: prod
spec:
  containers:
  - image: luksa/kubia
    name: kubia
    ports:
    - containerPort: 8080
      protocol: TCP
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-manual-with-labels.yaml
pod/kubia-manual-v2 created


[kubeadm@masnode1 ~]$ kubectl get pod
NAME              READY   STATUS    RESTARTS   AGE
kubia-manual      1/1     Running   0          38m
kubia-manual-v2   1/1     Running   0          57s
kubia-rz6ff       1/1     Running   0          68m
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME              READY   STATUS    RESTARTS   AGE   LABELS
kubia-manual      1/1     Running   0          38m   <none>
kubia-manual-v2   1/1     Running   0          70s   creation_method=manual,env=prod
kubia-rz6ff       1/1     Running   0          69m   run=kubia

修改现有的Pod的标签
[kubeadm@masnode1 ~]$ kubectl label pods kubia-manual creation_method=manual env=order
pod/kubia-manual labeled
[kubeadm@masnode1 ~]$ kubectl get po -L creation_method,env
NAME              READY   STATUS    RESTARTS   AGE     CREATION_METHOD   ENV
kubia-manual      1/1     Running   0          40m     manual            order
kubia-manual-v2   1/1     Running   0          3m45s   manual            prod

Pod不是唯一可以附加标签的K8s资源
标签可以附加到任何Kubernetes对象上

使用标签分类节点
[kubeadm@masnode1 ~]$ kubectl label nodes wornode1.example.com cpu=high
node/wornode1.example.com labeled
[kubeadm@masnode1 ~]$ kubectl label nodes wornode1.example.com cpu=middle
error: 'cpu' already has a value (high), and --overwrite is false
[kubeadm@masnode1 ~]$ kubectl label nodes wornode2.example.com cpu=middle
node/wornode2.example.com labeled
[kubeadm@masnode1 ~]$ kubectl label nodes wornode2.example.com cpu=high --overwrite
node/wornode2.example.com labeled
[kubeadm@masnode1 ~]$ kubectl get nodes --show-labels
NAME                   STATUS   ROLES    AGE   VERSION   LABELS
masnode1.example.com   Ready    master   18d   v1.15.3   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=masnode1.example.com,kubernetes.io/os=linux,node-role.kubernetes.io/master=
wornode1.example.com   Ready    <none>   18d   v1.15.3   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,cpu=high,kubernetes.io/arch=amd64,kubernetes.io/hostname=wornode1.example.com,kubernetes.io/os=linux


将Pod调度到特定的节点   

[kubeadm@masnode1 ~]$ cat kubia-cpu.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubia-gpu
spec:
  nodeSelector:
    cpu: high
  containers:
  - image: luksa/kubia
    name: kubia
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-cpu.yaml
pod/kubia-gpu created
[kubeadm@masnode1 ~]$ kubectl get pod -o wide
NAME              READY   STATUS              RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-gpu         0/1     ContainerCreating   0          13s   <none>        wornode2.example.com   <none>           <none>


我们也可以将Pod 调度到某个确切的节点
    
节点都有一个唯一的标签 kubernetes.io/hostname: wornode3.example.com 主机名 
[kubeadm@masnode1 ~]$ cat kubia-node-uni-label.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubia-node3
spec:
  nodeSelector:
    kubernetes.io/hostname: wornode3.example.com
  containers:
  - image: luksa/kubia
    name: kubia

[kubeadm@masnode1 ~]$ kubectl get pod -o wide
NAME              READY   STATUS    RESTARTS   AGE     IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-cpu         1/1     Running   0          4m20s   10.244.2.21   wornode2.example.com   <none>           <none>
kubia-manual      1/1     Running   0          72m     10.244.2.19   wornode2.example.com   <none>           <none>
kubia-manual-v2   1/1     Running   0          35m     10.244.3.14   wornode3.example.com   <none>           <none>
kubia-node3       1/1     Running   0          2m14s   10.244.3.15   wornode3.example.com   <none>           <none>


注解Pod
除标签外 Pod和其他对象还可以包含注解 键值对
注解并不是为了保存表示信息而存在,它不能像标签一样用于对对象进行分组

注解可以容纳更多的信息,并且主要用于工具使用
向K8s引入新特性时 通常也会用注解.
一般来说 新功能的alpha和beta版本不会向API对象引入任何新字段 因此使用的是注解而不是字段
一旦所需的API更改变得清晰并得到所有相关人员的认可,就会引入新的字段并废弃相关注解
大量使用注解可以为每个Pod 和其他API对象添加说明,以便每个使用该集群的人都能快速查找有关每个大都对象的信息
例如: 指定创建对象的人员的姓名的注解可以使集群中工作的人员之间的协作更加便利

查找对象的注解
[kubeadm@masnode1 ~]$ kubectl get pod kubia-manual -o yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Pod","metadata":{"annotations":{},"name":"kubia-manual","namespace":"default"},"spec":{"containers":[{"image":"luksa/kubia","name":"kubia","ports":[{"containerPort":8080,"protocol":"TCP"}]}]}}
  creationTimestamp: "2019-09-30T08:00:31Z"
  labels:
    creation_method: manual
    env: order
  name: kubia-manual
  namespace: default

添加和修改注解
[kubeadm@masnode1 ~]$ kubectl annotate pod kubia-manual example.com/someannotation="foo bar"
pod/kubia-manual annotated
[kubeadm@masnode1 ~]$ kubectl get pod kubia-manual -o yaml|more
apiVersion: v1
kind: Pod
metadata:
  annotations:
    example.com/someannotation: foo bar
    kubectl.kubernetes.io/last-applied-configuration: |


[kubeadm@masnode1 ~]$ kubectl describe pod kubia-manual
Name:         kubia-manual
Namespace:    default
Priority:     0
Node:         wornode2.example.com/192.168.0.102
Start Time:   Mon, 30 Sep 2019 16:00:31 +0800
Labels:       creation_method=manual
              env=order
Annotations:  example.com/someannotation: foo bar
              kubectl.kubernetes.io/last-applied-configuration:


3.7 使用命名空间对资源进行分组
命名空间为资源名称提供了一个作用域
[kubeadm@masnode1 ~]$ kubectl get ns
NAME              STATUS   AGE
default           Active   18d
kube-node-lease   Active   18d
kube-public       Active   18d
kube-system       Active   18d
[kubeadm@masnode1 ~]$ kubectl get pod -n kube-public
No resources found.


创建一个命名空间
[kubeadm@masnode1 ~]$ cat custom-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: custom-namespace

[kubeadm@masnode1 ~]$ kubectl apply -f custom-namespace.yaml
namespace/custom-namespace created
[kubeadm@masnode1 ~]$ kubectl create ns custom-namespace1
namespace/custom-namespace1 created


管理其他命名空间的对象
可以在metadata字段中namespace: custom-namespace
也可以用kubectl create命令创建资源
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-manual.yaml
pod/kubia-manual unchanged
[kubeadm@masnode1 ~]$ kubectl create -f kubia-manual.yaml
Error from server (AlreadyExists): error when creating "kubia-manual.yaml": pods "kubia-manual" already exists
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-manual.yaml -n custom-namespace
pod/kubia-manual created
[kubeadm@masnode1 ~]$

命名空间提供的隔离
实际上命名空间之间并不提供对正在运行的对象的任何隔离

停止和移除Pod
删除Pod的过程 实际上是指示K8S终止该Pod的所有容器
K8S向进程发送一个SIGTERM信号并等待一定的秒数(默认是30秒),使其正常关闭.
如果没有及时关闭,就通过SIGKILL终止该进程.
[kubeadm@masnode1 ~]$ date
2019年 09月 30日 星期一 18:16:22 CST
[kubeadm@masnode1 ~]$ kubectl delete pod kubia-cpu kubia-node3
pod "kubia-cpu" deleted
pod "kubia-node3" deleted
[kubeadm@masnode1 ~]$ date
2019年 09月 30日 星期一 18:17:08 CST
[kubeadm@masnode1 ~]$ date
2019年 09月 30日 星期一 18:17:26 CST
[kubeadm@masnode1 ~]$ kubectl delete pod kubia-manual-v2
pod "kubia-manual-v2" deleted
[kubeadm@masnode1 ~]$ date
2019年 09月 30日 星期一 18:18:12 CST


使用标签选择器删除Pod
[kubeadm@masnode1 ~]$ kubectl delete pod -l creation_method=manual
No resources found


通过删除整个命名空间删除Pod
[kubeadm@masnode1 ~]$ kubectl delete  ns custom-namespace1
namespace "custom-namespace1" deleted

删除命名空间的所有资源
[kubeadm@masnode1 ~]$ kubectl delete  all --all
