-module(bounded_buffer).
-export([test1/0, producer/3, buffer/3, consumer/2]).

test1() ->
    {id, S1}=derflow:lazyDeclare(),
    derflow:thread(bounded_buffer,producer,[0,10,S1]),
    consumer(S1, fun(X) -> X*2 end).
    %{id, S2}=derflow:lazyDeclare(), 
    %buffer(S1, 4, S2),
    %derflow:thread(bounded_buffer,test_consumer,[S2]).
    %test_consumer(S1).
	%derflow:thread(bounded_buffer,test_comsumer,[S1,fun(X) -> X + 5 end,S2]),
    %derflow:async_print_stream(S2).
    %L = derflow:get_stream(S2),
    %L.
    %io:format("Output: ~w~n",[L]).
    %S2.

producer(Init, N, Output) ->
    if (N>0) ->
        {id, Next} = derflow:byNeed(Output, Init),
        producer(Init + 1, N-1,  Next);
    true ->
        derflow:bind(Output, nil)
    end.

loop(S1, S2, End) ->
    derflow:waitNeeded(S2),
    {Value, S1Next} = derflow:read(S1),
    {Value, S2Next} = derflow:bind(S2, Value),
    {id, EndNext} = derflow:wait(End),
    loop(S1Next, S2Next, EndNext).    
    

buffer(S1, Size, S2) ->
    End = drop_list(S1, Size).
    loop(S1, S2, End).

drop_list(S, Size) ->
    if Size == 0 ->
	S;
      true ->
       	{_Value,Next}=derflow:read(S),
    	drop_list(Next, Size-1)
    end.

consumer(S2,F) ->
    case derflow:read(S2) of
	{nil, _} ->
	   io:format("Reading end~n");
	{Value, Next} ->
	   io:format("Consume ~w, Get ~w ~n",[Value, F(Value)]),
	   timer:sleep(1000),
	   consumer(Next, F)
    end.


%consumer(S1, F, S2) ->
%    case derflow:read(S1) of
%        {nil, _} ->
%            derflow:bind(S2, nil);
%        {Value, Next} ->
%            {id, NextOutput} = derflow:byNeed(S2, F, Value),
%            consumer(Next, F, NextOutput)
%    end.
