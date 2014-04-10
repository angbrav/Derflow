-module(derflow_server).
-behaviour(gen_server).

-export([start_link/0, code_change/3, terminate/2,handle_info/2]).
-export([bind/3,  wait/1, read/1, declare/0, execute_and_put/4]).
-export([init/1, handle_call/3, handle_cast/2]).

-record(state, {clock}).
-record(dv, {value, next, waitingThreads = [], bounded = false}). 

start_link() ->
    io:format("Server running~n"),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
	io:format("Init called~n"),
    	ets:new(dvstore, [set, named_table]),
    	{ok, #state{clock=0}}.

declare() ->
    gen_server:call(?MODULE, {declare}).

%bind(F,Arg) ->
%    gen_server:call(?MODULE, {bind, F, Arg}).

bind(Id, F, Arg) ->
    gen_server:call(?MODULE, {bind, Id, F, Arg}).

%bind(V) ->
%    gen_server:call(?MODULE, {bind, V}).
	
wait(X) ->
    gen_server:call(?MODULE, {wait, X}).

read(X) ->
    gen_server:call(?MODULE, {read, X}).

%handle_call({bind, X, V}, _From, State) ->
%    {Ch, Chs2} = alloc(Chs),

%    {reply, {ok}, Chs2};

handle_call({declare}, _From, State) ->
    	Clock = State#state.clock +1,
    	V = #dv{value=nil, next=nil},
	ets:insert(dvstore, Clock, V),
   	{reply, {id, Clock}, State#state{clock=Clock}};

%handle_call({bind, V}, _From, State) ->
%    Clock = State#state.clock +1,
%    KV = derflow_map:put(Clock, V, State#state.kv), 
%    {reply, {id, Clock}, State#state{clock=Clock, kv= KV}};

%handle_call({bind,F, Arg}, _From, State) ->
%    io:format("Bind request~n"),
%    Clock = State#state.clock +1,
%    KV= execute_and_put(F, Arg, State#state.kv, Clock),
%    {reply, {id, Clock}, State#state{clock=Clock, kv= KV}};

handle_call({bind,Id, F, Arg}, _From, State) ->
    io:format("Bind request~n"),
    Next = State#state.clock+1,
    spawn(derflow_server, execute_and_put, [F, Arg, Next, Id]),
    {reply, {id, Next}, State#state{clock=Next}};

%%%What if the Key does not exist in the map?%%%
handle_call({read,X}, From, State) ->
	V = ets:lookup(dvstore, X),
        Value = V#dv.value,
	Bounded = V#dv.bounded,
	%%%Need to distinguish that value is not calculated or is the end of a list%%%
	if Bounded == true ->
	 {reply, {Value, V#dv.next}, State};
	 true ->
	 WT = lists:append(V#dv.waitingThreads, [From]),
	 V1 = V#dv{waitingThreads=WT},
	 ets:delete(dvstore, X),
	 ets:insert(dvstore, X, V1),
         {noreply, State}
	end;

handle_call({wait, _X}, _From, State) ->
   %_V = wait_for_value(X, State#state.kv),
   {reply, {ok}, State}.

handle_cast({_}, State) ->
    {noreply, State}.

execute_and_put(F, Arg, Next, Key) ->
	V = ets:lookup(dvstore, Key),
	Threads = V#dv.waitingThreads,
	Value = F(Arg),
	V = #dv{value= Value, next =Next, bounded= true},
	ets:insert(dvstore, {Key, V}),
	replyToAll(Threads, Value, Next).

replyToAll([], _Value, _Next) ->
	ok;
replyToAll([H|T], Value, Next) ->
	gen_server:reply(H,{Value,Next}),
	replyToAll(T, Value, Next).

code_change(_, State, _) ->
    {ok, State}.

handle_info(_, State) ->
    {ok, State}.

terminate(normal, _State) ->
    ok.

%wait_for_value(X, KV)->
%       IsKey = derflow_map:is_key(X, KV),
%       if IsKey == true ->
%	 derflow_map:get(X, KV);
%	true ->
%    	  waitTime(500),
%          wait_for_value(X, KV)
%       end.
%
%waitTime(T) ->
%    receive
%    after (T) -> ok
%    end.
