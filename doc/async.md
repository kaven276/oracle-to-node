<script src="header.js"></script>

<div id="title"> Noradle async db operation </div>

如何实现数据库内部的异步处理


使用 pipe 和使用 alert 的比较：
===========================

pipe 的缺点

1. 可能被误读造成丢失，数据库宕机也会造成消息丢失。pipe 可能会被不相关的程序读取，包括IDE的消息监听器，包括其他错误的程序，从而造成信息丢失。解决方法：通过 pipe 命名规范达到防止误重用 pipe name 的目的同时，每当读 pipe 超时后，依然可以使用扫表的方法将漏掉的消息处理掉，代价最多是处理延时和顺序打乱。如果每隔一段时间总有新消息，broker 可以记录上次扫表时间，如果间隔较长就扫描一次。每次扫表必须使用 for update 防止并发重复读取。
2. 接收方可能看不到未提交的数据。pipe 在 trigger 中触发的话，监听过程收到消息后可能还看不到触发 trigger 的事务的变更。解决方法：在 trigger 中只进行 pack 消息，但是直到 commit 后才 send 消息即可。同理，如果事物回滚了，那么需要调用 dbms_pipe.reset_buffer 清除本地消息，并且不再调用 send_message 发出
3. pipe 可能由于没有及时监听爆满从而报错。解决方法：确保监听进程启动即可解决此问题。或者在发现爆满的同时，自动启动后台进程（通过告知 nodeJS 调用消息 broker ?）

pipe 的优点

1. 具有更好的性能，因为可以使用 tablename 作为消息类型，rowid 作为消息类型下的 key. 这样不用按照状态扫表就可以读取全部的消息内容
2. 具有保持原始消息产生顺序的作用
3. 适合并行工作，可以使用多个监听进程一起监听事件，不用担心事件被重复读取
4. pipe 内容中可以携带最多到全部的消息体内容，这样监听进程就可以完全不用扫表就能将消息发送给 NodeJS

alert 的优点

1. 进程间通信开销非常的小（是以收到 alert 后需要进行按状态扫表为代价）
2. 可以在 trigger 中触发，监听过程收到消息后一定能看到所做的变化
3. 如果一些 alert 丢失也没关系，下次 alert 时会将之前所有的为发送消息一并发出，或者 alert 等待超时后也会将漏掉的消息发送出去
4. 简单，产生消息的过程只要写表然后上面加者 trigger 或同步发送 alert 即可，无需理会 alert 内容，非常的方便
5. 所有事件的相关数据提取、序列化、发往NodeJS 等工作都放到 broker 后台进程执行，不影响前台响应。

alert 的缺点

1. 默认只支持单 broker 进程。如果启动多个监听进程，多进程可能会重复读取和处理消息。解决方法：扫表时必须人工区分段落不同的部分分别扫描(需要表分区或索引分区，然后并发扫描相关表或索引的分区)，发出的 alert 消息名称附带段落号，然后各个监听进程只处理自己段落的消息也可以每个监听进程一次只读取一定数量事件，一次性的读到 record array 中，然后进行批量状态修改并提交，这样别的进程就不会重复读取事件了。
2. 收到 alert 后需要进行按状态扫表，最差的情况下，每个事件都会导致一次全面的扫表解决方法：对不同状态的消息进行分表或分区存储，这样每个 broker 只需全表扫描本表或本分区即可，或者使用 bitmap index 也可，不会扫描到不相关的数据

比较 alert/pipe 组合方式：可以看出，alert 有的优点，pipe 也都有。
alert 唯一比 pipe 的优势就是不传递消息体，完全使用 sql 通过库表进行关联，写法为纯 sql/plsql ，比较简单。
但是 pipe 方式打入 rowid 等信息防止了扫表，并且支持并发，因此通常要明显好过 alert 方式。
如果表或分区中只保留待处理的消息，并且不需要并发的化，那么依然可以使用 alert 方式。


直接 DCO 和通过 async DCO 的比较
==============================

直接 DCO 需要写网络 I/O，速度较慢，会阻塞主处理进程。
直接 DCO 遭遇网络异常的可能行要远大于写 pipe，造成主处理进程异常。
需要异步处理的内容可能有一定量，为了不影响主进程，放到异步进程中做。

总结：无需回复的异步处理使得主进程更快更稳定，真正分担了主进程的负担。

为了避免 DCO 对主进程的影响，可以考虑设置固定的 pipe 到 node 转发后台 job。
pipe name = direct2node
NO.1 参数为 proxy id
其他参数为要发送给 proxy 的内容。


使用并发的 worker background process 来处理来自浏览器的请求
=======================================================

用例：
* 如，当一个较大的页面由多个部分组成，而每个部分又需要较长的生成时间时，可以使用 async 机制将请求拿到后台进程中执行，后台进程拥有完成的页面输出能力，只不过输出的结果不包含所谓的 http header 信息，后台进程输出的页面片段可用采用现有的任何输出 API，结果将打入到标准 blob 中(和主页面一样)，然后通过指示将该 blob result 通过 pipe 机制传回主过程。使用 pack 将回应信息打入 pipe，然后调用 API callback 无参数自动将其发往主过过程。主过程在调用分布时，使用了 API call_async() -> unique pipe id。


使用 async 提供 async.listen 监听一切需后台处理的 pipe 请求
=======================================================

使用内置标准化以后后台处理 async 包
--------------------------------
使用  async  可以将已经写入到表中的信息当做事件，将其 rowid 作为索引，
传递给后台进程异步执行，从而缓解前台进程的压力，同时使后台进程得到批处理的性能优势。

其实所有向外发送的请求都可以通过一组完全一样的后台 scheduler process 完成。

所有的对外请求都使用一个 pipe
pipe 中都要包含固定的 handler 信息。
然后由动态执行该 handler 的存储过程，
handler 取出其他参数信息，包括 table/rowid 等等，然后进行处理和 DCO 对外调用。

这个方法唯一的缺点就是每个请求的处理都要动态执行，可能效率略差，
但是本来 pl/sql 也是解释执行，因此其实也没有太大的性能差异。

但是由此也带来了额外的好处。
1. 后台进程管理简化了，只要在系统级启动一定量的服务进程即可
2. 具体的 handler 重新编译不会因为后台一直处于执行状态从而被阻塞
3. 执行出现异常可以统一进行记日志，报警的工作

和 gateway.listen 对比：
1. gateway.listen 监听 tcp 请求，async 监听 pipe 请求
2. tcp 请求中包含了全部外部请求信息，async pipe 请求中包含了全部待处理数据的引子信息，如 rowid
3. tcp 请求中包含要执行那个过程，async 请求中也在 pipe 中包含了要执行那个过程，而且他们都是动态执行，而且都允许被调用过程可随时冲编译。

和 gateway.listen 合并是不可行的
---------------------------------

只是，配置后台通用的异步框架进程比较麻烦，
如果配置多了，就会导致进程数浪费，如果配置少了，可能处理大量异步请求会慢。
因此考虑和前台 gateway.listen 合并。
当 gateway.listen 监听没有请求时，看一下 general pipe 有无消息(timeout 为0)，有就动态执行，没有和原先一样。
但是一次只能处理一个请求，因为否则的化，正常的前台请求发送过来，oracle 侧总不处理可能 tcp buffer 会满，从而造成前台服务错误。
这样可以确保前台处理优先，同时不用单独配置后台进程。同时保证后台处理可能达到最大的并发处理能力。
比如在春节发送短信时，可能同时几乎全部noradle进程都被动员进行短信发送。
但是前台 tcp 请求监听超时为 3s，也就是每处理一个后台请求后，都要等待 3s 钟后才能处理另外其他的短信。

如果进程能够同时监听 tcp 和 pipe 消息这样就不用配置大量的后台进程了，只要有闲置的前台进程就可以用于后台处理。
如果前后太消息都要求已有前后台请求就能够马上处理，那么在目前的 oracle 机制下是做不到的。
因为进程同时只能等待一个事件，不能同时等待 tcp 和 pipe。

因此最后的可能就是由 p_mon 控制前台后台进程数量。
所有前台出于性能原因，可以不同的组连接不同的前台nodejs，而后台只有一组，也可以有多组呀。
前台 gateway.listen 需要连接到不同的 node 服务并监听请求，
后台 async.listen 需要监听不同的 pipe。

DCO + DBCall 来实现 async
------------------------
考虑不使用 async，而使用 DCO + DBCall 来实现 async，
所有需要异步处理的 oracle 工作都直接通过 dco 将引子信息传给 worker proxy，其中包含要执行的过程及其参数。
然后 worker proxy 使用 DBCall 调用执行来获取对外请求的完整信息，发出请求，再通过 DCO 或者 DBCall 返回结果或更新数据库状态。
一旦有紧急消息要想外发送时，需要繁琐的步骤。

  1. 发送 pipe 引子信息
  2. 发送 DCO 到 worker proxy
  3. worker proxy 执行 handler message stream
  4. oracle side handler 读取 pipe 中的引子信息，输出完整的请求信息
  5. 从 message stream 接受请求信息

如果是直接

  1. 发送 pipe 引子信息
  2. 后台进程直接执行 handler 并且将完整的请求信息
  3. 通过 dco 发给 worker proxy

可以看到，后者比前者要减少不少环节，性能更好，没有无谓的损耗，响应更快。


使用 pipe 和使用 dco 进行 oracle 异步处理的比较：
1. pipe 基于oracle共享内存，跨进程通信效率更高；而dco方式须经到 ext-hub,worker proxy,gateway.listen 三步跨进程通信
2. dco 方式可以将异步处理分发到其他数据库和其他非oracle服务上；pipe 方式也可以在 handler 中通过 dco 实现相同能力。
3. 如果请求就是oracle外的，那么直接使用 dco 好了；如果请求首先是相同库的后续处理，那么直接使用 pipe 好了。
4. 使用 dco 方式不用配置所谓的后台进程，可以使用现有的输出 API 进行请求信息的输出；使用 pipe  方式首先得建立一定量的后台进程
5. 当实现了 in-hub 后，所有的 worker proxy 都可以很容易的访问数据库获取其最新消息，进程管理就大为简化了。
6. 使用 dco 实现异步数据库处理 overhead 较高，handler 名称和其参数要周转一个来回





async 和 DCO 的关系
==================

pipe 方式不用于发送对外请求，而仅仅作为 oracle 内部的异步分担处理机制。
pipe 方式和 DCO 是正交的关系。
可以只使用 pipe 将后续处理部分交给后台过程处理。
也可以在前台处理中同时调用 DCO 请求外部服务，而不使用 pipe。
当然也可以在后台异步处理服务中调用 DCO 调用外部资源。


<script src="footer.js"></script>