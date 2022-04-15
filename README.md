# RabbitMQ

> * Create Connection
> 
> * Create Channel
> 
> * Define Exchange
> 
> * Declare Queue
> 
> * Publisher 
> 
> * Consumer



![](https://miro.medium.com/max/1400/1*HoAG-7IhLaXShPJG-g9kvA.png)

##### Create Connection

```erlang
{ok, Connection} = amqp_connection:start(#amqp_params_network{}),
```

        The #amqp_params_network record sets the following default values: 

| Parameter                                             | Default Value                                                           |
| ----------------------------------------------------- | ----------------------------------------------------------------------- |
| username                                              | guest                                                                   |
| password                                              | guest                                                                   |
| virtual_host                                          | /                                                                       |
| host                                                  | localhost                                                               |
| port                                                  | 5672                                                                    |
| channel_max                                           | 2047                                                                    |
| frame_max                                             | 0                                                                       |
| [heartbeat](https://www.rabbitmq.com/heartbeats.html) | 0                                                                       |
| [ssl_options](https://www.rabbitmq.com/ssl.html)      | none                                                                    |
| auth_mechanisms                                       | [fun amqp_auth_mechanisms:plain/3, fun amqp_auth_mechanisms:amqplain/3] |
| client_properties                                     | []                                                                      |



#### Create Channel

Can have multiple channels over a single TCP connection

```erlang
  {ok, Channel} = amqp_connection:open_channel(Connection),
```

This function takes the pid of the connection process and returns a {ok, Channel} pair, where Channel is a pid that represents a channel and will be used to execute protocol commands.

#### Exchanges

Exchange type determines route for the message by comparing Binding key, Rounting key and the topic in some exchanges.

Types of exchanges,

* Direct 

* Topic

* Fanout

* Headers

[RabbitMQ Exchange Types. Before we start with this blog, I… | by Fatiha Beqirovski | Trendyol Tech | Medium](https://medium.com/trendyol-tech/rabbitmq-exchange-types-d7e1f51ec825#:~:text=RabbitMQ%20has%20four%20different%20types,have%20bound%20queues%20or%20exchanges.)

```erlang
Declare = #'exchange.declare'{exchange = <<"test_exchange">>},
#'exchange.declare_ok'{} = amqp_channel:call(Channel, Declare)
```

By default it uses DIrect exchange in above example. Or we can define it as follows,

```erlang
#'exchange.declare'{exchange    = <<"my_exchange">>,
                    type        = <<"direct">>,
                    passive     = false,
                    durable     = false,
                    auto_delete = false,
                    internal    = false,
                    nowait      = false,
                    arguments   = []}
```

#### Queues

```erlang
#'queue.declare_ok'{queue = Queue} = amqp_channel:call(Channel, #'queue.declare'{})
```

By doing so, the broker generate a queue with a random name. Or Queue name can be deifned as follows,

```erlang
Declare = #'queue.declare'{queue = <<"my_queue">>},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, Declare),
```

#### Acks

Acknowledgemnets for the received messages from a queue can be sent as below,

```erlang
amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
```

If the ack is received for a particular message it will be removed from the queue.  

## Code example

#### Publisher

```erlang
-module(test_app_publish).

-export([demo_test/0]).

-include("./_build/default/lib/amqp_client/include/amqp_client.hrl").

 demo_test() ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
    %% Open a channel on the connection
    {ok, Channel} = amqp_connection:open_channel(Connection),

    %% Declare a queue
    Declare = #'queue.declare'{queue = <<"my_queue">>},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, Declare),

    %% Publish a message
    Payload = <<Val>>,
    Publish = #'basic.publish'{exchange = <<>>, routing_key = <<"my_queue">>},
    amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),

    %% Close the channel
    amqp_channel:close(Channel),
    %% Close the connection
    amqp_connection:close(Connection),

    ok.
```

#### Consumer

```erlang
-module(test_app_consume).

-include("./_build/default/lib/amqp_client/include/amqp_client.hrl").
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([init/1]).
-record(state, {dummy}).

start_link() ->
    gen_server:start_link({local, server}, ?MODULE, [], []).

init(_Args) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
    %% Open a channel on the connection
    {ok, Channel} = amqp_connection:open_channel(Connection),

    %% Declare a queue
    Declare = #'queue.declare'{queue = <<"my_queue">>},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, Declare),

    #'basic.consume_ok'{consumer_tag = Tag} =
        amqp_channel:call(Channel, #'basic.consume'{queue = <<"my_queue">>}),

    loop(Channel),

    {ok, #state{dummy = 1}}.

loop(Channel) ->
    receive
        %% This is the first message received
        #'basic.consume_ok'{} ->
            loop(Channel);
        %% This is received when the subscription is cancelled
        #'basic.cancel_ok'{} ->
            ok;
        %% A delivery
        {#'basic.deliver'{delivery_tag = Tag}, Content} ->

            %% Do something with the message payload
            R = io_lib:format("~p", [Content]),
            lists:flatten(R),\
            io:fwrite("Received\n"),
            io:fwrite(R),

            %% Ack the message
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

            %% Loop
            loop(Channel)
    end.


```
