-module(derflow_server).
-behaviour(gen_server).

-export([start_link/0, code_change/3, terminate/2,handle_info/2]).
-export([bind/3,  bind/2, waitNeeded/1, wait/1, read/1, declare/0, execute_and_put/4, put/3]).
-export([init/1, handle_call/3, handle_cast/2]).

-record(state, {clock}).
-record(dv, {value, next, waitingThreads = [], creator, lazy=false,bounded = false}). 


%%% API functions


start_link() ->
    io:format("Server running~n"),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_Args) ->
    io:format("Init called~n"),
        ets:new(dvstore, [set, named_table, public, {write_concurrency, true}]),
        {ok, #state{clock=0}}.


% declare a new variable
% returns the new variable's Id, an Erlang term
declare() ->
    gen_server:call(?MODULE, {declare}).


% bind a function result to a variable
% Id: the variable id provided by declare/0
% F: the function to execute
% Arg: function arguments (TODO: what should they look like? why not just put in a fun)
bind(Id, F, Arg) ->
    gen_server:call(?MODULE, {bind, Id, F, Arg}).


% bind the variable Id to Value
% Id: the variable id provided by declare/0
% Value: an erlang term
bind(Id, Value) ->
    gen_server:call(?MODULE, {bind, Id, Value}).


% registers the calling process as wanting a notification when variable Id is bound
% Id: the variable id provided by declare/0
waitNeeded(Id) ->
    gen_server:call(?MODULE, {waitNeeded, Id}).

% TODO: what's this for
% TODO: unimplemented?
wait(X) ->
    gen_server:call(?MODULE, {wait, X}).


% read dataflow variable X; block until bound if not yet bound
% TODO: is X the same as Id from declare ? rename?
read(X) ->
    gen_server:call(?MODULE, {read, X}).


%%% end API functions




handle_call({declare}, _From, State) ->
        Clock = State#state.clock +1,
        V = #dv{value=empty, next=empty},
    ets:insert(dvstore, {Clock, V}),
    {reply, {id, Clock}, State#state{clock=Clock}};

handle_call({next, Id}, _From, State)->
    io:format("Requesting for next~w~n",[Id]),
    Next = State#state.clock+1,
    ets:insert(dvstore, {Next, #dv{value=empty, next=empty}}),
    {reply, {id, Next}, State#state{clock=Next}};


handle_call({bind,Id, F, Arg}, _From, State) ->
    %io:format("Bind request~n"),
    Next = State#state.clock+1,
    ets:insert(dvstore, {Next, #dv{value=empty, next=empty}}),
    spawn(derflow_server, execute_and_put, [F, Arg, Next, Id]),
    {reply, {id, Next}, State#state{clock=Next}};

handle_call({bind,Id, Value}, _From, State) ->
    %io:format("Bind request~n"),
    Next = State#state.clock+1,
    ets:insert(dvstore, {Next, #dv{value=empty, next=empty}}),
    spawn(derflow_server, put, [Value, Next, Id]),
    {reply, {id, Next}, State#state{clock=Next}};


handle_call({waitNeeded, Id}, From, State) ->
    [{_Key,V}] = ets:lookup(dvstore, Id),
    case V#dv.waitingThreads of [_H|_T] ->
        {reply, ok, State};
        _ ->
    ets:insert(dvstore, {Id, V#dv{lazy=true, creator=From}}),
        {noreply, State}
    end;

%%% TODO: What if the Key does not exist in the map?%%%
handle_call({read,X}, From, State) ->
    [{_Key,V}] = ets:lookup(dvstore, X),
    Value = V#dv.value,
    Bounded = V#dv.bounded,
    Creator = V#dv.creator,
    Lazy = V#dv.lazy,
    %%% TODO: Need to distinguish that value is not calculated or is the end of a list%%%
    if Bounded == true ->
      {reply, {Value, V#dv.next}, State};
    true ->
        if Lazy == true ->
            WT = lists:append(V#dv.waitingThreads, [From]),
                V1 = V#dv{waitingThreads=WT},
                ets:insert(dvstore, {X, V1}),
                gen_server:reply(Creator, ok),
                {noreply, State};
        true ->
            WT = lists:append(V#dv.waitingThreads, [From]),
            V1 = V#dv{waitingThreads=WT},
            ets:insert(dvstore, {X, V1}),
            {noreply, State}
        end
    end;


% TODO: unimplemented?
handle_call({wait, _X}, _From, State) ->
   %_V = wait_for_value(X, State#state.kv),
   {reply, {ok}, State}.

handle_cast({_}, State) ->
    {noreply, State}.


%putLazy(Value, Next, Key, From) ->
%   %io:format("Put lazy ~w~n",[Key]),
%   V1 = #dv{value= Value, next =Next, bounded= true, lazy = true, creator = From},
%   ets:insert(dvstore, {Key, V1}).

%Bind the key with the result (either by assignment or calculating)
%executeLazy(Key, V) ->
%   %io:format("Execute lazy ~w~n",[Key]),
%   Value= V#dv.value,
%   case Value of {F, Arg} ->
%      Result = F(Arg);
%      _ ->
%      Result = Value
%   end,
%   V1 = V#dv{value= Result, lazy = false, waitingThreads= []},
%   ets:insert(dvstore, {Key, V1}),
%   Result.

put(Value, Next, Key) ->
    [{_Key,V}] = ets:lookup(dvstore, Key),
    Threads = V#dv.waitingThreads,
    V1 = #dv{value= Value, next =Next, bounded= true,lazy=false},
    ets:insert(dvstore, {Key, V1}),
    replyToAll(Threads, Value, Next).

execute_and_put(F, Arg, Next, Key) ->
    [{_Key,V}] = ets:lookup(dvstore, Key),
    Threads = V#dv.waitingThreads,
    Value = F(Arg),
    V1 = #dv{value= Value, next =Next, bounded= true, lazy=false},
    ets:insert(dvstore, {Key, V1}),
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
%    derflow_map:get(X, KV);
%   true ->
%         waitTime(500),
%          wait_for_value(X, KV)
%       end.
%
%waitTime(T) ->
%    receive
%    after (T) -> ok
%    end.
