%%======================================================================
%%
%% Cherly
%%
%% Copyright (c) 2012 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% ---------------------------------------------------------------------
%% Cherly Server
%% @doc
%% @end
%%======================================================================
-module(cherly_server).
-author("Yosuke Hara").

-behaviour(gen_server).

-include("cherly.hrl").
-include_lib("eunit/include/eunit.hrl").

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% API
-export([start_link/1, stop/0, get/1, put/2, delete/1, stats/0, items/0, size/0]).

-record(state, {handler,
                total_cache_size = 0 :: integer(),
                stats_gets	     = 0 :: integer(),
                stats_puts	     = 0 :: integer(),
                stats_dels	     = 0 :: integer(),
                stats_hits       = 0 :: integer()
               }).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% Function: {ok,Pid} | ignore | {error, Error}
%% Description: Starts the server.
start_link(CacheSize) ->
    ?debugVal(CacheSize),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [CacheSize], []).


%% Function: -> ok
%% Description: Manually stops the server.
stop() ->
    gen_server:cast(?MODULE, stop).


%% @doc Retrieve a value associated with a specified key
%%
-spec(get(binary()) ->
             undefined | binary() | {error, any()}).
get(Key) ->
    gen_server:call(?MODULE, {get, Key}).


%% @doc Insert a key-value pair into the cherly
%%
-spec(put(binary(), binary()) ->
             ok | {error, any()}).
put(Key, Value) ->
    gen_server:call(?MODULE, {put, Key, Value}).


%% @doc Remove a key-value pair by a specified key into the cherly
-spec(delete(binary()) ->
             ok | {error, any()}).
delete(Key) ->
    gen_server:call(?MODULE, {delete, Key}).


%% @doc Return server's state
-spec(stats() ->
             any()).
stats() ->
     gen_server:call(?MODULE, {stats}).


%% @doc Return server's items
-spec(items() ->
             any()).
items() ->
     gen_server:call(?MODULE, {items}).


%% @doc Return server's summary of cache size
-spec(size() ->
             any()).
size() ->
     gen_server:call(?MODULE, {size}).


%%====================================================================
%% GEN_SERVER CALLBACKS
%%====================================================================
init([CacheSize]) ->
    {ok, Handler} = cherly:start(CacheSize),
    {ok, #state{total_cache_size = CacheSize,
                handler           = Handler}}.

handle_call({get, Key}, _From, State = #state{handler    = Handler,
                                              stats_gets = Gets,
                                              stats_hits = Hits}) ->
    case catch cherly:get(Handler, Key) of
        {'EXIT', Cause} ->
            {reply, {error, Cause}, State};
        not_found ->
            {reply, not_found, State#state{stats_gets = Gets + 1}};
        {ok, Value} ->
            {reply, {ok, Value}, State#state{stats_gets = Gets + 1,
                                             stats_hits = Hits + 1}}
    end;

handle_call({put, Key, Val}, _From, State = #state{handler    = Handler,
                                                   stats_puts = Puts}) ->
    case catch cherly:put(Handler, Key, Val) of
        {'EXIT', Cause} ->
            {reply, {error, Cause}, State};
        ok ->
            {reply, ok, State#state{stats_puts = Puts + 1}}
    end;

handle_call({delete, Key}, _From, State = #state{handler    = Handler,
                                                 stats_dels = Dels}) ->
    case catch cherly:remove(Handler, Key) of
        {'EXIT', Cause} ->
            {reply, {error, Cause}, State};
        ok ->
            {reply, ok, State#state{stats_dels = Dels + 1}}
    end;

handle_call({stats}, _From, State = #state{handler    = Handler,
                                           stats_hits = Hits,
                                           stats_gets = Gets,
                                           stats_puts = Puts,
                                           stats_dels = Dels}) ->
    {ok, Items} = cherly:items(Handler),
    {ok, Size}  = cherly:size(Handler),
    Stats = #cache_stats{hits        = Hits,
                         gets        = Gets,
                         puts        = Puts,
                         dels        = Dels,
                         records     = Items,
                         cached_size = Size},
    {reply, {ok, Stats}, State};

handle_call({items}, _From, #state{handler = Handler} = State) ->
    Reply = cherly:items(Handler),
    {reply, Reply, State};

handle_call({size}, _From, #state{handler = Handler} = State) ->
    Reply  = cherly:size(Handler),
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, undefined, State}.

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.


%% ----------------------------------------------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to terminate. When it returns,
%% the gen_server terminates with Reason. The return value is ignored.
%% ----------------------------------------------------------------------------------------------------------
terminate(_Reason, _State) ->
    terminated.


%% ----------------------------------------------------------------------------------------------------------
%% Function: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed.
%% ----------------------------------------------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
