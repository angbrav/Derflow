-module(derflow_server).
-behaviour(gen_server).

-export([start_link/0]).
-export([bind/2, bind/1, wait/1, read/1, declare/1]).
-export([init/1, handle_call/3, handle_cast/2]).

-record(state, {clock, kv}).
-record(dv, {id, value, next, waitingThreads}). 

start_link() ->
    io:format("Server running~n"),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
    io:format("Init called~n"),
    {ok, #state{clock=0, kv= dict:new()}}.

declare() ->
    gen_server:call(?MODULE, {declare}).

bind(F,Arg) ->
    gen_server:call(?MODULE, {bind, F, Arg}).

bind(V) ->
    gen_server:call(?MODULE, {bind, V}).
	
wait(X) ->
    gen_server:call(?MODULE, {wait, X}).

read(X) ->
    gen_server:call(?MODULE, {read, X}).

%handle_call({bind, X, V}, _From, State) ->
%    {Ch, Chs2} = alloc(Chs),

%    {reply, {ok}, Chs2};

handle_call({declare}, _From, State) ->
    Clock = State#state.clock +1,
    {reply, {id, Clock}, State#state{clock=Clock}};

handle_call({bind, V}, _From, State) ->
    Clock = State#state.clock +1,
    KV = derflow_map:put(Clock, V, State#state.kv), 
    {reply, {id, Clock}, State#state{clock=Clock, kv= KV}};

handle_call({bind,F, Arg}, _From, State) ->
    io:format("Bind request~n"),
    Clock = State#state.clock +1,
    KV= execute_and_put(F, Arg, State#state.kv, Clock),
    {reply, {id, Clock}, State#state{clock=Clock, kv= KV}};

handle_call({read,X}, _From, State) ->
   V = wait_for_value(X, State#state.kv),
    {reply, {V}, State};

handle_call({wait, X}, _From, State) ->
   _V = wait_for_value(X, State#state.kv),
   {reply, {ok}, State}.

handle_cast({_}, State) ->
    {noreply, State}.


execute_and_put(F, Arg, KV, Key) ->
	V = F(Arg),
	derflow_map:put(Key,V, KV).

wait_for_value(X, KV)->
       IsKey = derflow_map:is_key(X, KV),
       if IsKey == true ->
	 derflow_map:get(X, KV);
	true ->
    	  waitTime(500),
          wait_for_value(X, KV)
       end.

waitTime(T) ->
    receive
    after (T) -> ok
    end.
