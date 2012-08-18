-module(webRTCio_server).

-behaviour(gen_server).

%% API
-export([start_link/0, send_answer/3, send_ice_candidate/4, send_offer/3, get_peers/2, register/2, unregister/1, msg/1, chatMsg/4]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
     terminate/2, code_change/3]).
-import(dict).
-define(SERVER, ?MODULE). 

%%-record(state, {rooms = []}).

%%%===================================================================
%%% API
%%%===================================================================

register(Pid, Room) ->
    gen_server:cast(?SERVER, {register, Pid, Room}).

unregister(Pid) ->
    lager:debug("unregistered ~p", [Pid]),
    gen_server:cast(?SERVER, {unregister, Pid}).

msg(Msg) ->
    gen_server:cast(?SERVER, {msg, Msg}).

chatMsg(Pid, Msg, Room, Color) ->
    gen_server:cast(?SERVER, {chatMsg, Pid, Msg, Room, Color}).

get_peers(Pid, Room) ->
    gen_server:cast(?SERVER, {get_peers, Pid, Room}).

send_offer(Self, Pid, SDP) ->
    gen_server:cast(?SERVER, {send_offer, Self, Pid, SDP}).

send_ice_candidate(Self, Label, Candidate, Pid) ->
    gen_server:cast(?SERVER, {send_ice_candidate, Self, Label, Candidate, Pid}).

send_answer(Self, Pid, SDP) ->
    gen_server:cast(?SERVER, {send_answer,Self, Pid, SDP}).



%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    Dispatch = [{'_', [
                {'_', webRTCio_handler, []}
    ]}],
    lager:set_loglevel(lager_console_backend, debug),
    cowboy:start_listener(webRTCio_websocket, 100,
        cowboy_tcp_transport, [{port, 8080}],
        cowboy_http_protocol, [{dispatch, Dispatch}]
    ),
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    State = dict:new(),
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
%%handle_cast({register, Pid, Room}, #state{cons = Cons} = State) ->

handle_cast({register, Pid, Room}, State) ->
    lager:debug("---Making new Connection with Pid ~p in Room ~p", [Pid, Room]),
%%    lager:debug("Pid is: ~p", [Pid]),
%%    lager:debug("Room is: ~p", [Room]),
    case dict:is_key(Room,State) of
        false -> 
            State2 = dict:store(Room, [], State),
            FinalState = dict:append(Room, Pid, State2),
            lager:debug("State is: ~p", [FinalState]),
            {noreply, FinalState};
        true ->
            State2 = State,
            FinalState = dict:append(Room, Pid, State2),
    %%        lager:debug("State is: ~p", [FinalState]),
            {noreply, FinalState}
    end;

%%handle_cast({register, Pid}, #state{cons = Cons} = State) ->
    %%State2 =   #state{dict = [{Room, [Pid]}
%%    State2 = State#state{room = [{"yeq67ycr", [Pid]}]},
 %%   State#state{cons = [Pid | Cons]},
handle_cast({unregister, Pid, Room}, State) ->
    lager:debug("State is: ~p", [State]),
    lager:debug("Pid is: ~p", [Pid]),
    Room = dict:fetch(Room, State),
    lager:debug("Room is: ~p", [Room]),
    {noreply, State};

handle_cast({get_peers, MyPid, Room}, State) ->
    Rooms = dict:fetch(Room, State),
    lager:debug("get_peers ~p", [Rooms]),
    %MyPid ! {get_peers, MyPid},
    lists:foreach(fun (Pid) ->
                case (Pid =:= MyPid) of
                    false ->    
                        Pid ! {new_peer_connected, MyPid};
                    true  ->    lager:debug("~p === ~p", [Pid,MyPid])
                end
          end, Rooms),
    Cons = lists:map(fun(X) -> pid_to_list(X) end, Rooms),
%%    lager:debug("Cons is: ~p", [Cons]),
%%    lager:debug("PID is: ~p", [pid_to_list(MyPid)]),
    Connections = Cons -- [pid_to_list(MyPid)],
    lager:debug("Connections is: ~p", [Connections]),
    MyPid ! {get_peers, lists:map(fun(X) -> list_to_binary(X) end, Connections)},
    {noreply, State};
handle_cast({send_ice_candidate, Self, Label, Candidate, Pid}, State) ->
    lager:debug("Pid is: ~p", [Pid]),
    list_to_pid(binary_to_list(Pid)) ! {receive_ice_candidate, Label, Candidate, Self},
    {noreply, State};
handle_cast({send_offer, Self, Pid, SDP}, State) ->
    lager:debug("Pid is: ~p", [Pid]),
    list_to_pid(binary_to_list(Pid)) ! {receive_offer, SDP, Self},
    {noreply, State};
handle_cast({send_answer, Self, Pid, SDP}, State) ->
    lager:debug("Pid is: ~p", [Pid]),
    list_to_pid(binary_to_list(Pid)) ! {receive_answer, SDP, Self},
    {noreply, State};
     
handle_cast({chatMsg,MyPid, Msg, Room, Color}, State) ->
    lager:debug("myPid is ~p", [MyPid]),
    Rooms = dict:fetch(Room, State),
    lager:debug(Rooms),
    lists:foreach(fun (Pid) ->
                case (Pid =:= MyPid) of
                    false ->    Pid ! {chatMsg, Msg, Room, Color};
                    true  ->    lager:debug("sending message to peer ~p", [Pid])
                end
          end, Rooms),
    {noreply, State};
%%handle_cast({msg, Msg}, #state{cons = Cons} = State) ->
%%    lists:foreach(fun (Pid) ->
%%              Pid ! {msg, Msg}
%%          end, Cons),
%%    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
