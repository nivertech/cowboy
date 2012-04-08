%% Copyright (c) 2011, Loïc Hoguin <essen@dev-extend.eu>
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

%% @private
-module(cowboy_acceptor).

-export([start_link/9]). %% API.
-export([acceptor/12]). %% Internal.

%% API.

-spec start_link(inet:socket(), module(), module(), any(),
	non_neg_integer(), non_neg_integer(), non_neg_integer(),
    pid(), pid()) -> {ok, pid()}.
start_link(LSocket, Transport, Protocol, Opts,
		MaxConns, MaxConnPerPeriod, ConnPeriodMilliSec,
        ListenerPid, ReqsSup) ->
	Pid = spawn_link(?MODULE, acceptor,
		[LSocket, Transport, Protocol, Opts, 1,
         MaxConns, MaxConnPerPeriod, ConnPeriodMilliSec * 1000, now(), 0,
         ListenerPid, ReqsSup]),
	{ok, Pid}.

%% Internal.

-spec acceptor(inet:socket(), module(), module(), any(), non_neg_integer(),
	non_neg_integer(), non_neg_integer(), non_neg_integer(), 
    {non_neg_integer(), non_neg_integer(), non_neg_integer()},
    non_neg_integer(), pid(), pid()) -> no_return().
acceptor(LSocket, Transport, Protocol, Opts, OptsVsn,
        MaxConns, MaxConnPerPeriod, ConnPeriodMicroSec, LastPeriodStart, ConnInCurrentPeriod, 
        ListenerPid, ReqsSup) ->
    {Res, LastPeriodStart2, ConnInCurrentPeriod2} = case Transport:accept(LSocket, 2000) of
        {ok, CSocket} ->
            case MaxConnPerPeriod of
                0 ->
                    accept_connection(CSocket, Transport, Protocol, Opts,
                            ListenerPid, ReqsSup),
                    {ok, {0, 0, 0}, 0};
                _ ->
                    Now = now(),
                    NewPeriod = timer:now_diff(Now, LastPeriodStart) > ConnPeriodMicroSec,
                    case (ConnInCurrentPeriod >= MaxConnPerPeriod) and (not NewPeriod) of
                        true ->
                            Transport:close(CSocket),
                            {ok, LastPeriodStart, ConnInCurrentPeriod};
                        false ->                    
                            accept_connection(CSocket, Transport, Protocol, Opts, ListenerPid, ReqsSup),
                            case NewPeriod of 
                                true  -> 
                                    {ok, Now, 1};
                                false -> 
                                    {ok, LastPeriodStart, ConnInCurrentPeriod + 1}
                            end
                    end
            end;
		{error, timeout} ->
            % cowboy_listener:check_upgrades(ListenerPid, OptsVsn); - listener disabled for efficency reasons
			{ok, LastPeriodStart, ConnInCurrentPeriod};
		{error, _Reason} ->
			%% @todo Probably do something here. If the socket was closed,
			%%       we may want to try and listen again on the port?
			{ok, LastPeriodStart, ConnInCurrentPeriod}
	end,
	case Res of
		ok ->
			?MODULE:acceptor(LSocket, Transport, Protocol, Opts, OptsVsn, 
                MaxConns, MaxConnPerPeriod, ConnPeriodMicroSec, LastPeriodStart2, ConnInCurrentPeriod2, ListenerPid, ReqsSup)
		% {upgrade, Opts2, OptsVsn2} -> we can only get this if we re-enable cowboy_listener
		%	?MODULE:acceptor(LSocket, Transport, Protocol,
		%		Opts2, OptsVsn2, ListenerPid, ReqsSup)
	end.

-spec accept_connection(inet:socket(), module(), module(), any(), pid(), pid()) -> ok.
accept_connection(CSocket, Transport, Protocol, Opts, ListenerPid, ReqsSup) ->
    {ok, Pid} = supervisor:start_child(ReqsSup,
        [ListenerPid, CSocket, Transport, Protocol, Opts]),
    Transport:controlling_process(CSocket, Pid),
    %{ok, NbConns} = cowboy_listener:add_connection(ListenerPid,
    %    default, Pid, OptsVsn),
    Pid ! {shoot, ListenerPid}, % this would have been done in cowboy_listener if it was not disabled
    ok.
