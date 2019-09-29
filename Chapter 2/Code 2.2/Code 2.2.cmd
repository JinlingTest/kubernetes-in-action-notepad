[root@wornode1 ~]# mkdir code2.2
[root@wornode1 ~]# cd code2.2
[root@wornode1 code2.2]# vim Dockerfile
[root@wornode1 code2.2]# vim  app.js
[root@wornode1 code2.2]# docker build -t kubia .
Sending build context to Docker daemon  3.072kB
Step 1/3 : FROM node:7
7: Pulling from library/node
ad74af05f5a2: Pull complete 
2b032b8bbe8b: Pull complete 
a9a5b35f6ead: Pull complete 
3245b5a1c52c: Pull complete 
afa075743392: Pull complete 
9fb9f21641cd: Pull complete 
3f40ad2666bc: Pull complete 
49c0ed396b49: Pull complete 
Digest: sha256:af5c2c6ac8bc3fa372ac031ef60c45a285eeba7bce9ee9ed66dad3a01e29ab8d
Status: Downloaded newer image for node:7
 ---> d9aed20b68a4
Step 2/3 : ADD app.js /app.js
 ---> 292081b2d826
Step 3/3 : ENTRYPOINT ["node", "app.js"]
 ---> Running in e752cfa3d0d5
Removing intermediate container e752cfa3d0d5
 ---> d6fe51a8bdda
Successfully built d6fe51a8bdda
Successfully tagged kubia:latest

当创建过程完成 你有一个镜像存放在本地
[root@wornode1 code2.2]# docker images
REPOSITORY        TAG                 IMAGE ID            CREATED             SIZE
kubia             latest              d6fe51a8bdda        59 second

运行容器镜像(-d 容器和当前宿主机shell命令行分离 意味着容器在宿主机后台运行)
[root@wornode1 code2.2]#  docker run --name kubia-container -p 8080:8080 -d kubia
e7395a78a3c23c7254f2dc8e0aa3223b148fe10dae6336d6d43294973b81f897
[root@wornode1 code2.2]# curl localhost:8080
You've hit e7395a78a3c2
[root@wornode1 code2.2]# docker ps
CONTAINER ID  IMAGE     COMMAND          CREATED        STATUS         PORTS                  NAMES
e7395a78a3c2  kubia     "node app.js"    14 minutes ago Up 14 minutes  0.0.0.0:8080->8080/tcp kubia-container

打印包含容器底层信息的长json
docker inspect kubia-container

探索容器内部 在已有容器内部运行bash -i确保标准输入流开放 -t分配一个TTY伪终端
-i保证命令可以输入 -t保证显示命令提示符
[root@wornode1 code2.2]#  docker exec -it kubia-container bash
root@e7395a78a3c2:/# ps aux
USER        PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root          1  0.0  0.4 614424 16812 ?        Ssl  01:47   0:00 node app.js
root         11  0.0  0.0  20236  1920 pts/0    Ss   02:04   0:00 bash
root         16  0.0  0.0  17492  1132 pts/0    R+   02:07   0:00 ps aux

进程ID在容器中和宿主机中是不同的

文件系统也是和宿主机不同
 root@e7395a78a3c2:/# ls /
app.js  bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var

其实容器应用不仅拥有独立的文件系统 还有进程、用户名、主机名和网络接口

停止和删除一个容器
[root@wornode1 code2.2]# docker container stop kubia-container 
kubia-container
[root@wornode1 code2.2]# docker container rm kubia-container     
kubia-container

构建的镜像只可以在本地使用，为了在任何机器都可以使用，可以推送到外部镜像仓库。
为了简单，不需要搭建私有镜像仓库，可以推送到公开Docker Hub （https://hub.docker.com）
另外还有其他广泛使用的 ： quay.io Google container Registry
推送之前，按照docker hub的规定标注镜像 使用docker hub id 即可
[root@wornode1 code2.2]# docker tag kubia:latest jinling/kubia:latest
这不会重命名标签，而是给镜像创建一个额外的标签

推送
[root@wornode1 code2.2]# docker login
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username: jinling
Password: 
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

[root@wornode1 code2.2]# docker push jinling/kubia:latest            
The push refers to repository [docker.io/jinling/kubia]
96ef2ed43d3c: Pushed 
ab90d83fa34a: Mounted from library/node 
8ee318e54723: Mounted from library/node 
e6695624484e: Mounted from library/node 
da59b99bbd3b: Mounted from library/node 
5616a6292c16: Mounted from library/node 
f3ed6cb59ab0: Mounted from library/node 
654f45ecb7e3: Mounted from library/node 
2c40c66f7667: Mounted from library/node 
latest: digest: sha256:f1371fb009d5a8bb943ebe5f885ac7b642a1e935c103220529e25ca51215d130 size: 2213

推送了镜像 任何人都可以在任何docker主机上运行








应用被打包在一个容器镜像中，可以将它部署到Kubernetes集群中，而不是直接在Docker中运行，
但是要事先设置集群，安装集群有多种方法，在 https://kubernetes.io的文档中有详细描述
可以在本地开发机 GCE AWS

展示集群信息
[kubeadm@masnode1 ~]$ kubectl cluster-info 
Kubernetes master is running at https://192.168.0.100:6443
KubeDNS is running at https://192.168.0.100:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

列出集群节点
[kubeadm@masnode1 ~]$ kubectl get nodes
NAME                   STATUS   ROLES    AGE   VERSION
masnode1.example.com   Ready    master   17d   v1.15.3
wornode1.example.com   Ready    <none>   17d   v1.15.3
wornode2.example.com   Ready    <none>   17d   v1.15.3
wornode3.example.com   Ready    <none>   17d   v1.15.3

部署Node.js应用
[kubeadm@masnode1 ~]$ kubectl run kubia --image=luksa/kubia --port=8080 --generator=run/v1
kubectl run --generator=run/v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
replicationcontroller/kubia created

列出Pod
[kubeadm@masnode1 ~]$ kubectl get pod
NAME          READY   STATUS              RESTARTS   AGE
kubia-hv7h6   0/1     ContainerCreating   0          10s

要查看更多信息 可以describe
[kubeadm@masnode1 ~]$ kubectl describe pod kubia-hv7h6 
Name:           kubia-hv7h6
Namespace:      default
Priority:       0
Node:           wornode1.example.com/192.168.0.101
Start Time:     Sun, 29 Sep 2019 11:18:46 +0800
Labels:         run=kubia
Annotations:    <none>
Status:         Pending
IP:             
Controlled By:  ReplicationController/kubia
Containers:
  kubia:
    Container ID:   
    Image:          luksa/kubia
    Image ID:       
    Port:           8080/TCP
    Host Port:      0/TCP
    State:          Waiting
      Reason:       ContainerCreating
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-m9z4j (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  default-token-m9z4j:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-m9z4j
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age   From                           Message
  ----    ------     ----  ----                           -------
  Normal  Scheduled  22s   default-scheduler              Successfully assigned default/kubia-hv7h6 to wornode1.example.com
  Normal  Pulling    21s   kubelet, wornode1.example.com  Pulling image "luksa/kubia"

可以查看到在节点1 上部署 现在正在下载image

下载完镜像 既可以看到运行
[kubeadm@masnode1 ~]$ kubectl get pod
NAME          READY   STATUS    RESTARTS   AGE
kubia-hv7h6   1/1     Running   0          2m29s
要查看更多信息 可以describe
此过程可以看到图显示
Figure 2.6 Running the luksa/kubia container image in Kubernetes

此时更多信息中 可以看到Pod地址等
[kubeadm@masnode1 ~]$ kubectl describe pod kubia-hv7h6 
Name:           kubia-hv7h6
Namespace:      default
Priority:       0
Node:           wornode1.example.com/192.168.0.101
Start Time:     Sun, 29 Sep 2019 11:18:46 +0800
Labels:         run=kubia
Annotations:    <none>
Status:         Running
IP:             10.244.1.82
Controlled By:  ReplicationController/kubia
Containers:
  kubia:
    Container ID:   docker://6d0e4ab3dea4bad9bc53caa35af6716d7b2eeb4f7f99db7e303c6d2355462a67
    Image:          luksa/kubia
    Image ID:       docker-pullable://luksa/kubia@sha256:3f28e304dc0f63dc30f273a4202096f0fa0d08510bd2ee7e1032ce600616de24
    Port:           8080/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Sun, 29 Sep 2019 11:19:54 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-m9z4j (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  default-token-m9z4j:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-m9z4j
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age   From                           Message
  ----    ------     ----  ----                           -------
  Normal  Scheduled  11m   default-scheduler              Successfully assigned default/kubia-hv7h6 to wornode1.example.com
  Normal  Pulling    11m   kubelet, wornode1.example.com  Pulling image "luksa/kubia"
  Normal  Pulled     10m   kubelet, wornode1.example.com  Successfully pulled image "luksa/kubia"
  Normal  Created    10m   kubelet, wornode1.example.com  Created container kubia
  Normal  Started    10m   kubelet, wornode1.example.com  Started container kubia

如何访问到运行的Pod
每个Pod都有自己的地址 但那时集群内部的(由flannel提供的10.244.0.0/24)地址
[kubeadm@masnode1 ~]$ kubectl get pod -o wide
NAME          READY   STATUS    RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-hv7h6   1/1     Running   0          13m   10.244.1.82   wornode1.example.com   <none>           <none>

要让Pod能够从外部访问
需要通过sevice公开它，要创建一个特殊的LoadBalancer类型的service。
因为如果你创建一个常规服务(一个ClusterIP服务)，他只能从集群内部访问。
通过LoadBalancer类型的服务，将创建一个外部负载均衡，可以通过负载均衡的公共IP访问Pod

创建一个服务对象，告知对外暴露之前创建的ReplicationController
[kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   63s

[kubeadm@masnode1 ~]$ kubectl get rc 
NAME    DESIRED   CURRENT   READY   AGE
kubia   1         1         1       51m

[kubeadm@masnode1 ~]$ kubectl expose rc kubia --type=LoadBalancer --name kubia-http
service/kubia-http exposed

[kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP      10.96.0.1      <none>        443/TCP          78s
kubia-http   LoadBalancer   10.106.74.22   <pending>     8080:32589/TCP   4s

此时没有外部地址 显示Pending 如果在GCE云服务中 云基础设置需要一段时间创建负载均衡
[kubeadm@masnode1 ~]$ kubectl describe svc kubia-http
Name:                     kubia-http
Namespace:                default
Labels:                   run=kubia
Annotations:              <none>
Selector:                 run=kubia
Type:                     LoadBalancer
IP:                       10.106.74.22
Port:                     <unset>  8080/TCP
TargetPort:               8080/TCP
NodePort:                 <unset>  32589/TCP
Endpoints:                10.244.1.82:8080
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>

但这个Kubeadm建立的实验环境中没有外部地址
我们可以用node地址和端口32589访问
查看下Pod地址 Kube-proxy service地址和node地址
[kubeadm@masnode1 ~]$ kubectl get pod -o wide
NAME          READY   STATUS    RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-hv7h6   1/1     Running   0          56m   10.244.1.82   wornode1.example.com   <none>           <none>
[kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP      10.96.0.1      <none>        443/TCP          5m20s
kubia-http   LoadBalancer   10.106.74.22   <pending>     8080:32589/TCP   4m6s
[kubeadm@masnode1 ~]$ kubectl get nodes -o wide
NAME                   STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION          CONTAINER-RUNTIME
masnode1.example.com   Ready    master   17d   v1.15.3   192.168.0.100   <none>        CentOS Linux 7 (Core)   3.10.0-693.el7.x86_64   docker://18.9.7
wornode1.example.com   Ready    <none>   17d   v1.15.3   192.168.0.101   <none>        CentOS Linux 7 (Core)   3.10.0-693.el7.x86_64   docker://18.9.7
wornode2.example.com   Ready    <none>   17d   v1.15.3   192.168.0.102   <none>        CentOS Linux 7 (Core)   3.10.0-693.el7.x86_64   docker://18.9.7
wornode3.example.com   Ready    <none>   17d   v1.15.3   192.168.0.103   <none>        CentOS Linux 7 (Core)   3.10.0-693.el7.x86_64   docker://18.9.7

分别使用pod   10.244.1.82:8080
使用service IP 10.106.74.22:8080
使用node  192.168.0.101:32589
[kubeadm@masnode1 ~]$ curl 10.244.1.82:8080
You've hit kubia-hv7h6
[kubeadm@masnode1 ~]$ curl 10.106.74.22:8080
You've hit kubia-hv7h6
[kubeadm@masnode1 ~]$ curl 192.168.0.101:32589
You've hit kubia-hv7h6

为什么需要服务：
pod的存在是短暂的，消失的Pod会由ReplicationController替换为新的Pod，新的Pod与原来的Pod不是一个IP地址
这就需要服务解决不断变换的Pod 地址，以及在一个IP和端口上暴露多个Pod
服务表示一组或多组提供相同服务的Pod 的静态地址。到达服务的请求将被转发到属于该服务的一个Pod 的容器的IP和端口


水平伸缩应用
[kubeadm@masnode1 ~]$ kubectl get rc
NAME    DESIRED   CURRENT   READY   AGE
kubia   1         1         1       64m

DESIRED表示期望运行的pod副本数目
CURRENT表示当前的Pod副本数目

增加期望的副本数目
[kubeadm@masnode1 ~]$ kubectl scale rc kubia --replicas=3
replicationcontroller/kubia scaled
[kubeadm@masnode1 ~]$ kubectl get rc
NAME    DESIRED   CURRENT   READY   AGE
kubia   3         3         1       66m

READY表示一个副本准备好
继续详细查看
[kubeadm@masnode1 ~]$ kubectl describe rc kubia 
Name:         kubia
Namespace:    default
Selector:     run=kubia
Labels:       run=kubia
Annotations:  <none>
Replicas:     3 current / 3 desired
Pods Status:  1 Running / 2 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  run=kubia
  Containers:
   kubia:
    Image:        luksa/kubia
    Port:         8080/TCP
    Host Port:    0/TCP
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type    Reason            Age   From                    Message
  ----    ------            ----  ----                    -------
  Normal  SuccessfulCreate  62s   replication-controller  Created pod: kubia-9bxdz
  Normal  SuccessfulCreate  62s   replication-controller  Created pod: kubia-7t6s5

  继续看POD的情况
  [kubeadm@masnode1 ~]$ kubectl describe pod kubia-9bxdz 
  Name:           kubia-9bxdz
Namespace:      default
Priority:       0
Node:           wornode3.example.com/192.168.0.103
Start Time:     Sun, 29 Sep 2019 12:25:25 +0800
Labels:         run=kubia
Annotations:    <none>
Status:         Pending
IP:             
Controlled By:  ReplicationController/kubia
Containers:
  kubia:
    Container ID:   
    Image:          luksa/kubia
    Image ID:       
    Port:           8080/TCP
    Host Port:      0/TCP
    State:          Waiting
      Reason:       ContainerCreating
    Ready:          False
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-m9z4j (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             False 
  ContainersReady   False 
  PodScheduled      True 
Volumes:
  default-token-m9z4j:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-m9z4j
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type    Reason     Age   From                           Message
  ----    ------     ----  ----                           -------
  Normal  Scheduled  82s   default-scheduler              Successfully assigned default/kubia-9bxdz to wornode3.example.com
  Normal  Pulling    82s   kubelet, wornode3.example.com  Pulling image "luksa/kubia"
  正在拉取image
 一会之后
   Normal  Pulling    2m34s  kubelet, wornode3.example.com  Pulling image "luksa/kubia"
  Normal  Pulled     29s    kubelet, wornode3.example.com  Successfully pulled image "luksa/kubia"
  Normal  Created    29s    kubelet, wornode3.example.com  Created container kubia
  Normal  Started    28s    kubelet, wornode3.example.com  Started container kubia

Pod建立好

查看扩容结果
  [kubeadm@masnode1 ~]$ kubectl get rc                   
NAME    DESIRED   CURRENT   READY   AGE
kubia   3         3         3       69m

[kubeadm@masnode1 ~]$ kubectl get pod
NAME          READY   STATUS    RESTARTS   AGE
kubia-7t6s5   1/1     Running   0          3m42s
kubia-9bxdz   1/1     Running   0          3m42s
kubia-hv7h6   1/1     Running   0          70m

通过访问 Node地址 
[kubeadm@masnode1 ~]$ curl 192.168.0.101:32589
You've hit kubia-7t6s5
[kubeadm@masnode1 ~]$ curl 192.168.0.102:32589
You've hit kubia-hv7h6
[kubeadm@masnode1 ~]$ curl 192.168.0.103:32589
You've hit kubia-9bxdz

看图
Figure 2.8 Three instances of a pod managed by the same ReplicationController and exposed 
through a single service IP and port.
