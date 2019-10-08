创建服务资源 利用单个地址反问一组pod
发现集群中的服务
将服务公开给外部客户端
从集群内部来凝结外部服务
控制pod与服务关联


学历了Pod和通过控制器部署 
就微服务而言,Pod经常需要对来自集群内部的其他Pod和集群外部的HTTP请求作出响应
在没有K8S的世界,管理员要在客户端指出IP或HOSTNAME
在K8S世界,并不适用,因为:
 1. Pod是短暂的
 2. K8S在Pod启动前就会给Pod分配IP地址 因此客户端不能提前知道提供服务的Pod的IP
 3. 水平伸缩意味多个Pod提供相同服务 需要一个单一的IP进行访问

 为了上述问题k8s使用了一种资源 services

=====
服务services 是为一组功能相同的pod提供单一且不变的接入点的资源

内部和外部客户端通常通过服务连接到Pod

=====
创建服务
服务的后端有不知一个Pod,服务连接所有的后端是负载均衡的
使用标签选择器 来定义Pod属于哪个服务
前面使用过expose创建服务

[kubeadm@masnode1 ~]$ kubectl expose rc kubia --type=LoadBalancer --name kubia-http
service/kubia-http exposed

[kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP      10.96.0.1      <none>        443/TCP          78s
kubia-http   LoadBalancer   10.106.74.22   <pending>     8080:32589/TCP   4s

现在使用YAML
kubia-svc.yaml
创建了一个kubia服务 在80 端口接收请求 并路由到app=kubia的pod 的8080
[kubeadm@masnode1 ~]$ vim kubia-svc.yaml
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-svc.yaml
service/kubia created
  [kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   2d16h
kubia        ClusterIP   10.111.237.45   <none>        80/TCP    23m
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE   LABELS
kubia-hx2dd   1/1     Running   0          26s   app=kubia
kubia-w9k6c   1/1     Running   0          26s   app=kubia
kubia-zvh4m   1/1     Running   0          26s   app=kubia

分配的是集群地址,目前只可以集群内部访问
测试方法
1. 如果是kubeadm部署的实验环境 可以在master节点直接使用curl测试

[kubeadm@masnode1 ~]$ curl http://10.111.237.45
You've hit kubia-w9k6c
[kubeadm@masnode1 ~]$ curl http://10.111.237.45
You've hit kubia-hx2dd
[kubeadm@masnode1 ~]$ curl http://10.111.237.45
You've hit kubia-hx2dd
[kubeadm@masnode1 ~]$ curl http://10.111.237.45
You've hit kubia-zvh4m

2. 如果是谷歌云环境 1.可以建一个Pod 来访问 2.ssh登录到一个Pod 来访问 3.使用kubectl exec 用一个pod来访问
例如第三种(前提是该Pod的容器镜像有访问web的工具curl 或 wget也行)
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl http://10.111.237.45
You've hit kubia-hx2dd
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    23    0    23    0     0  12405      0 --:--:-- --:--:-- --:--:-- 23000
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl http://10.111.237.45
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    23    0    23    0     0   2325      0 --:--:-- --:--:-- --:--:--  2555
You've hit kubia-w9k6c
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl -s http://10.111.237.45
You've hit kubia-w9k6c
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl -s http://10.111.237.45
You've hit kubia-w9k6c
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl -s http://10.111.237.45
You've hit kubia-hx2dd

注意 -- 代表kubectl 命令项结束 之后是在容器中执行的命令,如果命令中没有一横岗开始的参数也可以不需要--
但这里有个-s  会被解析成kubectl exec的选项
就像这样
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd  curl -s http://10.111.237.45
error: couldn't get version/kind; json parse error: json: cannot unmarshal string into Go value of type struct { APIVersion string "json:\"apiVersion,omitempty\""; Kind string "json:\"kind,omitempty\"" }
这里的-s 被解析为连接一个API Server 

没有横杠参数-s  就可以不加--
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd  curl  http://10.111.237.45
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    23    0    23    0     0   4417      0 --:--:-- --:--:-- --:--:--  5750
You've hit kubia-w9k6c

curl -s 是指 -s, --silent        Silent mode. Don't output anything

以上过程参见图 Figure 5.3 Using kubectl exec to test out a connection to the service by running curl in one of the pods

====
配置服务上的会话亲和性
如果多次执行相同的命令,每次调用执行的应该在不同的pod
如果希望特定的client产生的所有请求每次都指向同一个pod,可以设置服务的sessionAffinity属性为ClientIP(而不是None)
apiVersion: v1
kind: Service
spec:
  sessionAffinity: ClientIP

kubernetes只支持两种会话亲和性 ClientIP None
(这个亲和性不支持cookie 因为cookie是HTTP 应用层的  而服务只处理TCP和UDP)


spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: kubia
  sessionAffinity: None
  type: ClusterIP


改亲和性 为ClientIP

[kubeadm@masnode1 ~]$ vim kubia-svc.yaml
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-svc.yaml
service/kubia created
[kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   2d17h
kubia        ClusterIP   10.104.251.87   <none>        80/TCP    34s
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl -s http://10.104.251.87
You've hit kubia-zvh4m
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl -s http://10.104.251.87
You've hit kubia-zvh4m
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl -s http://10.104.251.87
You've hit kubia-zvh4m
[kubeadm@masnode1 ~]$ kubectl exec  kubia-hx2dd -- curl -s http://10.104.251.87
You've hit kubia-zvh4m


=====
同一个服务暴露多个端口 例如一个80 一个443
注意:创建一个多端口的服务 必须给没个端口指定名字
apiVersion: v1
kind: Service
metadata:
  name: kubia
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
  selector:
    app: kubia

标签选择器应用于整个服务,不能对每个端口做单独的配置

之前创建的Kubia Pod不再多个端口上侦听,因此可以创建一个多端口的服务和建一个多端口的Pod

假设Pod
kind: Pod
spec:
  containers:
  - name: kubia
    ports:
    - name: http                |Container’s port 8080 is called http
      containerPort: 8080
    - name: https               |Port 8443 is called https.
      containerPort: 8443

apiVersion: v1
kind: Service
spec:
  ports:
  - name: http
    port: 80
    targetPort: http            |Port 80 is mapped to the container’s port called http.
  - name: https
    port: 443
    targetPort: https           |Port 443 is mapped to the container’s port, whose name is https.

为什么要采用命名端口的方式呢? 主要原因是更换了端口 比较方便

====
服务发现
客户端pod如何知道服务器的IP呢
是否要事先创建服务,让后手动查找IP 并传递给客户端Pod的配置选项?
当然不是,kubernetes还为客户端提供和发现服务IP和端口的方式

1.通过环境变量发现服务
在pod开始运行时 K8S会初始化一系列环境变量指向现存的服务
如果服务早于客户端pod,Pod上的进程可以根据环境变量获得服务的IP

[kubeadm@masnode1 ~]$ kubectl exec kubia-hx2dd -- env
[kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   3d6h
kubia        ClusterIP   10.104.251.87   <none>        80/TCP    12h
..........
KUBIA_PORT=tcp://10.111.237.45:80
..........
KUBIA_SERVICE_PORT=80
KUBIA_SERVICE_HOST=10.111.237.45
..........

这里保存的是上一次哦svc的地址和端口 10.111.237.45
这次的svc 地址是 10.104.251.87
最近这次相当于是先启动rs中的pod 后启动服务 所以在POd 的环境变量中还是上次的访问地址和端口
那么这个环境变量指示的服务IP就是不可以使用的 现在重启POD 我们在观察

现在 删除pod pod会重建 这样svc在pod之前建立 看结果 变量中地址正确
[kubeadm@masnode1 ~]$ kubectl delete pod --all
pod "kubia-hx2dd" deleted
pod "kubia-w9k6c" deleted
pod "kubia-zvh4m" deleted
[kubeadm@masnode1 ~]$ kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   3d7h
kubia        ClusterIP   10.104.251.87   <none>        80/TCP    13h
[kubeadm@masnode1 ~]$ kubectl get pod
NAME          READY   STATUS    RESTARTS   AGE
kubia-8vjrn   1/1     Running   0          55m
kubia-n72pc   1/1     Running   0          55m
kubia-snx9q   1/1     Running   0          55m
[kubeadm@masnode1 ~]$ kubectl exec kubia-8vjrn -- env

KUBIA_SERVICE_PORT=80
KUBIA_SERVICE_HOST=10.104.251.87

这个服务名kubia转换成大写 如果名称里有横杠 会转化为下划线


以上 变量是一种方式获取服务的IP
还有通过DNS发现
kube-system名字空间运行着coredns 集群中每个POD的/etc/resolv.conf指向
注意POD是否使用内部DNS查询 是根据POD 的spec.dnsPolicy属性
每个服务从内部DNS服务器获得一个DNS条目,客户端的pod在知道服务名称情况下可以通过FQDN访问 而不用环境变量
FQDN名字为kubia.default.svc.cluster.local
此时客户端仍然必须知道服务的端口号,如果服务使用的不是标准端口,客户端需要从环境变量中获取端口号
一般如果前端pod和后端数据库pod 在一个命名空间 可以省略svc.cluster.local的后缀 甚至命名空间
因此可以用服务名kubia来指代服务的FQDN
来测试一下
[kubeadm@masnode1 ~]$ curl 10.104.251.87
You've hit kubia-n72pc
[kubeadm@masnode1 ~]$ kubectl exec kubia-n72pc -- curl -s 10.104.251.87
You've hit kubia-snx9q
[kubeadm@masnode1 ~]$ kubectl exec kubia-n72pc -- curl -s kubia.default.svc.cluster.local
You've hit kubia-snx9q
[kubeadm@masnode1 ~]$ kubectl exec kubia-n72pc -- curl -s kubia.default
You've hit kubia-snx9q
[kubeadm@masnode1 ~]$ kubectl exec kubia-n72pc -- curl -s kubia
You've hit kubia-snx9q

查看pod 的DNS服务器配置  是内部 DNS的服务地址
[kubeadm@masnode1 ~]$ kubectl get svc -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   21d

[kubeadm@masnode1 ~]$ kubectl exec kubia-n72pc -- cat /etc/resolv.conf
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local example.com


无法PING通服务IP的原因
curl这个服务地址是工作的,但是PING不通 因为是虚拟地址 只有和服务端口结合才有意义


=======
连接集群外部的服务
前面是讨论后端是集群中运行的一个和多个POD 的服务
现在需要将它重定向到外部IP和端口
并可以充分利用服务负载平衡和服务发现,在集群中运行的客户端可以连接到外部服务

==== endpoint
先阐述服务 服务并不是和POd直接连接
有一种介于二者的资源endpoint
在服务运行describe 可以看到endpoint

[kubeadm@masnode1 ~]$ kubectl describe svc kubia
Name:              kubia
Namespace:         default
Labels:            <none>
Annotations:       kubectl.kubernetes.io/last-applied-configuration:
                     {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"kubia","namespace":"default"},"spec":{"ports":[{"port":80,"target...
Selector:          app=kubia
Type:              ClusterIP
IP:                10.104.251.87
Port:              <unset>  80/TCP
TargetPort:        8080/TCP
Endpoints:
Session Affinity:  ClientIP
Events:            <none>
看不到endpoint
删除下POD 重新看
[kubeadm@masnode1 ~]$ kubectl delete pod --all
pod "kubia-8vjrn" deleted
pod "kubia-n72pc" deleted
pod "kubia-snx9q" deleted
[kubeadm@masnode1 ~]$ kubectl describe svc kubia
Name:              kubia
Namespace:         default
Labels:            <none>
Annotations:       kubectl.kubernetes.io/last-applied-configuration:
                     {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"kubia","namespace":"default"},"spec":{"ports":[{"port":80,"target...
Selector:          app=kubia
Type:              ClusterIP
IP:                10.104.251.87
Port:              <unset>  80/TCP
TargetPort:        8080/TCP
Endpoints:         10.244.1.25:8080,10.244.2.47:8080,10.244.3.34:8080
Session Affinity:  ClientIP
Events:            <none>

[kubeadm@masnode1 ~]$ kubectl get endpoints
NAME         ENDPOINTS                                            AGE
kubernetes   192.168.0.100:6443                                   3d22h
kubia        10.244.1.25:8080,10.244.2.47:8080,10.244.3.34:8080   28h




手动配置endpoint
服务和endpoint解耦后 可以手动配置和更新
如果创建了不包含pod 的服务 K8S不会创建endpoint资源
因为缺少选择器,将不会知道服务中包含哪些POD
这样需要创建endpoint资源来制定该服务的endpoint列表

手动方式:就要创建服务和Endpoint资源
例子
创建没有选择器的服务
external-service.yaml


为没有选择器的服务创建endpoint资源
[kubeadm@masnode1 ~]$ kubectl apply -f external-service-endpoints.yaml
endpoints/external-service created
[kubeadm@masnode1 ~]$ kubectl describe s
secrets                        services                       storageclasses.storage.k8s.io
serviceaccounts                statefulsets.apps
[kubeadm@masnode1 ~]$ kubectl describe svc external-service
Name:              external-service
Namespace:         default
Labels:            <none>
Annotations:       kubectl.kubernetes.io/last-applied-configuration:
                     {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"external-service","namespace":"default"},"spec":{"ports":[{"port"...
Selector:          <none>
Type:              ClusterIP
IP:                10.99.222.187
Port:              <unset>  80/TCP
TargetPort:        80/TCP
Endpoints:         11.11.11.11:80,22.22.22.22:80
Session Affinity:  None

endpint对象需要与服务具有服务相同的名称 并包含服务的IP和端口
图:Figure 5.4 Pods consuming a service with two external endpoints.


为外部服务创建爱你别名
----除了手动配置服务的Endpoint来代替公开外部服务方法
还可以更简单方法 FQDN
  ----创建ExternalName类型服务
type: ExternalName

[kubeadm@masnode1 ~]$ kubectl get svc
NAME                TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
external-service    ClusterIP      10.99.222.187   <none>        80/TCP    14m
external-service1   ExternalName   <none>          www.ibm.com   <none>    4s

可以使用external-service1.default.svc.cluster.local

证明过程
[kubeadm@masnode1 ~]$ kubectl exec kubia-bstwm -it -- bash

root@kubia-bstwm:/# ping -c1 external-service1
PING e2874.ca2.s.tl88.net (222.138.4.179): 56 data bytes
64 bytes from 222.138.4.179: icmp_seq=0 ttl=127 time=31.094 ms

root@kubia-bstwm:/# ping -c1 external-service1.default.svc.cluster.local
PING e2874.ca2.s.tl88.net (222.138.4.179): 56 data bytes
64 bytes from 222.138.4.179: icmp_seq=0 ttl=127 time=31.142 ms

root@kubia-bstwm:/# ping -c1 www.ibm.com
PING e2874.ca2.s.tl88.net (222.138.4.179): 56 data bytes
64 bytes from 222.138.4.179: icmp_seq=0 ttl=127 time=30.456 ms


---- 将服务暴露给外部客户端
目前为止只讨论集群内部服务如何被Pod使用
将服务暴露给外部客户端
三种
1. 
Setting the service type to NodePort:
每个集群节点都会在节点上打开一个端口
2. 
Setting the service type to LoadBalancer
NodePort的扩展 题哦你法国一个专用的负载均衡器
该均衡器将流量重定向到所有节点端口
3. 
Creating an Ingress resource 创建一个Igress资源 通过一个IP地址公开多个服务 前面的LB只运行在4层.
igress运行在HTTP层提供比四层更多的功能



第一种NodePort
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30123
将类型设置为Nodeport
指定将服务绑定到集群所有节点的30123端口 这不是必须的 可以随机
[kubeadm@masnode1 ~]$ kubectl get svc
NAME                TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
external-service    ClusterIP      10.99.222.187   <none>        80/TCP         34m
external-service1   ExternalName   <none>          www.ibm.com   <none>         20m
kubernetes          ClusterIP      10.96.0.1       <none>        443/TCP        3d22h
kubia               ClusterIP      10.104.251.87   <none>        80/TCP         29h
kubia-nodeport      NodePort       10.103.15.26    <none>        80:30123/TCP   2m13s


你可以使用任何一个Node的IP地址和30123端口 还有clusterIP和80端口
[kubeadm@masnode1 ~]$ kubectl get svc kubia-nodeport
NAME             TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubia-nodeport   NodePort   10.103.15.26   <none>        80:30123/TCP   6h58m
[kubeadm@masnode1 ~]$ curl 10.103.15.26:80
You've hit kubia-wwj2j
[kubeadm@masnode1 ~]$ curl 192.168.0.101:30123
You've hit kubia-bstwm
[kubeadm@masnode1 ~]$ curl 192.168.0.102:30123
You've hit kubia-ls2nf
[kubeadm@masnode1 ~]$ curl 192.168.0.103:30123
You've hit kubia-bstwm
[kubeadm@masnode1 ~]$
看图 Figure 5.6 An external client connecting to a NodePort service either through Node 1 or 2

如果是GCE 还要配置防火墙
$ gcloud compute firewall-rules create kubia-svc-rule --allow=tcp:30123
Created [https://www.googleapis.com/compute/v1/projects/kubia-
1295/global/firewalls/kubia-svc-rule].
NAME NETWORK SRC_RANGES RULES SRC_TAGS TARGET_TAGS
kubia-svc-rule default 0.0.0.0/0 tcp:30123

=====
如果K8S集群支持,可以通过创建一个LoadBalance而不是NodePort服务 自动生成均衡负载器 

均衡负载器有可公开访问的IP地址,并将所有连接重定向到服务
如果你的K8S不支持LoadBalance 就会退化到NodePort 
[kubeadm@masnode1 ~]$ vim  kubia-svc-loadbalancer.yaml
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-svc-loadbalancer.yaml
service/kubia-loadbalancer created
[kubeadm@masnode1 ~]$ kubectl get svc
NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
external-service     ClusterIP      10.99.222.187   <none>        80/TCP         7h40m
external-service1    ExternalName   <none>          www.ibm.com   <none>         7h25m
kubernetes           ClusterIP      10.96.0.1       <none>        443/TCP        4d5h
kubia                ClusterIP      10.104.251.87   <none>        80/TCP         36h
kubia-loadbalancer   LoadBalancer   10.109.200.35   <pending>     80:30990/TCP   11s

这里没有外部地址 所以显示pending

注意不需要设置防火墙

会话亲和性和web浏览器
---由于服务现在已暴露在外
为什么不同的浏览器请求不会碰到不同的pod,就像使用curl
浏览器使用keepalived连接 通过单个连接发送所有请求
curl每次打开一个新连接

看图 Figure 5.7 An external client connecting to a LoadBalancer service

=====
通过Ingress暴露服务
与Loadbalancer的区别是 一个7层 一个4层
Ingress只需要一个公网IP就能为很多服务提供访问
看图Figure 5.9 Multiple services can be exposed through a single Ingress.
通过一个Ingress暴露多个服务
Ingress在网络栈HTTP

安装Ingress
.....

$ kubectl get po --all-namespaces

创建Ingress资源
[kubeadm@masnode1 ~]$ vim kubia-ingress.yaml
定义了一个单一规则的Ingress,确保Ingress 控制器收到的所有请求 kubia.example.com的HTTP请求,将发送到端口80上的kubia-nodeport服务

=====
通过Ingress访问服务
获取Ingress的iP地址
$ kubectl get ingresses
NAME    HOSTS           ADDRESS         PORTS   AGE
kubia kubia.example.com 192.168.99.100  80      29m


Ingress的工作原理
见图:Figure 5.10 Accessing pods through an Ingress


==== 通过相同的Ingress暴露多个服务
Ingress exposing multiple services on same host, but different paths

...
- host: kubia.example.com
  http:
  paths:
  - path: /kubia
    backend:
      serviceName: kubia
      servicePort: 80
  - path: /foo
    backend:
      serviceName: bar
      servicePort: 80

对kubia.example.com/kubia的请求转发给服务Kubia
对kubia.example.com/foo的请求转发给服务bar

继续...
将上述不同的服务映射到不同的主机
spec:
  rules:
  - host: foo.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: foo
          servicePort: 80
  - host: bar.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: bar
          servicePort: 80






