-module(derflow_sup).
-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, derflow}, ?MODULE, []).

init(_Args) ->
    Server = { derflow_server,
                  {derflow_server, start_link, []},
                  permanent, 5000, worker, [derflow_server]},
    { ok,
        { {one_for_one, 5, 10},
          [Server]}}.
