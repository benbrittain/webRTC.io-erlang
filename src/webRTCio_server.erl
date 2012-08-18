-module(webRTCio_server).
-behaviour(gen_server).

%%%===================================================================
%%% WebRTC.io specific API
%%%===================================================================
-export([start_link/0, send_answer/3, send_ice_candidate/4, send_offer/3, get_peers/2, register/2, unregister/1]). 

%%%===================================================================
%%% User defined API
%%%===================================================================
-export([chatMsg/4]).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
     terminate/2, code_change/3]).

%% Need a dictionary for room storage
-import(dict).

-define(SERVER, ?MODULE). 

%%%===================================================================
%%% WebRTC.io required functions
%%%===================================================================

register(Pid, Room) ->
    gen_server:cast(?SERVER, {register, Pid, Room}).

unregister(Pid) ->
    lager:debug("unregistered ~p", [Pid]),
    gen_server:cast(?SERVER, {unregister, Pid}).

get_peers(Pid, Room) ->
    gen_server:cast(?SERVER, {get_peers, Pid, Room}).

send_offer(Self, Pid, SDP) ->
    gen_server:cast(?SERVER, {send_offer, Self, Pid, SDP}).

send_ice_candidate(Self, Label, Candidate, Pid) ->
    gen_server:cast(?SERVER, {send_ice_candidate, Self, Label, Candidate, Pid}).

send_answer(Self, Pid, SDP) ->
    gen_server:cast(?SERVER, {send_answer,Self, Pid, SDP}).

chatMsg(Pid, Msg, Room, Color) ->
    gen_server:cast(?SERVER, {chatMsg, Pid, Msg, Room, Color}).

start_link() ->
    Dispatch = [{'_', [
                {'_', webRTCio_handler, []}
    ]}],
    %% Turn on or off logging by commenting
    lager:set_loglevel(lager_console_backend, debug),
    cowboy:start_listener(webRTCio_websocket, 100,
        cowboy_tcp_transport, [{port, 8080}],
        cowboy_http_protocol, [{dispatch, Dispatch}]
    ),
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    State = dict:new(),
    {ok, State}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast({register, Pid, Room}, State) ->
    lager:debug("---Making new Connection with Pid ~p in Room ~p", [Pid, Room]),
    lager:debug("State is: ~p", [State]),
    case dict:is_key(Room,State) of
        false -> 
            State2 = dict:store(Room, [], State),
            lager:debug("State2 is: ~p", [State2]),
            FinalState = dict:append(Room, Pid, State2),
            lager:debug("State is: ~p", [FinalState]),
            {noreply, FinalState};
        true ->
            State2 = State,
            lager:debug("State2 is: ~p", [State2]),
            FinalState = dict:append(Room, Pid, State2),
            lager:debug("State is: ~p", [FinalState]),
            {noreply, FinalState}
    end;

handle_cast({unregister, Pid}, State) ->
    State2 = lists:map(fun(Room) ->
                case lists:member(Pid, dict:fetch(Room,State)) of
                    true -> 
                        NewRoom = dict:fetch(Room,State) -- [Pid],
                        lists:map(fun(OtherPid) ->
                                    OtherPid ! {remove_peer_connected, Pid} end, NewRoom),
                        dict:store(Room, NewRoom, State);
                    false -> 
                        lager:debug("~p is dunno ~p", [Pid,Room])
                end
        end,
    dict:fetch_keys(State)),
    [FinalState] = State2,
    {noreply, FinalState};

handle_cast({get_peers, MyPid, Room}, State) ->
    Rooms = dict:fetch(Room, State),
    lager:debug("get_peers ~p", [Rooms]),
    lists:foreach(fun (Pid) ->
                case (Pid =:= MyPid) of
                    false ->    
                        Pid ! {new_peer_connected, MyPid};
                    true  ->    lager:debug("~p === ~p", [Pid,MyPid])
                end
          end, Rooms),
    Cons = lists:map(fun(X) -> pid_to_list(X) end, Rooms),
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

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
