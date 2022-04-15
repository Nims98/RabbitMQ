-module(rabbitConsumer_consumer_svr).

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
            %% (some work here)
            R = io_lib:format("~p", [Content]),
            lists:flatten(R),

            io:fwrite("Received\n"),
            io:fwrite(R),
            %% Ack the message
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),

            %% Loop
            loop(Channel)
    end.
