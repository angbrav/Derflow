%%% API module for derflow
-module(derflow).
-behaviour(application).
-export([start/2,
	 stop/1,
	 bind/2,
	 newBind/1,
	 read/1,
	 wait/1]).
start(normal, _Args) ->
    derflow_sup:start_link().

stop(_State) ->
    ok.

bind(Var, Value) ->
    derflow_server:bind(Var, Value).

newBind(Value) ->
    derflow_server:newBind(Value).

read(Var) ->
    derflow_server:read(Var).

wait(Var) ->
    derflow_server:wait(Var).
