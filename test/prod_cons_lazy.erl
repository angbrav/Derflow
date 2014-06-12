-module(prod_cons_lazy).
-export([test1/0, producer/3, consumer/3]).

test1() ->
    {id, S1}=derflow:lazyDeclare(),
    derflow:thread(prod_cons_lazy,producer,[0,10,S1]),
    {id, S2}=derflow:lazyDeclare(),
    derflow:thread(prod_cons_lazy,consumer,[S1,fun(X) -> X + 5 end,S2]),
    derflow:async_print_stream(S2).
    %L = derflow:get_stream(S2),
    %L.
    %io:format("Output: ~w~n",[L]).
    %S2.

producer(Init, N, Output) ->
    if (N>0) ->
    timer:sleep(1000),
    {id, Next} = derflow:byNeed(Output, Init),
    producer(Init + 1, N-1,  Next);
    true ->
    derflow:bind(Output, nil)
    end.

consumer(S1, F, S2) ->
    case derflow:read(S1) of
    {nil, _} ->
        derflow:bind(S2, nil);
    {Value, Next} ->
        {id, NextOutput} = derflow:byNeed(S2, F, Value),
        consumer(Next, F, NextOutput)
    end.
