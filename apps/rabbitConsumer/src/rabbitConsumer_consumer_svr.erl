-module(rabbitConsumer_consumer_svr).

-include("./_build/default/lib/amqp_client/include/amqp_client.hrl").
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([init/1]).
-record(state, {dummy, channel}).

start_link() ->
    gen_server:start_link({local, server}, ?MODULE, [], []).

init(_Args) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{}),
    %% Open a channel on the connection
    {ok, Channel} = amqp_connection:open_channel(Connection),
    State = #state{dummy = 1, channel = Channel},

    %% Declare queues
    Queues = [queue_1, queue_2, queue_3, queue_4, queue_5],
    %% Declare exchange

    #'exchange.declare_ok'{} = amqp_channel:call(State#state.channel, #'exchange.declare'{
        exchange = <<"my_exchange">>,
        type = <<"fanout">>
    }),
    declare_queues(Queues, State),

    loop(Channel),
    {ok, State}.

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
            {_, _, M} = Content,
            io:fwrite("Received --->  "),
            io:fwrite(M),
            io:fwrite("~n"),
            %% Ack the message
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
            %% Loop
            loop(Channel)
    end.

declare_queues([], _) ->
    {ok, done};
declare_queues([Queue | T], State) ->
    %% Declare queues
    Declare = #'queue.declare'{queue = atom_to_binary(Queue)},
    #'queue.declare_ok'{} = amqp_channel:call(State#state.channel, Declare),
    #'basic.consume_ok'{consumer_tag = Tag} =
        amqp_channel:call(State#state.channel, #'basic.consume'{queue = atom_to_binary(Queue)}),

    %% Binding
    #'queue.bind_ok'{} = amqp_channel:call(State#state.channel, #'queue.bind'{
        queue = atom_to_binary(Queue),
        exchange = <<"my_exchange">>,
        routing_key = atom_to_binary(Queue)
    }),
    declare_queues(T, State).
