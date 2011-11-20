-module(simple_ws_server2).

-behaviour(cowboy_http_handler).
-behaviour(cowboy_http_websocket_handler).

-define(SEND_IDLE,1).

-export([start/0]).
-export([pinger/0]).
-export([init/3, handle/2, terminate/2]).
-export([websocket_init/3, websocket_handle/3, websocket_info/3, websocket_terminate/3]).


dispatch() ->
    [
     {'_', [
            {'_', simple_ws_server2, []}
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
    pinger ! {newclient, self()},
    {ok,cowboy_http_req:compact(Req),undefined,hibernate}.

websocket_handle(_, Req, State) ->
    {ok,Req,State,hibernate}.

websocket_info(idlemsg, Req, State) ->
    {reply, {text, <<"{}">>}, Req, State,hibernate}.

websocket_terminate(_Reason, _Req, _State) ->
                             ok.

pinger() ->
    start_timer(),
    pinger_loop([]).

pinger_loop(L) ->
    receive
        {timeout,_,idlemsg} ->
            start_timer(),
            StartTime=now(),
            lists:foreach(fun(P) -> P ! idlemsg end, L),
            EndTime=now(),
            io:format("Broadcast ping took ~p~n", [timer:now_diff(EndTime, StartTime) / 100000]),
            pinger_loop(L);
        {newclient, P} ->
            pinger_loop([P|L])
    end.

start() ->
    PingerPid = spawn(fun pinger/0),
    register(pinger, PingerPid),
    {ok,_}=cowboy:start_listener(
             simple_ws_listener,
             1024,
             cowboy_tcp_transport, [{port, 8003}, {max_connections, 512*1024}],
             cowboy_http_protocol, [{dispatch, dispatch()},
                                    {timeout, 60000}]).


