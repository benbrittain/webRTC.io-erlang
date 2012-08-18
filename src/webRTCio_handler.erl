-module(webRTCio_handler).
-behaviour(cowboy_http_handler).
-behaviour(cowboy_http_websocket_handler).
-export([init/3, handle/2, terminate/2]).
-export([
        websocket_init/3, websocket_handle/3,
        websocket_info/3, websocket_terminate/3
    ]).


init({tcp, http}, Req, _Opts) ->
    lager:debug("Request: ~p", [Req]),
    {upgrade, protocol, cowboy_http_websocket}.


handle(Req, State) ->  
    lager:debug("Unexpected request: ~p", [Req]),  
    {ok, Req2} = cowboy_http_req:reply(404, [  
            {'Content-Type', <<"text/html">>}  
        ]),  
    {ok, Req2, State}.  

terminate(_Req, _State) ->
    lager:debug("terminate client"),
    webRTCio_server:unregister(self()),
    ok.

websocket_init(_Any, Req, []) ->
    Req2 = cowboy_http_req:compact(Req),
    {ok, Req2, 0, hibernate}.

%% Handle messoges being sent to the process
websocket_handle({text, Msg}, Req, State) ->
    JSON = json:decode(Msg),
    case JSON of
        {ok,{[{<<"eventName">>,<<"join_room">>}, {<<"data">>, {[{<<"room">>, Room}]}} ]}} ->
            lager:debug("New client"),
            webRTCio_server:register(self(),Room),
            webRTCio_server:get_peers(self(),Room);
        {ok,{[{<<"eventName">>,<<"send_answer">>},{<<"data">>, {[{<<"socketId">>,Pid},{<<"sdp">>,SDP}]}}]}} ->
            lager:debug("send_answer from ~p", [Pid]),
            webRTCio_server:send_answer(self(),Pid,SDP);
        {ok,{[{<<"eventName">>,<<"send_offer">>},{<<"data">>, {[{<<"socketId">>,Pid},{<<"sdp">>,SDP}]}}]}} ->
            lager:debug("send_offer from ~p", [Pid]),
            webRTCio_server:send_offer(self(),Pid,SDP);
        {ok,{[{<<"eventName">>,<<"send_ice_candidate">>},{<<"data">>, {[{<<"label">>,Label},{<<"candidate">>,Candidate},{<<"socketId">>,Pid}]}}]}} ->
            lager:debug("send_ice_candidate from ~p", [Pid]),
            webRTCio_server:send_ice_candidate(self(),Label,Candidate,Pid);
        {ok,{[{<<"eventName">>,<<"chat_msg">>},{<<"messages">>,Message},{<<"room">>,Room},{<<"color">>,Color}]}} ->
            webRTCio_server:chatMsg(self(),Message,Room,Color);
        _ ->
            webRTCio_server:msg(Msg)
    end,
    {ok, Req, State};

websocket_handle(Any, Req, State) ->
    lager:debug("Any: ~p", [Any]),
    {ok, Req, State}.

%% send messages back to the client
websocket_info({new_peer_connected, Pid}, Req, State) ->
    lager:debug("PID new_peer_connected ~p", [Pid]),
    {ok, JSON} = json:encode({[{<<"eventName">>,<<"new_peer_connected">>},{<<"data">>, {[ {<<"socketId">>, list_to_binary(pid_to_list(Pid))}]}}]}),
    {reply, {text, JSON}, Req, State, hibernate};

websocket_info({receive_ice_candidate, Label, Candidate, Pid}, Req, State) ->
    lager:debug("receive_ice_candidate ~p", [Pid]),
    {ok, JSON} = json:encode({[{<<"eventName">>,<<"receive_ice_candidate">>}, {<<"data">>, {[{<<"label">>, Label}, {<<"candidate">>, Candidate},{<<"socketId">>, list_to_binary(pid_to_list(Pid))}]}} ]}),
    {reply, {text, JSON}, Req, State, hibernate};

websocket_info({remove_peer_connected, Pid}, Req, State) ->
    lager:debug("remove_peer_connected ~p", [Pid]),
    {ok, JSON} = json:encode({[{<<"eventName">>,<<"remove_peer_connected">>}, {<<"data">>, {[{<<"socketId">>, list_to_binary(pid_to_list(Pid))}]}} ]}),
    {reply, {text, JSON}, Req, State, hibernate};

websocket_info({receive_offer, SDP, Pid}, Req, State) ->
    lager:debug("receive_offer ~p", [Pid]),
    {ok, JSON} = json:encode({[{<<"eventName">>,<<"receive_offer">>}, {<<"data">>, {[{<<"sdp">>, SDP},{<<"socketId">>, list_to_binary(pid_to_list(Pid))}]}} ]}),
    {reply, {text, JSON}, Req, State, hibernate};

websocket_info({receive_answer, SDP, Pid}, Req, State) ->
    lager:debug("receive_answer ~p", [Pid]),
    {ok, JSON} = json:encode({[{<<"eventName">>,<<"receive_answer">>}, {<<"data">>, {[{<<"sdp">>, SDP},{<<"socketId">>, list_to_binary(pid_to_list(Pid))}]}} ]}),
    {reply, {text, JSON}, Req, State, hibernate};

websocket_info({get_peers, Connections}, Req, State) ->
    lager:debug("PID get_peers ~p", [Connections]),
    {ok, JSON} = json:encode({[{<<"eventName">>,<<"get_peers">>}, {<<"data">>, {[{<<"connections">>, Connections}]}} ]}),
    {reply, {text, JSON}, Req, State, hibernate};

websocket_info({chatMsg, Pid, Msg, Room, Color}, Req, State) ->
    {ok, JSON} = json:encode({[{<<"eventName">>,<<"receive_chat_msg">>}, {<<"messages">>, Msg}, {<<"color">>, Color}]}),
    {reply, {text, JSON}, Req, State, hibernate};

websocket_info(_Info, Req, State) ->
    {ok, Req, State, hibernate}.

%% remove from rooms
websocket_terminate(_Reason, _Req, State) ->
    lager:debug(State),
    lager:debug("websocket terminate client"),
    webRTCio_server:unregister(self()),
    ok.
