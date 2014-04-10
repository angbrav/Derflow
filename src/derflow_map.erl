-module(derflow_map).

-export([put/3,get/2,find/2,is_key/2,erase/2]).


put(Key, Value, Dict) ->
    C0 = dict:erase(Key, Dict),
    dict:append(Key, Value, C0).

get(Key, Dict) ->
    ValueList = dict:fetch(Key, Dict),
    get_first(ValueList).

is_key(Key, Dict) ->
    dict:is_key(Key, Dict).

erase(Key, Dict) ->
    dict:erase(Key, Dict).

find(Key, Dict) ->
   case dict:find(Key, Dict) of
        {ok, ValueList} ->
           Value = get_first(ValueList),
           {ok, Value};
        error ->
           error
   end.



get_first(List) ->
  [T|_] = List,
  T.
