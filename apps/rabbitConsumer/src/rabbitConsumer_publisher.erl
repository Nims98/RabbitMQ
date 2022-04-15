-module(rabbitConsumer_publisher).
-export([wavenet_test/1]).

-include("./_build/default/lib/amqp_client/include/amqp_client.hrl").

wavenet_test(Val) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
    %% Open a channel on the connection
    {ok, Channel} = amqp_connection:open_channel(Connection),

    %% Declare a queue

    % #'queue.declare_ok'{queue = Q} =
    %     amqp_channel:call(Channel, #'queue.declare'{}),

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
