-module(webRTCio_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).
%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
%    Dispatch = [{'_', [
%                {'_', webRTCio_handler, []}
%    ]}],
%    lager:set_loglevel(lager_console_backend, debug),
%    cowboy:start_listener(webRTCio_websocket, 100,
%        cowboy_tcp_transport, [{port, 8080}],
%        cowboy_http_protocol, [{dispatch, Dispatch}]
%    ),
%    lager:set_loglevel(lager_console_backend, debug),
    lager:set_loglevel(lager_console_backend, debug),
    webRTCio_sup:start_link().

stop(_State) ->
    ok.
