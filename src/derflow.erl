%%% API module for derflow
-module(derflow).
-behaviour(application).
-export([start/2,
	 stop/1,
	 bind/2,
	 bind/3,
	 read/1,
	 lazyDeclare/0,
	 declare/0,
	 thread/3,
	 get_stream/1,
	 byNeed/2,
	 byNeed/3,
	 async_print_stream/1]).
start(normal, _Args) ->
    derflow_sup:start_link().

stop(_State) ->
    ok.

bind(Id, Value) ->
    derflow_server:bind(Id, Value).

bind(Id, Function, Args) ->
    derflow_server:bind(Id, Function, Args).

byNeed(Id, Value) ->
    derflow_server:byNeed(Id, Value).

byNeed(Id, Function, Args) ->
    derflow_server:byNeed(Id, Function, Args).

read(Id) ->
    derflow_server:read(Id).

declare() ->
    derflow_server:declare().

lazyDeclare() ->
    derflow_server:lazyDeclare().

thread(Module, Function, Args) ->
    spawn(Module, Function, Args).

get_stream(Stream)->
    internal_get_stream(Stream, []).

async_print_stream(Stream)->
    io:format("Stream: ~w~n", [Stream]),
    case read(Stream) of
	{nil, _} -> {ok, stream_read};
	{Value, Next} -> 
	    io:format("Value of stream: ~w~n",[Value]),
	    async_print_stream(Next)
    end.
    
%Internal functions

internal_get_stream(Head, Output) ->
    case read(Head) of
	{nil, _} -> Output;
	{Value, Next} -> 
	    internal_get_stream(Next, lists:append(Output, [Value]))
    end.
