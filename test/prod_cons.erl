-module(prod_cons).
-export([test1/0, producer/3, consumer/3]).

test1() ->
    % create a variable Stream1 and have a producer write to it
    {id, Stream1}=derflow:declare(),
    derflow:thread(prod_cons,producer,[0,10,Stream1]),

    % create a variable Stream2 and write transformations of values read from Stream1
    {id, Stream2}=derflow:declare(),
    derflow:thread(prod_cons,consumer,[Stream1,fun(X) -> X + 5 end,Stream2]),
    derflow:async_print_stream(Stream2).
    %L = derflow:get_stream(Stream2),
    %L.
    %io:format("Output: ~w~n",[L]).
    %Stream2.

producer(Init, N, Output) ->
    if (N>0) ->
    timer:sleep(1000),
    {id, Next} = derflow:bind(Output, Init),
    producer(Init + 1, N-1,  Next);
    true ->
    derflow:bind(Output, nil)
    end.

consumer(InStream, F, OutStream) ->
    case derflow:read(InStream) of
    {nil, _} ->
        derflow:bind(OutStream, nil);
    {Value, Next} ->
        {id, NextOutput} = derflow:bind(OutStream, F, Value),
        consumer(Next, F, NextOutput)
    end.
