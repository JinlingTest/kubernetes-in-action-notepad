实际的用例里 你希望不是能保持运行 保持健康,无需任何手动干预
要做到这点,你几乎不会直接创建Pod,而是创建rs和deployment这样的资源 有它们来创建并管理实际的Pod

当创建未托管的Pod,会选择一个节点,运行容器,K8S会监控这些容器,并在它们失败时重新启动它们
但如果节点失败,那么Pod会失效,而且不会被新节点替换
除非Pod有控制器资源

保持Pod的健康
使用ks的好处是,可以给kubernetes一个容器列表来由其保持容器在集群中运行
一个崩溃的容器会重启
但有时必须从外部检查应用程序的运行状况,而不是依赖于应用的内部检测
-----存活探针 Liveness Probe
k8s可以通过 Liveness Probe 检查容器是否还在运行.
可以为Pod中每个容器单独制定存活探针
k8s有三种探测容器的机制
1. HTTP GET 探针对容器的IP 端口 执行HTTP GET请求 如果探测器收到响应,并且显示没有错误(200和300返回码)则认为探测成功 如果返回错误或错误响应状态 就认为失败,容器将被重新启动
2. TCP套接字探针尝试建立TCP连接
3. Exec探针在容器执行任意命令,检查命令的退出码 如果状态码0 探测成功 其他都是失败


创建基于HTTP的存活探针
下面有个Web应用,可以添加一个存活探针检查其web服务的请求是否提供请求时有意义的
kubectl apply -f kubia-liveness-probe.yaml
kubectl get po kubia-liveness

[kubeadm@masnode1 ~]$ kubectl get po kubia-liveness -o wide
NAME             READY   STATUS              RESTARTS   AGE   IP       NODE                   NOMINATED NODE   READINESS GATES
kubia-liveness   0/1     ContainerCreating   0          25s   <none>   wornode2.example.com   <none>           <none>
[kubeadm@masnode1 ~]$ kubectl get po kubia-liveness -o wide
NAME             READY   STATUS    RESTARTS   AGE     IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-liveness   1/1     Running   2          6m11s   10.244.2.22   wornode2.example.com   <none>           <none>
[kubeadm@masnode1 ~]$ kubectl get po kubia-liveness -o wide
NAME             READY   STATUS             RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-liveness   0/1     CrashLoopBackOff   6          14m   10.244.2.22   wornode2.example.com   <none>           <none>

[kubeadm@masnode1 ~]$ kubectl describe po kubia-liveness
    Ready:          False
    Restart Count:  6
    Liveness:       http-get http://:8080/ delay=0s timeout=1s period=10s #success=1 #failure=3
    Environment:    <none>

Events:
  Type     Reason     Age                   From                           Message
  ----     ------     ----                  ----                           -------
  Normal   Scheduled  20m                   default-scheduler              Successfully assigned default/kubia-liveness to wornode2.example.com
  Normal   Created    15m (x3 over 19m)     kubelet, wornode2.example.com  Created container kubia
  Normal   Started    15m (x3 over 19m)     kubelet, wornode2.example.com  Started container kubia
  Warning  Unhealthy  14m (x9 over 18m)     kubelet, wornode2.example.com  Liveness probe failed: HTTP probe failed with statuscode: 500
  Normal   Killing    14m (x3 over 18m)     kubelet, wornode2.example.com  Container kubia failed liveness probe, will be restarted
  Normal   Pulled     13m (x4 over 19m)     kubelet, wornode2.example.com  Successfully pulled image "luksa/kubia-unhealthy"
  Normal   Pulling    10m (x6 over 20m)     kubelet, wornode2.example.com  Pulling image "luksa/kubia-unhealthy"
  Warning  BackOff    39s (x23 over 6m37s)  kubelet, wornode2.example.com  Back-off restarting failed container

有个小知识点
上述有个退出代码 137或143
      Exit Code:    137
如果是137就是128+9 使用信号9 SIGKILL退出   143=128+15 使用信号15 SIGTERM退出

[kubeadm@masnode1 ~]$ kubectl get po kubia-liveness -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-liveness   1/1     Running   7          18m   10.244.2.22   wornode2.example.com   <none>    <none>

[kubeadm@masnode1 ~]$ kubectl get po kubia-liveness -o wide
NAME             READY   STATUS             RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kubia-liveness   0/1     CrashLoopBackOff   7          19m   10.244.2.22   wornode2.example.com   <none><none>
[kubeadm@masnode1 ~]$ kubectl logs kubia-liveness --previous
Kubia server starting...
Received request from ::ffff:10.244.2.1
Received request from ::ffff:10.244.2.1
Received request from ::ffff:10.244.2.1
Received request from ::ffff:10.244.2.1
Received request from ::ffff:10.244.2.1
Received request from ::ffff:10.244.2.1
Received request from ::ffff:10.244.2.1
Received request from ::ffff:10.244.2.1

配置存活探针的附加属性
delay 延迟
timeout 超时
period 周期

delay=0s 表示在容器启动后立即开始探测 timeout=1s 容器必须在1秒响应 每10秒探测一次 period=10s 连续探测三次失败(failure=3)后重启

配置具有初始延迟的存活探针
kubia-liveness-probe-initial-delay.yaml

创建有效的存活探针
对于生产环境中的Pod 一定要有个有意义的存活探针
一定要检查应用程序内部,而没有任何外部因素影响(例如当服务器无法连接后端数据库 前端web服务器不应该返回存活探针失败 否则重启web服务器无助于问题的解决)
存活探针失败阈值可以配置 所有不需要对存活探针本身设置循环重试



===========了解ReplicationController
Pod发生故障时,kubelet会重建该Pod
而Node发生故障时  rc管理的pod会重新创建

rc是根据pod是否匹配某个标签选择器
一个rc有三个主要部分
1 label selector 
2 replica count 指定运行的pod数量
3 pod template 用于创建新的Pod的副本
三点数据都可以修改 但只有 replica count影响现有Pod

创建一个全新的ReplicationController
参看 kubia-rc.yaml
[kubeadm@masnode1 ~]$ kubectl apply -f kubia-rc.yaml
replicationcontroller/kubia created
[kubeadm@masnode1 ~]$ kubectl get rc
NAME    DESIRED   CURRENT   READY   AGE
kubia   3         3         3       10m
[kubeadm@masnode1 ~]$ kubectl get rc --show-labels
NAME    DESIRED   CURRENT   READY   AGE   LABELS
kubia   3         3         3       10m   app=kubia
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME             READY   STATUS    RESTARTS   AGE   LABELS
kubia-5w9mc      1/1     Running   0          10m   app=kubia
kubia-7jvkr      1/1     Running   0          10m   app=kubia
kubia-liveness   1/1     Running   14         52m   <none>
kubia-q9b5l      1/1     Running   0          10m   app=kubia


K8s会创建一个rc 并确保符合标签选择器app=kubia的pod实例为三个



将Pod移入或移出 ReplicationController的作用域
由rc创建的Pod并不绑定到ec 在任何时刻 rc管理与标签选择器匹配的Pod 通过更改pod的标签 可以将其从rc的作用域天骄或删除
甚至可以从一个rc移动到另一个

尽管一个Pod没有绑定到rc 可以在metadata.ownerReferences
ownerReferences:
  - apiVersion: v1
    blockOwnerDeletion: true
    controller: true
    kind: ReplicationController
    name: kubia
    uid: d48e06d5-682a-4ba4-95fb-39cebf7882b1

如果修改了一个Pod的标签 他不再与rc的标签选择器匹配,那该Pod就变得和其他手动Pod一样
当你改动了pod标签 rc发现一个pod丢失 并启动一个新的
修改Label:
[kubeadm@masnode1 ~]$ kubectl label pod kubia-7jvkr app=test --overwrite
pod/kubia-7jvkr labeled
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS              RESTARTS   AGE   LABELS
kubia-5w9mc   1/1     Running             1          21h   app=kubia
kubia-7jvkr   1/1     Running             1          21h   app=test
kubia-kcsx6   0/1     ContainerCreating   0          3s    app=kubia
kubia-q9b5l   1/1     Running             1          21h   app=kubia

添加Label:
[kubeadm@masnode1 ~]$ kubectl label pod kubia-q9b5l release=stable
pod/kubia-q9b5l labeled
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE   LABELS
kubia-5w9mc   1/1     Running   1          21h   app=kubia
kubia-7jvkr   1/1     Running   1          21h   app=test
kubia-kcsx6   1/1     Running   0          55s   app=kubia
kubia-q9b5l   1/1     Running   1          21h   app=kubia,release=stable



修改Pod模板
rc的Pod模板可以随时修改
要修改旧的Pod,你需要删除它们,并让rc根据新模板将其替换为新的Pod

可以试着编辑rc 向Pod模板添加标签
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE   LABELS
kubia-5w9mc   1/1     Running   1          21h   app=kubia
kubia-7jvkr   1/1     Running   1          21h   app=test
kubia-kcsx6   1/1     Running   0          55s   app=kubia
kubia-q9b5l   1/1     Running   1          21h   app=kubia,release=stable
[kubeadm@masnode1 ~]$ kubectl get rc
NAME    DESIRED   CURRENT   READY   AGE
kubia   3         3         3       21h
[kubeadm@masnode1 ~]$ kubectl edit rc kubia
在templates添加了一个标签
  labels:
    app: kubia
    owner: jin
保存退出    
并没有发生什么变化
replicationcontroller/kubia edited
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE     LABELS
kubia-5w9mc   1/1     Running   1          21h     app=kubia
kubia-7jvkr   1/1     Running   1          21h     app=test
kubia-kcsx6   1/1     Running   0          5m28s   app=kubia
kubia-q9b5l   1/1     Running   1          21h     app=kubia,release=stable

但如果删除了Pod 会看到新标签
[kubeadm@masnode1 ~]$ kubectl delete pod --all
pod "kubia-fn6xf" deleted
pod "kubia-m8jbx" deleted
pod "kubia-rtmp4" deleted
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE   LABELS
kubia-kmsfn   1/1     Running   0          46s   app=kubia,owner=jin
kubia-vh9nw   1/1     Running   0          46s   app=kubia,owner=jin
kubia-xsfjv   1/1     Running   0          46s   app=kubia,owner=jin


水平缩放Pod
[kubeadm@masnode1 ~]$
[kubeadm@masnode1 ~]$ kubectl scale rc kubia --replicas=4
replicationcontroller/kubia scaled
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS              RESTARTS   AGE   LABELS
kubia-kmsfn   1/1     Running             0          10m   app=kubia,owner=jin
kubia-vc8ml   0/1     ContainerCreating   0          3s    app=kubia,owner=jin
kubia-vh9nw   1/1     Running             0          10m   app=kubia,owner=jin
kubia-xsfjv   1/1     Running             0          10m   app=kubia,owner=jin

使用edit也可
[kubeadm@masnode1 ~]$ kubectl edit rc kubia

删除一个rc
当使用kubectl delete删除rc时 Pod也会被删除
但rc创建Pod 而不是rc的组成部分,只是尤其管理,所以可以只删除rc并保持Pod  
使用 --cascade=false
这个很有用处:如果用rs代替rc 就很好用

[kubeadm@masnode1 ~]$ kubectl delete rc kubia --cascade=false
replicationcontroller "kubia" deleted
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE     LABELS
kubia-kmsfn   1/1     Running   0          14m     app=kubia,owner=jin
kubia-vc8ml   1/1     Running   0          4m28s   app=kubia,owner=jin
kubia-vh9nw   1/1     Running   0          14m     app=kubia,owner=jin
kubia-xsfjv   1/1     Running   0          14m     app=kubia,owner=jin


============使用ReplicaSet而不是用rc
ReplicaSet是新一代的ReplicationController
从现在开始开始 使用rs 来替代rc
比较rs rc 但pod选择器的表达能力更强 
rc标签选择器 只允许包含某个标签的匹配Pod,但rs选择器 还允许匹配缺少某个标签的Pod ,或包含某个标签名(就是Key),而不管其值
另外 单个rc无法将Pod与标签env=production和env=devel同时匹配 
It can only match either pods with the env=production label or pods with the env=devel label
But a single ReplicaSet can match both sets of pods and treat them as a single group(一个rs可以匹配两组Pod).
而且rs 可以就用key匹配 而不管里面的值是什么 类似 env=*条件

定义 ReplicaSet
例子:kubia-replicaset.yaml
(注意此处 我将书中的apiVersion 的v1beat1 改为 v1 应该可以 可以查文档 实际也成功)

[kubeadm@masnode1 ~]$ kubectl  apply -f kubia-replicaset.yaml
replicaset.apps/kubia created

[kubeadm@masnode1 ~]$ kubectl get rs
NAME    DESIRED   CURRENT   READY   AGE
kubia   3         3         3       15m

我们没有创建任何新的Pod
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
NAME          READY   STATUS    RESTARTS   AGE   LABELS
kubia-kmsfn   1/1     Running   0          50m   app=kubia,owner=jin
kubia-vh9nw   1/1     Running   0          50m   app=kubia,owner=jin
kubia-xsfjv   1/1     Running   0          50m   app=kubia,owner=jin

========使用rs的更富表达力的标签选择器
rs相比rc的主要改进的它更具表达力的标签选择器
前一个例子是较为简单的  用matchLabels选择器来确认rc和rs没有区别
你可以用更强大的matchExpressions来重写

selector:
  matchExpressions:
  - key: app
    operator: In
    values:
    - kubia


In—Label’s value must match one of the specified values.
NotIn—Label’s value must not match any of the specified values.
Exists—   Pod 必须包含一个指定的标签,值不重要.The values property must not be specified.
DoesNotExist—   Pod 不能包含一个指定的标签,值不重要.The values property must no


======ReplicaSet小结
替代rc
删除
[kubeadm@masnode1 ~]$ kubectl delete rs kubia
replicaset.extensions "kubia" deleted
[kubeadm@masnode1 ~]$
[kubeadm@masnode1 ~]$ kubectl get pod --show-labels
No resources found.


======== 使用DaemonSet在每个节点上运行一个Pod
DaemonSet没有期望副本数的概念 因为 他的工作室确保一个Pod匹配他的选择器并在每个节点上运行.
如果节点下线,不会在其他地方重建Pod,当有新节点加入就会立即部署一个新的Pod
如果无意删除了Pod ,也会被重新创建

========= 使用daemonset只在特定的节点上运行Pod
DaemonSet将Pod部署到集群中的所有节点上,除非指定这些Pod只在部分节点上运行
通过Pod模板nodeSelector指定
(注意:在后面 可以将节点设置为不可调度,防止Pod被部署到节点上.DaemonSet甚至会将Pod部署到这些节点,
因为无法调度的属性只能会被调度器使用,而DaemonSet管理的Pod则完全绕过调度器,这是预期的,这是预期的
因为DaemonSet的木的是运行系统服务,即使是在不可调度的节点上,系统服务通常也需要运行)


[kubeadm@masnode1 ~]$ vim ssd-monitor-daemonset.yaml
[kubeadm@masnode1 ~]$ kubectl apply -f ssd-monitor-daemonset.yaml
daemonset.apps/ssd-monitor created
[kubeadm@masnode1 ~]$ kubectl get daemonsets.
NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
ssd-monitor   0         0         0       0            0           disk=ssd        14s
[kubeadm@masnode1 ~]$ kubectl get pod
No resources found.

[kubeadm@masnode1 ~]$ kubectl get nodes
NAME                   STATUS   ROLES    AGE   VERSION
masnode1.example.com   Ready    master   20d   v1.15.3
wornode1.example.com   Ready    <none>   20d   v1.15.3
wornode2.example.com   Ready    <none>   20d   v1.15.3
wornode3.example.com   Ready    <none>   20d   v1.15.3
[kubeadm@masnode1 ~]$ kubectl label nodes wornode2.example.com disk=hdd
node/wornode2.example.com labeled
[kubeadm@masnode1 ~]$ kubectl get pod
No resources found.
[kubeadm@masnode1 ~]$ kubectl label nodes wornode2.example.com disk=ssd --overwrite
node/wornode2.example.com labeled
[kubeadm@masnode1 ~]$ kubectl get pod
NAME                READY   STATUS              RESTARTS   AGE
ssd-monitor-85vfq   0/1     ContainerCreating   0          5s
[kubeadm@masnode1 ~]$ kubectl get pod
NAME                READY   STATUS    RESTARTS   AGE
ssd-monitor-85vfq   1/1     Running   0          7m43s
[kubeadm@masnode1 ~]$ kubectl get pod -o wide
NAME                READY   STATUS    RESTARTS   AGE     IP            NODE                   NOMINATED NODE   READINESS GATES
ssd-monitor-85vfq   1/1     Running   0          7m55s   10.244.2.30   wornode2.example.com   <none>           <none>
[kubeadm@masnode1 ~]$ kubectl label nodes wornode1.example.com disk=ssd
node/wornode1.example.com labeled
[kubeadm@masnode1 ~]$ kubectl label nodes wornode2.example.com disk=hdd --overwrite
node/wornode2.example.com labeled
[kubeadm@masnode1 ~]$ kubectl get pod -o wide
NAME                READY STATUS   RESTARTS   AGE     IP         NODE     NOMINATED NODE   READINESS GATES
ssd-monitor-4qsgp   1/1    Running  0        17s     10.244.1.19   wornode1.example.com   <none>   <none>
ssd-monitor-85vfq   1/1    Terminating  0     8m27s  10.244.2.30   wornode2.example.com   <none>   <none>



===========运行单个任务的Pod
如果你只想运行完成工作后就终止任务的情况 可以选择Job资源
他允许你运行一种Pod,该Pod在内部进程成功结束,不重启容器.
一旦任务完成,Pod就被认为处于完成状态
在发生节点故障时,该节点上由Job管理的Pod将按照rs的Pod的方式,重新安排到其他节点.
[kubeadm@masnode1 ~]$ kubectl apply -f exporter.yaml
job.batch/batch-job created

[kubeadm@masnode1 ~]$ kubectl get pod
NAME                READY   STATUS    RESTARTS   AGE
batch-job-mjlf9     1/1     Running   0          54s
ssd-monitor-4qsgp   1/1     Running   0          9m23s

运行120s退出
[kubeadm@masnode1 ~]$ kubectl get pod
NAME                READY   STATUS    RESTARTS   AGE
batch-job-mjlf9     1/1     Running   0          54s
ssd-monitor-4qsgp   1/1     Running   0          9m23s
[kubeadm@masnode1 ~]$ kubectl get pod
NAME                READY   STATUS      RESTARTS   AGE
batch-job-mjlf9     0/1     Completed   0          3m45s
ssd-monitor-4qsgp   1/1     Running     0          12m
[kubeadm@masnode1 ~]$ kubectl logs pod batch-job-mjlf9
Error from server (NotFound): pods "pod" not found
[kubeadm@masnode1 ~]$ kubectl logs  batch-job-mjlf9
Wed Oct  2 12:47:39 UTC 2019 Batch job starting
Wed Oct  2 12:49:39 UTC 2019 Finished succesfully

在一个Pod的定义中,可以指定在容器运行进程结束后,k8s会做什么.
这是通过Pod配置的属性restartPolicy完成,默认Always.
Job Pod不能使用默认策略,要明确设置为 OnFailure或者Never.


在job中运行多个Pod实例
Job
可顺序-------串行运行 multi-completion-batch-job.yaml

可以并行运行  multi-completion-parallel-batch-job
[kubeadm@masnode1 ~]$ kubectl apply -f multi-completion-parallel-batch-job.yaml
job.batch/multi-completion-batch-job created
[kubeadm@masnode1 ~]$ kubectl get pod
NAME                               READY   STATUS      RESTARTS   AGE
batch-job-mjlf9                    0/1     Completed   0          16m
multi-completion-batch-job-2dt6l   1/1     Running     0          102s
multi-completion-batch-job-fbmz6   1/1     Running     0          102s
ssd-monitor-4qsgp                  1/1     Running     0          24m


限制Job Pod完成任务的时间
通过在Pod配置中activeDeadlineSeconds属性,可以限制Pod的时间.
如果pod运行时间超过此时间,系统将尝试终止Pod,并将job标记为失败



=====  安排Job定期运行  CronJob
[kubeadm@masnode1 ~]$ kubectl apply -f cronjob.yaml
cronjob.batch/batch-job-every-fifteen-minutes created
[kubeadm@masnode1 ~]$ kubectl get pod
NAME                               READY   STATUS      RESTARTS   AGE
batch-job-mjlf9                    0/1     Completed   0          24m
multi-completion-batch-job-2dt6l   0/1     Completed   0          9m59s
multi-completion-batch-job-d89gp   0/1     Completed   0          7m42s
multi-completion-batch-job-fbmz6   0/1     Completed   0          9m59s
multi-completion-batch-job-pj9z6   0/1     Completed   0          5m26s
multi-completion-batch-job-pnfgk   0/1     Completed   0          7m43s
ssd-monitor-4qsgp                  1/1     Running     0          33m
[kubeadm@masnode1 ~]$ kubectl get cronjobs.batch
NAME                              SCHEDULE             SUSPEND   ACTIVE   LAST SCHEDULE   AGE
batch-job-every-fifteen-minutes   0,15,30,45 * * * *   False     0        <none>          37s

在正常情况下,CronJob总是为计划中配置的每个执行创建一个Job