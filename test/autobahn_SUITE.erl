%% Copyright (c) 2011, Magnus Klaar <magnus.klaar@gmail.com>
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

-module(autobahn_SUITE).

%% This CT suite reuses the websocket server test suite from the Autobahn
%% project. The Autobahn project is a websocket implementation for Python.
%% Given that we don't expect to find the packages and tools to properly
%% set up and run such a test on a system used primarily for Erlang devlopment
%% this test suite is not included in the default 'ct' target in the makefile.

-include_lib("common_test/include/ct.hrl").

-export([all/0, groups/0, init_per_suite/1, end_per_suite/1,
	init_per_group/2, end_per_group/2]). %% ct.
-export([run_tests/1]). %% autobahn.

%% ct.

all() ->
	[{group, autobahn}].

groups() ->
	BaseTests = [run_tests],
	[{autobahn, [], BaseTests}].

init_per_suite(Config) ->
	application:start(inets),
	application:start(cowboy),
	%% /tmp must be used as the parent directory for the virtualenv because
	%% the directory names used in CT are so long that the interpreter path
	%% in the scripts generated by virtualenv get so long that the system
	%% refuses to execute them.
	EnvPath = "/tmp/cowboy_autobahn_env",
	os:putenv("AB_TESTS_ENV", EnvPath),
	os:putenv("AB_TESTS_PRIV", ?config(priv_dir, Config)),
	BinPath = filename:join(?config(data_dir, Config), "test.py"),
	Stdout = os:cmd(BinPath ++ " setup"),
	ct:log("~s~n", [Stdout]),
	case string:str(Stdout, "AB-TESTS-SETUP-OK") of
		0 -> erlang:error(failed);
		_ -> [{env_path, EnvPath},{bin_path,BinPath}|Config]
	end.

end_per_suite(_Config) ->
	os:cmd("deactivate"),
	application:stop(cowboy),
	application:stop(inets),
	ok.

init_per_group(autobahn, Config) ->
	Port = 33080,
	cowboy:start_http(autobahn, 100, [{port, Port}], [
		{dispatch, init_dispatch()}
	]),
	[{port, Port}|Config].

end_per_group(Listener, _Config) ->
	cowboy:stop_listener(Listener),
	ok.

%% Dispatch configuration.

init_dispatch() ->
	[{[<<"localhost">>], [
		{[<<"echo">>], websocket_echo_handler, []}]}].

%% autobahn cases

run_tests(Config) ->
	PrivDir = ?config(priv_dir, Config),
	IndexFile = filename:join([PrivDir, "reports", "servers", "index.html"]),
	ct:log("<h2><a href=\"~s\">Full Test Results Report</a></h2>~n", [IndexFile]),
	BinPath = ?config(bin_path, Config),
	Stdout = os:cmd(BinPath ++ " test"),
	ct:log("~s~n", [Stdout]),
	case string:str(Stdout, "AB-TESTS-TEST-OK") of
		0 -> erlang:error(failed);
		_ -> ok
	end,
	{ok, IndexHTML} = file:read_file(IndexFile),
	case binary:match(IndexHTML, <<"Fail">>) of
		{_, _} -> erlang:error(failed);
		nomatch -> ok
	end.
