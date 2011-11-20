-module(simple_ws_server).

-behaviour(cowboy_http_handler).
-behaviour(cowboy_http_websocket_handler).

-define(SEND_IDLE,1).

-export([start/0]).
-export([init/3, handle/2, terminate/2]).
-export([websocket_init/3, websocket_handle/3, websocket_info/3, websocket_terminate/3]).


dispatch() ->
    [
     {'_', [
            {'_', simple_ws_server, []}
           ]
     }
    ].

init(_Any, _Req, _Opts) ->
    {upgrade, protocol, cowboy_http_websocket}.

handle(_Req, _State) ->
	exit(badarg).

terminate(_Req, _State) ->
	exit(badarg).

-ifdef(SEND_IDLE).
start_timer() ->
    erlang:start_timer(25000, self(), idlemsg).
-else.
start_timer() ->
    ok.
-endif.

websocket_init(_, Req, _) ->
    start_timer(),
    {ok,cowboy_http_req:compact(Req),undefined}.

websocket_handle(_, Req, State) ->
    {ok,Req,State}.

websocket_info({timeout,_,_}, Req, State) ->
    start_timer(),
    {reply, {text, <<"{}">>}, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
	ok.

start() ->
    {ok,_}=cowboy:start_listener(
             simple_ws_listener,
             1024,
             cowboy_tcp_transport, [{port, 8003}],
             cowboy_http_protocol, [{dispatch, dispatch()},
                                    {timeout, 60000}]).
