%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 1998-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%

-module(erl_eval_SUITE).
-export([all/0, suite/0,groups/0,init_per_suite/1, end_per_suite/1,
	 init_per_testcase/2, end_per_testcase/2,
	 init_per_group/2,end_per_group/2]).

-export([guard_1/1, guard_2/1,
	 match_pattern/1,
	 match_bin/1,
	 string_plusplus/1,
	 pattern_expr/1,
         guard_3/1, guard_4/1, guard_5/1,
         lc/1,
         zlc/1,
         zbc/1,
         zmc/1,
         simple_cases/1,
         unary_plus/1,
         apply_atom/1,
         otp_5269/1,
         otp_6539/1,
         otp_6543/1,
         otp_6787/1,
         otp_6977/1,
	 otp_7550/1,
         otp_8133/1,
         otp_10622/1,
         otp_13228/1,
         otp_14826/1,
         funs/1,
         custom_stacktrace/1,
	 try_catch/1,
	 eval_expr_5/1,
	 zero_width/1,
         eep37/1,
         eep43/1,
         otp_15035/1,
         otp_16439/1,
         otp_14708/1,
         otp_16545/1,
         otp_16865/1,
         eep49/1,
         binary_and_map_aliases/1,
         eep58/1,
         strict_generators/1,
         binary_skip/1]).

%%
%% Define to run outside of test server
%%
%%-define(STANDALONE,1).

-import(lists,[concat/1, sort/1]).

-export([count_down/2, count_down_fun/0, do_apply/2,
         local_func/3, local_func_value/2]).
-export([simple/0]).
-export([my_div/2]).

-ifdef(STANDALONE).
-define(config(A,B),config(A,B)).
-export([config/2]).
-define(line, noop, ).
config(priv_dir,_) ->
    ".".
-else.
-include_lib("common_test/include/ct.hrl").
-endif.

init_per_testcase(_Case, Config) ->
    Config.

end_per_testcase(_Case, _Config) ->
    ok.

suite() ->
    [{ct_hooks,[ts_install_cth]},
     {timetrap,{minutes,1}}].

all() ->
    [guard_1, guard_2, match_pattern, string_plusplus,
     pattern_expr, match_bin, guard_3, guard_4, guard_5, lc,
     simple_cases, unary_plus, apply_atom, otp_5269,
     otp_6539, otp_6543, otp_6787, otp_6977, otp_7550,
     otp_8133, otp_10622, otp_13228, otp_14826,
     funs, custom_stacktrace, try_catch, eval_expr_5, zero_width,
     eep37, eep43, otp_15035, otp_16439, otp_14708, otp_16545, otp_16865,
     eep49, binary_and_map_aliases, eep58, strict_generators, binary_skip,
     zlc, zbc, zmc].

groups() ->
    [].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, Config) ->
    Config.

%% OTP-2405
guard_1(Config) when is_list(Config) ->
    {ok,Tokens ,_} =
	erl_scan:string("if a+4 == 4 -> yes; true -> no end. "),
    {ok, [Expr]} = erl_parse:parse_exprs(Tokens),
    no = guard_1_compiled(),
    {value, no, []} = erl_eval:expr(Expr, []),
    ok.

guard_1_compiled() ->
    if a+4 == 4 -> yes; true -> no end.

%% Similar to guard_1, but type-correct.
guard_2(Config) when is_list(Config) ->
    {ok,Tokens ,_} =
	erl_scan:string("if 6+4 == 4 -> yes; true -> no end. "),
    {ok, [Expr]} = erl_parse:parse_exprs(Tokens),
    no = guard_2_compiled(),
    {value, no, []} = erl_eval:expr(Expr, []),
    ok.

guard_2_compiled() ->
    if 6+4 == 4 -> yes; true -> no end.

%% OTP-3069: syntactic sugar string ++ ...
string_plusplus(Config) when is_list(Config) ->
    check(fun() -> case "abc" of "ab" ++ L -> L end end,
	  "case \"abc\" of \"ab\" ++ L -> L end. ",
	  "c"),
    check(fun() -> case "abcde" of "ab" ++ "cd" ++ L -> L end end,
	  "case \"abcde\" of \"ab\" ++ \"cd\" ++ L -> L end. ",
	  "e"),
    check(fun() -> case "abc" of [97, 98] ++ L -> L end end,
	  "case \"abc\" of [97, 98] ++ L -> L end. ",
	  "c"),
    ok.

%% OTP-2983: match operator in pattern.
match_pattern(Config) when is_list(Config) ->
    check(fun() -> case {a, b} of {a, _X}=Y -> {x,Y} end end,
	  "case {a, b} of {a, X}=Y -> {x,Y} end. ",
	  {x, {a, b}}),
    check(fun() -> case {a, b} of Y={a, _X} -> {x,Y} end end,
	  "case {a, b} of Y={a, X} -> {x,Y} end. ",
	  {x, {a, b}}),
    check(fun() -> case {a, b} of Y={a, _X}=Z -> {Z,Y} end end,
	  "case {a, b} of Y={a, X}=Z -> {Z,Y} end. ",
	  {{a, b}, {a, b}}),
    check(fun() -> A = 4, B = 28, <<13:(A+(X=B))>>, X end,
	  "begin A = 4, B = 28, <<13:(A+(X=B))>>, X end.",
	  28),
    ok.

%% Binary match problems.
match_bin(Config) when is_list(Config) ->
    check(fun() -> <<"abc">> = <<"abc">> end,
	  "<<\"abc\">> = <<\"abc\">>. ",
	  <<"abc">>),
    check(fun() ->
		  <<Size,B:Size/binary,Rest/binary>> = <<2,"AB","CD">>,
		  {Size,B,Rest}
	  end,
	  "begin <<Size,B:Size/binary,Rest/binary>> = <<2,\"AB\",\"CD\">>, "
	  "{Size,B,Rest} end. ",
	  {2,<<"AB">>,<<"CD">>}),
    ok.

%% OTP-3144: compile-time expressions in pattern.
pattern_expr(Config) when is_list(Config) ->
    check(fun() -> case 4 of 2+2 -> ok end end,
	  "case 4 of 2+2 -> ok end. ",
	  ok),
    check(fun() -> case 2 of +2 -> ok end end,
	  "case 2 of +2 -> ok end. ",
	  ok),
    ok.

%% OTP-4518.
guard_3(Config) when is_list(Config) ->
    check(fun() -> if false -> false; true -> true end end,
	  "if false -> false; true -> true end.",
	  true),
    check(fun() -> if <<"hej">> == <<"hopp">> -> true;
		      true -> false end end,
	  "begin if <<\"hej\">> == <<\"hopp\">> -> true;
                          true -> false end end.",
                false),
    check(fun() -> if <<"hej">> == <<"hej">> -> true;
		      true -> false end end,
	  "begin if <<\"hej\">> == <<\"hej\">> -> true;
                          true -> false end end.",
                true),
    ok.

%% OTP-4885.
guard_4(Config) when is_list(Config) ->
    check(fun() -> if erlang:'+'(3,a) -> true ; true -> false end end,
	  "if erlang:'+'(3,a) -> true ; true -> false end.",
	  false),
    check(fun() -> if erlang:is_integer(3) -> true ; true -> false end
	  end,
	  "if erlang:is_integer(3) -> true ; true -> false end.",
	  true),
    check(fun() -> [X || X <- [1,2,3], erlang:is_integer(X)] end,
	  "[X || X <- [1,2,3], erlang:is_integer(X)].",
	  [1,2,3]),
    check(fun() -> if is_atom(is_integer(a)) -> true ; true -> false end
	  end,
	  "if is_atom(is_integer(a)) -> true ; true -> false end.",
	  true),
    check(fun() -> if erlang:is_atom(erlang:is_integer(a)) -> true;
		      true -> false end end,
	  "if erlang:is_atom(erlang:is_integer(a)) -> true; "
	  "true -> false end.",
	  true),
    check(fun() -> if is_atom(3+a) -> true ; true -> false end end,
	  "if is_atom(3+a) -> true ; true -> false end.",
	  false),
    check(fun() -> if erlang:is_atom(3+a) -> true ; true -> false end
	  end,
	  "if erlang:is_atom(3+a) -> true ; true -> false end.",
	  false),
    ok.

%% Guards with erlang:'=='/2.
guard_5(Config) when is_list(Config) ->
    {ok,Tokens ,_} =
	erl_scan:string("case 1 of A when erlang:'=='(A, 1) -> true end."),
    {ok, [Expr]} = erl_parse:parse_exprs(Tokens),
    true = guard_5_compiled(),
    {value, true, [{'A',1}]} = erl_eval:expr(Expr, []),
    ok.

guard_5_compiled() ->
    case 1 of A when erlang:'=='(A, 1) -> true end.

%% OTP-4518.
lc(Config) when is_list(Config) ->
    check(fun() -> X = 32, [X || X <- [1,2,3]] end,
	  "begin X = 32, [X || X <- [1,2,3]] end.",
	  [1,2,3]),
    check(fun() -> X = 32,
		   [X || <<X:X>> <- [<<1:32>>,<<2:32>>,<<3:8>>]] end,
	  %% "binsize variable"          ^
	  "begin X = 32,
                 [X || <<X:X>> <- [<<1:32>>,<<2:32>>,<<3:8>>]] end.",
                [1,2]),
    check(fun() -> Y = 13,[X || {X,Y} <- [{1,2}]] end,
	  "begin Y = 13,[X || {X,Y} <- [{1,2}]] end.",
	  [1]),
    error_check("begin [A || X <- [{1,2}], 1 == A] end.",
		{unbound_var,'A'}),
    error_check("begin X = 32,
                        [{Y,W} || X <- [1,2,32,Y=4], Z <- [1,2,W=3]] end.",
                      {unbound_var,'Y'}),
    error_check("begin X = 32,<<A:B>> = <<100:X>> end.",
		{unbound_var,'B'}),
    check(fun() -> [X || X <- [1,2,3,4], not (X < 2)] end,
	  "begin [X || X <- [1,2,3,4], not (X < 2)] end.",
	  [2,3,4]),
    check(fun() -> [X || X <- [true,false], X] end,
	  "[X || X <- [true,false], X].", [true]),
    ok.

%% EEP-73 zip generator.
zlc(Config) when is_list(Config) ->
    check(fun() ->
                  X = 32, Y = 32, [{X, Y} || X <- [1,2,3] && Y <- [4,5,6]]
          end,
          "begin X = 32, Y = 32, [{X, Y} || X <- [1,2,3] && Y <- [4,5,6]] end.",
          [{1,4},{2,5},{3,6}]),
    check(fun() ->
                  S1 = [x, y, z], S2 = [5, 10, 15], X = 32, Y = 32,
                  [{X, Y} || X <- S1 && Y <- S2]
          end,
          "begin
        S1 = [x, y, z], S2 = [5, 10, 15], X = 32, Y = 32,
          [{X, Y} || X <- S1 && Y <- S2]
          end.",
    [{x,5}, {y,10}, {z,15}]),
    check(fun() ->
                  [{X, Y, K} || X <:- [1,2,3] &&  Y:=K <- #{1=>a, 2=>b, 3=>c}]
          end,
          "begin [{X, Y, K} || X <:- [1,2,3] &&  Y:=K <- #{1=>a, 2=>b, 3=>c}] end.",
          [{1,1,a},{2,2,b},{3,3,c}]),
    check(fun() ->
                [{X, W+Y} || X <- [a, b, c] && <<Y>> <= <<2, 4, 6>>, W <- [1,2]]
        end,
        "begin [{X, W+Y} || X <- [a, b, c] && <<Y>> <= <<2, 4, 6>>, W <- [1,2]] end.",
        [{a,3}, {a,4}, {b,5}, {b,6}, {c,7}, {c,8}]),
    check(fun() ->
            [{X, W+Y} || W <- [0], X <- [a, b, c] && <<Y>> <:= <<2, 4, 6>>, Y<4]
    end,
    "begin [{X, W+Y} || W <- [0], X <- [a, b, c] && <<Y>> <:= <<2, 4, 6>>, Y<4] end.",
    [{a,2}]),
    check(fun() ->
            [{X,Y}|| a=b=X <- [1,2] && Y <-[1,2]] end,
        "begin [{X,Y}|| a=b=X <- [1,2] && Y <-[1,2]] end.",
        []),
    check(fun() ->
        [{A,B,W} || {Same,W} <- [{a,1}],
            {Same,A} <- [{a,1},{b,9},{x,10}] && {Same,B} <- [{a,7},{wrong,8},{x,20}]]
        end,
        "begin [{A,B,W} || {Same,W} <- [{a,1}],
            {Same,A} <- [{a,1},{b,9},{x,10}] && {Same,B} <- [{a,7},{wrong,8},{x,20}]]
        end.",
        [{1,7,1},{10,20,1}]),
    error_check("[X || X <- a && Y <- [1]].",{bad_generators,{a,[1]}}),
    error_check("[{X,Y} || X <- a && <<Y>> <= <<1,2>>].",{bad_generators,{a,<<1,2>>}}),
    error_check("[{X,V} || X <- a && _K := V <- #{b=>3}].",{bad_generators,{a,#{b=>3}}}),
    error_check("begin
        X = 32, Y = 32, [{X, Y} || X <- [1,2,3] && Y <- [4]] end.",
    {bad_generators,{[2,3],[]}}),
    error_check("begin
        X = 32, Y = 32, [{X, Y} || X <- [1,2,3] && Y:=_V <- #{1=>1}] end.",
    {bad_generators,{[2,3],#{}}}),
    error_check("[X || X <- [b] && X <:- [a]].",{bad_generators,{[b],[a]}}),
    error_check("[X || X <:- [b] && X <- [a]].",{bad_generators,{[b],[a]}}),
    error_check("[X || X <- [a,a] && X <:- [a,b]].",{bad_generators,{[a],[b]}}),
    error_check("[{X,Y} || {X,Y} <- [{a,b}] && Y <:- [a] && X <- [a]].",
    {bad_generators,{[{a,b}],[a],[a]}}),

    ok.

zbc(Config) when is_list(Config) ->
    check(fun() ->
                  <<3, 4, 5>>
          end,
          "begin
        X = 32, Y = 32,
          << <<(X+Y)/integer>> || <<X>> <= <<1,2,3>> && <<Y>> <= <<2,2,2>> >>
              end.",
        <<3, 4, 5>>),
    check(fun() ->
                  <<4,5,6,5,6,7,6,7,8>>
          end,
          "begin
        X = 32, Y = 32, Z = 32,
          << <<(X+Y+Z)/integer>> || <<X>> <= <<1,2,3>> && <<Y>> <= <<2,2,2>>, Z<-[1,2,3] >>
              end.",
        <<4,5,6,5,6,7,6,7,8>>),
    check(fun() ->
                  <<4, 5, 6>>
          end,
          "begin
        L1 = <<1, 2, 3>>, L2 = <<1, 1, 1>>, L3 = <<2, 2, 2>>,
          << <<(X+Y+Z)/integer>> || <<X>> <= L1 && <<Y>> <= L2 && <<Z>> <= L3 >>
              end.",
    <<4, 5, 6>>),
    check(fun() ->
         << <<(X+Y):64>>|| a=b=X <- [1,2] && Y <- [1,2] >> end,
        "begin << <<(X+Y):64>>|| a=b=X <- [1,2] && Y <- [1,2] >> end.",
        <<>>),
    check(fun() ->
         << <<(X+Y):64>>|| a=b=X <- [1,2] && <<Y>> <= <<1,2>> >> end,
        "begin << <<(X+Y):64>>|| a=b=X <- [1,2] && <<Y>> <= <<1,2>> >> end.",
        <<>>),
    check(fun() ->
         << <<(X+V):64>>|| a=b=X <- [1,2] && _K:=V <- #{a=>1,b=>2}>> end,
        "begin << <<(X+V):64>>|| a=b=X <- [1,2] && _K:=V <- #{a=>1,b=>2}>> end.",
        <<>>),
    error_check("begin << <<(X+Y):8>> || <<X:b>> <= <<1,2>> && <<Y>> <= <<1,2>> >> end.",
        {bad_generators,{<<>>,<<1,2>>}}),
    error_check("begin << <<X>> || <<X>> <= a && Y <- [1]>> end.",{bad_generators,{a,[1]}}),
    error_check("begin
        X = 32, Y = 32,
                << <<(X+Y)/integer>> || X <- [1,2] && Y <- [1,2,3,4]>>
                    end.",
    {bad_generators,{[],[3,4]}}),
    error_check("begin << <<X:8>> || X <- [1] && Y <- a && <<Z>> <= <<2>> >> end.",
        {bad_generators,{[1], a, <<2>>}}),
    ok.

zmc(Config) when is_list(Config) ->
    check(fun() ->
                  [{a,b,1,3}]
          end,
          "begin
        M1 = #{a=>1}, M2 = #{b=>3},
          [{K1, K2, V1, V2} || K1 := V1 <- M1 && K2 := V2 <- M2]
          end.",
    [{a,b,1,3}]),
    check(fun() ->
                  [A * 4 || A <- lists:seq(1, 50)]
          end,
          "begin
        Seq = lists:seq(1, 50),
          M1 = maps:iterator(#{X=>X || X <- Seq}, ordered),
          M2 = maps:iterator(#{X=>X || X <- lists:seq(1,50)}, ordered),
          [X+Y+Z+W || X := Y <- M1 && Z := W <- M2]
          end.",
    [A * 4 || A <- lists:seq(1, 50)]),
    check(fun() ->
                  [{A, A*3, A*2, A*4} || A <- lists:seq(1, 50)]
          end,
          "begin
        Seq = lists:seq(1, 50),
          M3 = maps:iterator(#{X=>X*3 || X <- Seq}, ordered),
          M4 = maps:iterator(#{X*2=>X*4 || X <- Seq}, ordered),
          [{X, Y, Z, W} || X := Y <- M3 && Z := W <- M4]
          end.",
    [{A, A*3, A*2, A*4} || A <- lists:seq(1, 50)]),
    check(fun() ->
                  #{K1 => V1+V2 || K1:=V1 <:- #{a=>1} && _K2:=V2 <- #{b=>3}}
          end,
          "begin
        #{K1 => V1+V2 || K1:=V1 <- #{a=>1} && _K2:=V2 <- #{b=>3}}
          end.",
    #{a=>4}),
    check(fun() ->
                  #{K=>V || a := b <- #{x => y} && K := V <- #{x => y}}
          end,
          "begin
        #{K=>V || a := b <- #{x => y} && K := V <- #{x => y}}
          end.",
    #{}),
    error_check("begin
        #{K1 => V1+V2 || K1:=V1 <- #{a=>1} &&
                             _K2:=V2 <- maps:iterator(#{b=>3,c=>4}, ordered)}
                end.",
    {bad_generators,{#{},#{c=>4}}}),
    error_check("begin #{X=>Y || X <- [1] && Y <- a && K1:=V1 <- #{b=>3}} end.",
        {bad_generators,{[1], a, #{b=>3}}}),

    error_check("begin #{K => V || K := V <- #{1=>2} && K := _ <:- #{2=>3}} end.",
        {bad_generators,{#{1 => 2},#{2 => 3}}}),
    ok.

%% Simple cases, just to cover some code.
simple_cases(Config) when is_list(Config) ->
    check(fun() -> A = $C end, "A = $C.", $C),
    %% check(fun() -> A = 3.14 end, "A = 3.14.", 3.14),
    check(fun() -> self() ! a, A = receive a -> true end end,
	  "begin self() ! a, A = receive a -> true end end.",
	  true),
    check(fun() -> c:flush(), self() ! a, self() ! b, self() ! c,
		   receive b -> b end,
		   {messages, [a,c]} =
		       erlang:process_info(self(), messages),
		   c:flush() end,
	  "begin c:flush(), self() ! a, self() ! b, self() ! c,"
	  "receive b -> b end,"
	  "{messages, [a,c]} ="
	  "     erlang:process_info(self(), messages), c:flush() end.",
	  ok),
    check(fun() -> self() ! a, A = receive a -> true
				   after 0 -> false end end,
	  "begin self() ! a, A = receive a -> true"
	  "                      after 0 -> false end end.",
	  true),
    check(fun() -> c:flush(), self() ! a, self() ! b, self() ! c,
		   receive b -> b after 0 -> true end,
		   {messages, [a,c]} =
		       erlang:process_info(self(), messages),
		   c:flush() end,
	  "begin c:flush(), self() ! a, self() ! b, self() ! c,"
	  "receive b -> b after 0 -> true end,"
	  "{messages, [a,c]} ="
	  "     erlang:process_info(self(), messages), c:flush() end.",
	  ok),
    check(fun() -> receive _ -> true after 10 -> false end end,
	  "receive _ -> true after 10 -> false end.",
	  false),
    check(fun() -> F = fun(A) -> A end, true = 3 == F(3) end,
	  "begin F = fun(A) -> A end, true = 3 == F(3) end.",
	  true),
    check(fun() -> F = fun(A) -> A end, true = 3 == apply(F, [3]) end,
	  "begin F = fun(A) -> A end, true = 3 == apply(F,[3]) end.",
	  true),
    check(fun() -> catch throw(a) end, "catch throw(a).", a),
    check(fun() -> catch a end, "catch a.", a),
    check(fun() -> 4 == 3 end, "4 == 3.", false),
    check(fun() -> not true end, "not true.", false),
    check(fun() -> -3 end, "-3.", -3),

    error_check("3.0 = 4.0.", {badmatch,4.0}),
    check(fun() -> <<(3.0+2.0):32/float>> = <<5.0:32/float>> end,
	  "<<(3.0+2.0):32/float>> = <<5.0:32/float>>.",
	  <<5.0:32/float>>),

    check(fun() -> false andalso kludd end, "false andalso kludd.",
	  false),
    check(fun() -> true andalso true end, "true andalso true.",
	  true),
    check(fun() -> true andalso false end, "true andalso false.",
	  false),
    check(fun() -> true andalso kludd end, "true andalso kludd.",
	  kludd),
    error_check("kladd andalso kludd.", {badarg,kladd}),

    check(fun() -> if false andalso kludd -> a; true -> b end end,
	  "if false andalso kludd -> a; true -> b end.",
	  b),
    check(fun() -> if true andalso true -> a; true -> b end end,
	  "if true andalso true -> a; true -> b end.",
	  a),
    check(fun() -> if true andalso false -> a; true -> b end end,
	  "if true andalso false -> a; true -> b end.",
	  b),

    check(fun() -> true orelse kludd end,
	  "true orelse kludd.", true),
    check(fun() -> false orelse false end,
	  "false orelse false.", false),
    check(fun() -> false orelse true end,
	  "false orelse true.", true),
    check(fun() -> false orelse kludd end,
	  "false orelse kludd.", kludd),
    error_check("kladd orelse kludd.", {badarg,kladd}),
    error_check("[X || X <- [1,2,3], begin 1 end].",{bad_filter,1}),
    error_check("[X || X <- a].",{bad_generator,a}),

    check(fun() -> if true orelse kludd -> a; true -> b end end,
	  "if true orelse kludd -> a; true -> b end.", a),
    check(fun() -> if false orelse false -> a; true -> b end end,
	  "if false orelse false -> a; true -> b end.", b),
    check(fun() -> if false orelse true -> a; true -> b end end,
	  "if false orelse true -> a; true -> b end.", a),

    check(fun() -> [X || X <- [1,2,3], X+2] end,
	  "[X || X <- [1,2,3], X+2].", []),

    check(fun() -> [X || X <- [1,2,3], [X] == [X || X <- [2]]] end,
	  "[X || X <- [1,2,3], [X] == [X || X <- [2]]].",
	  [2]),
    check(fun() -> F = fun(1) -> ett; (2) -> zwei end,
		   ett = F(1), zwei = F(2) end,
	  "begin F = fun(1) -> ett; (2) -> zwei end,
                         ett = F(1), zwei = F(2) end.",
                zwei),
    check(fun() -> F = fun(X) when X == 1 -> ett;
			  (X) when X == 2 -> zwei end,
		   ett = F(1), zwei = F(2) end,
	  "begin F = fun(X) when X == 1 -> ett;
                              (X) when X == 2 -> zwei end,
	  ett = F(1), zwei = F(2) end.",
                zwei),
    error_check("begin F = fun(1) -> ett end, zwei = F(2) end.",
		function_clause),
    check(fun() -> if length([1]) == 1 -> yes;
		      true -> no end end,
	  "if length([1]) == 1 -> yes;
                            true -> no end.",
                yes),
    check(fun() -> if is_integer(3) -> true; true -> false end end,
	  "if is_integer(3) -> true; true -> false end.", true),
    check(fun() -> if integer(3) -> true; true -> false end end,
	  "if integer(3) -> true; true -> false end.", true),
    check(fun() -> if is_float(3) -> true; true -> false end end,
	  "if is_float(3) -> true; true -> false end.", false),
    check(fun() -> if float(3) -> true; true -> false end end,
	  "if float(3) -> true; true -> false end.", false),
    check(fun() -> if is_number(3) -> true; true -> false end end,
	  "if is_number(3) -> true; true -> false end.", true),
    check(fun() -> if number(3) -> true; true -> false end end,
	  "if number(3) -> true; true -> false end.", true),
    check(fun() -> if is_atom(a) -> true; true -> false end end,
	  "if is_atom(a) -> true; true -> false end.", true),
    check(fun() -> if atom(a) -> true; true -> false end end,
	  "if atom(a) -> true; true -> false end.", true),
    check(fun() -> if is_list([]) -> true; true -> false end end,
	  "if is_list([]) -> true; true -> false end.", true),
    check(fun() -> if list([]) -> true; true -> false end end,
	  "if list([]) -> true; true -> false end.", true),
    check(fun() -> if is_tuple({}) -> true; true -> false end end,
	  "if is_tuple({}) -> true; true -> false end.", true),
    check(fun() -> if tuple({}) -> true; true -> false end end,
	  "if tuple({}) -> true; true -> false end.", true),
    check(fun() -> if is_pid(self()) -> true; true -> false end end,
	  "if is_pid(self()) -> true; true -> false end.", true),
    check(fun() -> if pid(self()) -> true; true -> false end end,
	  "if pid(self()) -> true; true -> false end.", true),
    check(fun() -> R = make_ref(), if is_reference(R) -> true;
				      true -> false end end,
	  "begin R = make_ref(), if is_reference(R) -> true;"
	  "true -> false end end.", true),
    check(fun() -> R = make_ref(), if reference(R) -> true;
				      true -> false end end,
	  "begin R = make_ref(), if reference(R) -> true;"
	  "true -> false end end.", true),
    check(fun() -> if is_port(a) -> true; true -> false end end,
	  "if is_port(a) -> true; true -> false end.", false),
    check(fun() -> if port(a) -> true; true -> false end end,
	  "if port(a) -> true; true -> false end.", false),
    check(fun() -> if is_function(a) -> true; true -> false end end,
	  "if is_function(a) -> true; true -> false end.", false),
    check(fun() -> if function(a) -> true; true -> false end end,
	  "if function(a) -> true; true -> false end.", false),
    check(fun() -> if is_binary(<<>>) -> true; true -> false end end,
	  "if is_binary(<<>>) -> true; true -> false end.", true),
    check(fun() -> if binary(<<>>) -> true; true -> false end end,
	  "if binary(<<>>) -> true; true -> false end.", true),
    check(fun() -> if is_integer(a) == true -> yes;
		      true -> no end end,
	  "if is_integer(a) == true -> yes;
                            true -> no end.",
                no),
    check(fun() -> if [] -> true; true -> false end end,
	  "if [] -> true; true -> false end.", false),
    error_check("if lists:member(1,[1]) -> true; true -> false end.",
		illegal_guard_expr),
    error_check("if false -> true end.", if_clause),
    check(fun() -> if a+b -> true; true -> false end end,
	  "if a + b -> true; true -> false end.", false),
    check(fun() -> if + b -> true; true -> false end end,
	  "if + b -> true; true -> false end.", false),
    error_check("case foo of bar -> true end.", {case_clause,foo}),
    error_check("case 4 of 2+a -> true; _ -> false end.",
		illegal_pattern),
    error_check("case 4 of +a -> true; _ -> false end.",
		illegal_pattern),
    check(fun() -> case a of
		       X when X == b -> one;
		       X when X == a -> two
		   end end,
	  "begin case a of
                             X when X == b -> one;
	      X when X == a -> two
	 end end.", two),
    error_check("3 = 4.", {badmatch,4}),
	  error_check("a = 3.", {badmatch,3}),
    %% error_check("3.1 = 2.7.",{badmatch,2.7}),
	  error_check("$c = 4.", {badmatch,4}),
	  check(fun() -> $c = $c end, "$c = $c.", $c),
	  check(fun() -> _ = bar end, "_ = bar.", bar),
	  check(fun() -> A = 14, A = 14 end,
                "begin A = 14, A = 14 end.", 14),
	  error_check("begin A = 14, A = 16 end.", {badmatch,16}),
	  error_check("\"hej\" = \"san\".", {badmatch,"san"}),
	  check(fun() -> "hej" = "hej" end,
                "\"hej\" = \"hej\".", "hej"),
	  error_check("[] = [a].", {badmatch,[a]}),
	  check(fun() -> [] = [] end, "[] = [].", []),
	  error_check("[a] = [].", {badmatch,[]}),
	  error_check("{a,b} = 34.", {badmatch,34}),
	  check(fun() -> <<X:7>> = <<8:7>>, X end,
		"begin <<X:7>> = <<8:7>>, X end.", 8),
	  error_check("<<34:32>> = \"hej\".", {badmatch,"hej"}),
	  check(fun() -> trunc((1 * 3 div 3 + 4 - 3) / 1) rem 2 end,
                "begin trunc((1 * 3 div 3 + 4 - 3) / 1) rem 2 end.", 0),
	  check(fun() -> (2#101 band 2#10101) bor (2#110 bxor 2#010) end,
                "(2#101 band 2#10101) bor (2#110 bxor 2#010).", 5),
	  check(fun() -> (2#1 bsl 4) + (2#10000 bsr 3) end,
                "(2#1 bsl 4) + (2#10000 bsr 3).", 18),
	  check(fun() -> ((1<3) and ((1 =:= 2) or (1 =/= 2))) xor (1=<2) end,
                "((1<3) and ((1 =:= 2) or (1 =/= 2))) xor (1=<2).", false),
	  check(fun() -> (a /= b) or (2 > 4) or (3 >= 3) end,
                "(a /= b) or (2 > 4) or (3 >= 3).", true),
	  check(fun() -> "hej" ++ "san" =/= "hejsan" -- "san" end,
                "\"hej\" ++ \"san\" =/= \"hejsan\" -- \"san\".", true),
	  check(fun() -> (bnot 1) < -0 end, "(bnot (+1)) < -0.", true),
	  ok.

%% OTP-4929. Unary plus rejects non-numbers.
unary_plus(Config) when is_list(Config) ->
    check(fun() -> F = fun(X) -> + X end,
		   true = -1 == F(-1) end,
	  "begin F = fun(X) -> + X end,"
	  "      true = -1 == F(-1) end.", true, ['F'], none, none),
    error_check("+a.", badarith),
    ok.

%% OTP-5064. Can no longer apply atoms.
apply_atom(Config) when is_list(Config) ->
    error_check("[X || X <- [[1],[2]],
                             begin L = length, L(X) =:= 1 end].",
                      {badfun,length}),
    ok.

%% OTP-5269. Bugs in the bit syntax.
otp_5269(Config) when is_list(Config) ->
    check(fun() -> L = 8,
                         F = fun(<<A:L,B:A>>) -> B end,
                         F(<<16:8, 7:16>>)
                end,
                "begin
                   L = 8, F = fun(<<A:L,B:A>>) -> B end, F(<<16:8, 7:16>>)
                 end.",
                7),
    check(fun() -> L = 8,
                         F = fun(<<L:L,B:L>>) -> B end,
                         F(<<16:8, 7:16>>)
                end,
                "begin
                   L = 8, F = fun(<<L:L,B:L>>) -> B end, F(<<16:8, 7:16>>)
                 end.",
                7),
    check(fun() -> L = 8, <<A:L,B:A>> = <<16:8, 7:16>>, B end,
                "begin L = 8, <<A:L,B:A>> = <<16:8, 7:16>>, B end.",
                7),
    error_check("begin L = 8, <<L:L,B:L>> = <<16:8, 7:16>> end.",
                      {badmatch,<<16:8,7:16>>}),

    error_check("begin <<L:16,L:L>> = <<16:16,8:16>>, L end.",
                      {badmatch, <<16:16,8:16>>}),
    check(fun() -> U = 8, (fun(<<U:U>>) -> U end)(<<32:8>>) end,
                "begin U = 8, (fun(<<U:U>>) -> U end)(<<32:8>>) end.",
                32),
    check(fun() -> U = 8, [U || <<U:U>> <- [<<32:8>>]] end,
                "begin U = 8, [U || <<U:U>> <- [<<32:8>>]] end.",
                [32]),
    error_check("(fun({3,<<A:32,A:32>>}) -> a end)
                          ({3,<<17:32,19:32>>}).",
                      function_clause),
    check(fun() -> [X || <<A:8,
                                 B:A>> <- [<<16:8,19:16>>],
                               <<X:8>> <- [<<B:8>>]] end,
                "[X || <<A:8,
                                 B:A>> <- [<<16:8,19:16>>],
                               <<X:8>> <- [<<B:8>>]].",
                [19]),
    check(fun() ->
		(fun (<<A:1/binary, B:8/integer, _C:B/binary>>) ->
			    case A of
				B -> wrong;
				_ -> ok
			    end
		 end)(<<1,2,3,4>>) end,
		"(fun(<<A:1/binary, B:8/integer, _C:B/binary>>) ->"
			    " case A of B -> wrong; _ -> ok end"
		" end)(<<1, 2, 3, 4>>).",
		ok),
    ok.

%% OTP-6539. try/catch bugs.
otp_6539(Config) when is_list(Config) ->
    check(fun() ->
                        F = fun(A,B) ->
                                    try A+B
                                    catch _:_ -> dontthinkso
                                    end
                            end,
                        lists:zipwith(F, [1,2], [2,3])
                end,
                "begin
                     F = fun(A,B) ->
                                 try A+B
                                 catch _:_ -> dontthinkso
                                 end
                         end,
                     lists:zipwith(F, [1,2], [2,3])
                 end.",
                [3, 5]),
    ok.

%% OTP-6543. bitlevel binaries.
otp_6543(Config) when is_list(Config) ->
    check(fun() ->
                        << <<X>> || <<X>> <- [1,2,3] >>
                end,
                "<< <<X>> || <<X>> <- [1,2,3] >>.",
                <<>>),
    check(fun() ->
                        << <<X>> || X <- [1,2,3] >>
                end,
                "<< <<X>> || X <- [1,2,3] >>.",
                <<1,2,3>>),
    check(fun() ->
                        << <<X:8>> || <<X:2>> <= <<"hej">> >>
                end,
                "<< <<X:8>> || <<X:2>> <= <<\"hej\">> >>.",
                <<1,2,2,0,1,2,1,1,1,2,2,2>>),
    check(fun() ->
                        << <<X:8>> ||
                            <<65,X:4>> <= <<65,7:4,65,3:4,66,8:4>> >>
                end,
                "<< <<X:8>> ||
                            <<65,X:4>> <= <<65,7:4,65,3:4,66,8:4>> >>.",
                <<7,3>>),
    check(fun() -> <<34:18/big>> end,
                "<<34:18/big>>.",
                <<0,8,2:2>>),
    check(fun() -> <<34:18/big-unit:2>> end,
                "<<34:18/big-unit:2>>.",
                <<0,0,0,2,2:4>>),
    check(fun() -> <<34:18/little>> end,
                "<<34:18/little>>.",
                <<34,0,0:2>>),
    case eval_string("<<34:18/native>>.") of
              <<0,8,2:2>> -> ok;
              <<34,0,0:2>> -> ok
          end,
    check(fun() -> <<34:18/big-signed>> end,
                "<<34:18/big-signed>>.",
                <<0,8,2:2>>),
    check(fun() -> <<34:18/little-signed>> end,
                "<<34:18/little-signed>>.",
                <<34,0,0:2>>),
    case eval_string("<<34:18/native-signed>>.") of
              <<0,8,2:2>> -> ok;
              <<34,0,0:2>> -> ok
          end,
    check(fun() -> <<34:18/big-unsigned>> end,
                "<<34:18/big-unsigned>>.",
                <<0,8,2:2>>),
    check(fun() -> <<34:18/little-unsigned>> end,
                "<<34:18/little-unsigned>>.",
                <<34,0,0:2>>),
    case eval_string("<<34:18/native-unsigned>>.") of
              <<0,8,2:2>> -> ok;
              <<34,0,0:2>> -> ok
          end,
    check(fun() -> <<3.14:32/float-big>> end,
                "<<3.14:32/float-big>>.",
                <<64,72,245,195>>),
    check(fun() -> <<3.14:32/float-little>> end,
                "<<3.14:32/float-little>>.",
                <<195,245,72,64>>),
    case eval_string("<<3.14:32/float-native>>.") of
              <<64,72,245,195>> -> ok;
              <<195,245,72,64>> -> ok
          end,
    error_check("<<(<<17,3:2>>)/binary>>.", badarg),
    check(fun() -> <<(<<17,3:2>>)/bitstring>> end,
                "<<(<<17,3:2>>)/bitstring>>.",
                <<17,3:2>>),
    check(fun() -> <<(<<17,3:2>>):10/bitstring>> end,
                "<<(<<17,3:2>>):10/bitstring>>.",
                <<17,3:2>>),
    check(fun() -> <<<<344:17>>/binary-unit:17>> end,
		"<<<<344:17>>/binary-unit:17>>.",
		<<344:17>>),

    check(fun() -> <<X:18/big>> = <<34:18/big>>, X end,
                "begin <<X:18/big>> = <<34:18/big>>, X end.",
                34),
    check(fun() -> <<X:18/big-unit:2>> = <<34:18/big-unit:2>>, X end,
                "begin <<X:18/big-unit:2>> = <<34:18/big-unit:2>>, X end.",
                34),
    check(fun() -> <<X:18/little>> = <<34:18/little>>, X end,
                "begin <<X:18/little>> = <<34:18/little>>, X end.",
                34),
    check(fun() -> <<X:18/native>> = <<34:18/native>>, X end,
                "begin <<X:18/native>> = <<34:18/native>>, X end.",
                34),
    check(fun() -> <<X:18/big-signed>> = <<34:18/big-signed>>, X end,
                "begin <<X:18/big-signed>> = <<34:18/big-signed>>, X end.",
                34),
    check(fun() -> <<X:18/little-signed>> = <<34:18/little-signed>>,
                         X end,
                "begin <<X:18/little-signed>> = <<34:18/little-signed>>,
                       X end.",
                34),
    check(fun() -> <<X:18/native-signed>> = <<34:18/native-signed>>,
                         X end,
                "begin <<X:18/native-signed>> = <<34:18/native-signed>>,
                       X end.",
                34),
    check(fun() -> <<X:18/big-unsigned>> = <<34:18/big-unsigned>>,
                         X end,
                "begin <<X:18/big-unsigned>> = <<34:18/big-unsigned>>,
                       X end.",
                34),
    check(fun() ->
                        <<X:18/little-unsigned>> = <<34:18/little-unsigned>>,
                        X end,
                "begin <<X:18/little-unsigned>> = <<34:18/little-unsigned>>,
                       X end.",
                34),
    check(fun() ->
                        <<X:18/native-unsigned>> = <<34:18/native-unsigned>>,
                        X end,
                "begin <<X:18/native-unsigned>> = <<34:18/native-unsigned>>,
                       X end.",
                34),
    check(fun() -> <<X:32/float-big>> = <<2.0:32/float-big>>, X end,
                "begin <<X:32/float-big>> = <<2.0:32/float-big>>,
                        X end.",
                2.0),
    check(fun() -> <<X:32/float-little>> = <<2.0:32/float-little>>,
                         X end,
                "begin <<X:32/float-little>> = <<2.0:32/float-little>>,
                        X end.",
                2.0),
    check(fun() -> <<X:32/float-native>> = <<2.0:32/float-native>>,
                         X end,
                "begin <<X:32/float-native>> = <<2.0:32/float-native>>,
                        X end.",
                2.0),

    check(
            fun() ->
                    [X || <<"hej",X:8>> <= <<"hej",8,"san",9,"hej",17,"hej">>]
            end,
            "[X || <<\"hej\",X:8>> <=
                        <<\"hej\",8,\"san\",9,\"hej\",17,\"hej\">>].",
            [8,17]),
    check(
            fun() ->
                    L = 8, << <<B:32>> || <<L:L,B:L>> <= <<16:8, 7:16>> >>
            end,
            "begin L = 8, << <<B:32>> || <<L:L,B:L>> <= <<16:8, 7:16>> >>
             end.",
            <<0,0,0,7>>),
    %% Test the Value part of a binary segment.
    %% "Old" bugs have been fixed (partial_eval is called on Value).
    check(fun() -> [ 3 || <<17/float>> <= <<17.0/float>>] end,
                "[ 3 || <<17/float>> <= <<17.0/float>>].",
                [3]),
    check(fun() -> [ 3 || <<17/float>> <- [<<17.0/float>>]] end,
                "[ 3 || <<17/float>> <- [<<17.0/float>>]].",
                [3]),
    check(fun() -> [ X || <<17/float,X:3>> <= <<17.0/float,2:3>>] end,
                "[ X || <<17/float,X:3>> <= <<17.0/float,2:3>>].",
                [2]),
    check(fun() ->
                 [ foo || <<(1 bsl 1023)/float>> <= <<(1 bsl 1023)/float>>]
                end,
                "[ foo || <<(1 bsl 1023)/float>> <= <<(1 bsl 1023)/float>>].",
                [foo]),
    check(fun() ->
                 [ foo || <<(1 bsl 1023)/float>> <- [<<(1 bsl 1023)/float>>]]
                end,
               "[ foo || <<(1 bsl 1023)/float>> <- [<<(1 bsl 1023)/float>>]].",
                [foo]),
    error_check("[ foo || <<(1 bsl 1024)/float>> <-
                            [<<(1 bsl 1024)/float>>]].",
                      badarg),
    check(fun() ->
                 [ foo || <<(1 bsl 1024)/float>> <- [<<(1 bsl 1023)/float>>]]
                end,
                "[ foo || <<(1 bsl 1024)/float>> <-
                            [<<(1 bsl 1023)/float>>]].",
                []),
    check(fun() ->
                 [ foo || <<(1 bsl 1024)/float>> <= <<(1 bsl 1023)/float>>]
                end,
                "[ foo || <<(1 bsl 1024)/float>> <=
                            <<(1 bsl 1023)/float>>].",
                []),
    check(fun() ->
                        L = 8,
                        [{L,B} || <<L:L,B:L/float>> <= <<32:8,7:32/float>>]
                end,
                "begin L = 8,
                       [{L,B} || <<L:L,B:L/float>> <= <<32:8,7:32/float>>]
                 end.",
                [{32,7.0}]),
    check(fun() ->
                        L = 8,
                        [{L,B} || <<L:L,B:L/float>> <- [<<32:8,7:32/float>>]]
                end,
                "begin L = 8,
                       [{L,B} || <<L:L,B:L/float>> <- [<<32:8,7:32/float>>]]
                 end.",
                [{32,7.0}]),
    check(fun() ->
                        [foo || <<"s">> <= <<"st">>]
                end,
                "[foo || <<\"s\">> <= <<\"st\">>].",
                [foo]),
    check(fun() -> <<_:32>> = <<17:32>> end,
                "<<_:32>> = <<17:32>>.",
                <<17:32>>),
    check(fun() -> [foo || <<_:32>> <= <<17:32,20:32>>] end,
                "[foo || <<_:32>> <= <<17:32,20:32>>].",
                [foo,foo]),

    check(fun() -> << <<X:32>> || X <- [1,2,3], X > 1 >> end,
                "<< <<X:32>> || X <- [1,2,3], X > 1 >>.",
                <<0,0,0,2,0,0,0,3>>),
    error_check("[X || <<X>> <= [a,b]].",{bad_generator,[a,b]}),
    ok.

%% OTP-6787. bitlevel binaries.
otp_6787(Config) when is_list(Config) ->
    check(
            fun() -> <<16:(1024*1024)>> = <<16:(1024*1024)>> end,
            "<<16:(1024*1024)>> = <<16:(1024*1024)>>.",
            <<16:1048576>>),
    ok.

%% OTP-6977. ++ bug.
otp_6977(Config) when is_list(Config) ->
    check(
            fun() -> (fun([$X] ++ _) -> ok end)("X") end,
            "(fun([$X] ++ _) -> ok end)(\"X\").",
            ok),
    ok.

%% OTP-7550. Support for UTF-8, UTF-16, UTF-32.
otp_7550(Config) when is_list(Config) ->

    %% UTF-8.
    check(
	    fun() -> <<65>> = <<65/utf8>> end,
	    "<<65>> = <<65/utf8>>.",
	    <<65>>),
    check(
	    fun() -> <<350/utf8>> = <<197,158>> end,
	    "<<350/utf8>> = <<197,158>>.",
	    <<197,158>>),
    check(
	    fun() -> <<$b,$j,$\303,$\266,$r,$n>> = <<"bj\366rn"/utf8>> end,
	    "<<$b,$j,$\303,$\266,$r,$n>> = <<\"bj\366rn\"/utf8>>.",
	    <<$b,$j,$\303,$\266,$r,$n>>),

    %% UTF-16.
    check(
	    fun() -> <<0,65>> = <<65/utf16>> end,
	    "<<0,65>> = <<65/utf16>>.",
	    <<0,65>>),
    check(
	    fun() -> <<16#D8,16#08,16#DF,16#45>> = <<16#12345/utf16>> end,
	    "<<16#D8,16#08,16#DF,16#45>> = <<16#12345/utf16>>.",
	    <<16#D8,16#08,16#DF,16#45>>),
    check(
	    fun() -> <<16#08,16#D8,16#45,16#DF>> = <<16#12345/little-utf16>> end,
	    "<<16#08,16#D8,16#45,16#DF>> = <<16#12345/little-utf16>>.",
	    <<16#08,16#D8,16#45,16#DF>>),

    check(
	    fun() -> <<350/utf16>> = <<1,94>> end,
	    "<<350/utf16>> = <<1,94>>.",
	    <<1,94>>),
    check(
	    fun() -> <<350/little-utf16>> = <<94,1>> end,
	    "<<350/little-utf16>> = <<94,1>>.",
	    <<94,1>>),
    check(
	    fun() -> <<16#12345/utf16>> = <<16#D8,16#08,16#DF,16#45>> end,
	    "<<16#12345/utf16>> = <<16#D8,16#08,16#DF,16#45>>.",
	    <<16#D8,16#08,16#DF,16#45>>),
    check(
	    fun() -> <<16#12345/little-utf16>> = <<16#08,16#D8,16#45,16#DF>> end,
	    "<<16#12345/little-utf16>> = <<16#08,16#D8,16#45,16#DF>>.",
	    <<16#08,16#D8,16#45,16#DF>>),

    %% UTF-32.
    check(
	    fun() -> <<16#12345/utf32>> = <<16#0,16#01,16#23,16#45>> end,
	    "<<16#12345/utf32>> = <<16#0,16#01,16#23,16#45>>.",
	    <<16#0,16#01,16#23,16#45>>),
    check(
	    fun() -> <<16#0,16#01,16#23,16#45>> = <<16#12345/utf32>> end,
	    "<<16#0,16#01,16#23,16#45>> = <<16#12345/utf32>>.",
	    <<16#0,16#01,16#23,16#45>>),
    check(
	    fun() -> <<16#12345/little-utf32>> = <<16#45,16#23,16#01,16#00>> end,
	    "<<16#12345/little-utf32>> = <<16#45,16#23,16#01,16#00>>.",
	    <<16#45,16#23,16#01,16#00>>),
    check(
	    fun() -> <<16#12345/little-utf32>> end,
	    "<<16#12345/little-utf32>>.",
	    <<16#45,16#23,16#01,16#00>>),

    %% Mixed.
    check(
	    fun() -> <<16#41,16#12345/utf32,16#0391:16,16#2E:8>> end,
	    "<<16#41,16#12345/utf32,16#0391:16,16#2E:8>>.",
	    <<16#41,16#00,16#01,16#23,16#45,16#03,16#91,16#2E>>),
    ok.


%% OTP-8133. Bit comprehension bug.
otp_8133(Config) when is_list(Config) ->
    check(
            fun() ->
                  E = fun(N) ->
                              if
                                  is_integer(N) -> <<N/integer>>;
                                  true -> throw(foo)
                              end
                      end,
                  try << << (E(V))/binary >> || V <- [1,2,3,a] >>
                  catch foo -> ok
                  end
            end,
            "begin
                 E = fun(N) ->
                            if is_integer(N) -> <<N/integer>>;
                               true -> throw(foo)
                            end
                     end,
                 try << << (E(V))/binary >> || V <- [1,2,3,a] >>
                 catch foo -> ok
                 end
             end.",
            ok),
    check(
            fun() ->
                  E = fun(N) ->
                              if
                                  is_integer(N) -> <<N/integer>>;

                                  true -> erlang:error(foo)
                              end
                      end,
                  try << << (E(V))/binary >> || V <- [1,2,3,a] >>
                  catch error:foo -> ok
                  end
            end,
            "begin
                 E = fun(N) ->
                            if is_integer(N) -> <<N/integer>>;
                               true -> erlang:error(foo)
                            end
                     end,
                 try << << (E(V))/binary >> || V <- [1,2,3,a] >>
                 catch error:foo -> ok
                 end
             end.",
            ok),
    ok.

%% OTP-10622. Bugs.
otp_10622(Config) when is_list(Config) ->
    check(fun() -> <<0>> = <<"\x{400}">> end,
          "<<0>> = <<\"\\x{400}\">>. ",
          <<0>>),
    check(fun() -> <<"\x{aa}ff"/utf8>> = <<"\x{aa}ff"/utf8>> end,
          "<<\"\\x{aa}ff\"/utf8>> = <<\"\\x{aa}ff\"/utf8>>. ",
          <<"Â\xaaff">>),
    %% The same bug as last example:
    check(fun() -> case <<"foo"/utf8>> of
                       <<"foo"/utf8>> -> true
                   end
          end,
          "case <<\"foo\"/utf8>> of <<\"foo\"/utf8>> -> true end.",
          true),
    check(fun() -> <<"\x{400}"/utf8>> = <<"\x{400}"/utf8>> end,
          "<<\"\\x{400}\"/utf8>> = <<\"\\x{400}\"/utf8>>. ",
          <<208,128>>),
    error_check("<<\"\\x{aaa}\">> = <<\"\\x{aaa}\">>.",
                {badmatch,<<"\xaa">>}),

    check(fun() -> [a || <<"\x{aaa}">> <= <<2703:16>>] end,
          "[a || <<\"\\x{aaa}\">> <= <<2703:16>>]. ",
          []),
    check(fun() -> [a || <<"\x{aa}"/utf8>> <= <<"\x{aa}"/utf8>>] end,
          "[a || <<\"\\x{aa}\"/utf8>> <= <<\"\\x{aa}\"/utf8>>]. ",
          [a]),
    check(fun() -> [a || <<"\x{aa}x"/utf8>> <= <<"\x{aa}y"/utf8>>] end,
          "[a || <<\"\\x{aa}x\"/utf8>> <= <<\"\\x{aa}y\"/utf8>>]. ",
          []),
    check(fun() -> [a || <<"\x{aaa}">> <= <<"\x{aaa}">>] end,
          "[a || <<\"\\x{aaa}\">> <= <<\"\\x{aaa}\">>]. ",
          []),
    check(fun() -> [a || <<"\x{aaa}"/utf8>> <= <<"\x{aaa}"/utf8>>] end,
          "[a || <<\"\\x{aaa}\"/utf8>> <= <<\"\\x{aaa}\"/utf8>>]. ",
          [a]),

    ok.

%% OTP-13228. ERL-32: non-local function handler bug.
otp_13228(_Config) ->
    LFH = {value, fun(foo, [io_fwrite]) -> worked end},
    EFH = {value, fun({io, fwrite}, [atom]) -> io_fwrite end},
    {value, worked, []} = parse_and_run("foo(io:fwrite(atom)).", LFH, EFH).

%% OTP-14826: more accurate stacktrace.
otp_14826(_Config) ->
    backtrace_check("fun(P) when is_pid(P) -> true end(a).",
                    function_clause,
                    [{erl_eval,'-inside-an-interpreted-fun-',[a],[]},
                     {erl_eval,eval_fun,8},
                     ?MODULE]),
    backtrace_check("B.",
                    {unbound_var, 'B'},
                    [{erl_eval,expr,2}, ?MODULE]),
    backtrace_check("B.",
                    {unbound, 'B'},
                    [{erl_eval,expr,6}, ?MODULE],
                    none, none),
    backtrace_check("1/0.",
                    badarith,
                    [{erlang,'/',[1,0],[]},
                     {erl_eval,do_apply,7}]),
    backtrace_catch("catch 1/0.",
                    badarith,
                    [{erlang,'/',[1,0],[]},
                     {erl_eval,do_apply,7}]),
    check(fun() -> catch exit(foo) end,
          "catch exit(foo).",
          {'EXIT', foo}),
    check(fun() -> catch throw(foo) end,
          "catch throw(foo).",
          foo),
    backtrace_check("try 1/0 after foo end.",
                    badarith,
                    [{erlang,'/',[1,0],[]},
                     {erl_eval,do_apply,7}]),
    backtrace_catch("catch (try 1/0 after foo end).",
                    badarith,
                    [{erlang,'/',[1,0],[]},
                     {erl_eval,do_apply,7}]),
    backtrace_catch("try catch 1/0 after foo end.",
                    badarith,
                    [{erlang,'/',[1,0],[]},
                     {erl_eval,do_apply,7}]),
    backtrace_check("try a of b -> bar after foo end.",
                    {try_clause,a},
                    [{erl_eval,try_clauses,10}]),
    check(fun() -> X = try foo:bar() catch A:B:C -> {A,B} end, X end,
          "try foo:bar() catch A:B:C -> {A,B} end.",
          {error, undef}),
    backtrace_check("C = 4, try foo:bar() catch A:B:C -> {A,B,C} end.",
                    stacktrace_bound,
                    [{erl_eval,check_stacktrace_vars,5},
                     {erl_eval,try_clauses,10}],
                    none, none),
    backtrace_catch("catch (try a of b -> bar after foo end).",
                    {try_clause,a},
                    [{erl_eval,try_clauses,10}]),
    backtrace_check("try 1/0 catch exit:a -> foo end.",
                    badarith,
                    [{erlang,'/',[1,0],[]},
                     {erl_eval,do_apply,7}]),
    Es = [{'try',1,[{call,1,{remote,1,{atom,1,foo},{atom,1,bar}},[]}],
           [],
           [{clause,1,[{tuple,1,[{var,1,'A'},{var,1,'B'},{atom,1,'C'}]}],
             [],[{tuple,1,[{var,1,'A'},{var,1,'B'},{atom,1,'C'}]}]}],[]}],
    try
        erl_eval:exprs(Es, [], none, none),
        ct:fail(stacktrace_variable)
    catch
        error:{illegal_stacktrace_variable,{atom,1,'C'}}:S ->
            [{erl_eval,check_stacktrace_vars,5,_},
             {erl_eval,try_clauses,10,_}|_] = S
    end,
    backtrace_check("{1,1} = {A = 1, A = 2}.",
                    {badmatch, 1},
                    [erl_eval, {lists,foldl,3}]),
    backtrace_check("case a of a when foo:bar() -> x end.",
                    guard_expr,
                    [{erl_eval,guard0,4}], none, none),
    backtrace_check("case a of foo() -> ok end.",
                    {illegal_pattern,{call,1,{atom,1,foo},[]}},
                    [{erl_eval,match,6}], none, none),
    backtrace_check("case a of b -> ok end.",
                    {case_clause,a},
                    [{erl_eval,case_clauses,8}, ?MODULE]),
    backtrace_check("if a =:= b -> ok end.",
                    if_clause,
                    [{erl_eval,if_clauses,7}, ?MODULE]),
    backtrace_check("fun A(b) -> ok end(a).",
                    function_clause,
                    [{erl_eval,'-inside-an-interpreted-fun-',[a],[]},
                     {erl_eval,eval_named_fun,10},
                     ?MODULE]),
    backtrace_check("[A || A <- a].",
                    {bad_generator, a},
                    [{erl_eval,eval_generate,9}, {erl_eval, eval_lc, 7}]),
    backtrace_check("<< <<A>> || <<A>> <= a>>.",
                    {bad_generator, a},
                    [{erl_eval,eval_b_generate,9}, {erl_eval, eval_bc, 7}]),
    backtrace_check("[A || A <- [1], begin a end].",
                    {bad_filter, a},
                    [{erl_eval,eval_filter,7}, {erl_eval, eval_generate, 9}]),
    fun() ->
            {'EXIT', {{badarity, {_Fun, []}}, BT}} =
                (catch parse_and_run("fun(A) -> A end().")),
            check_backtrace([{erl_eval,do_apply,6}, ?MODULE], BT)
    end(),
    fun() ->
            {'EXIT', {{badarity, {_Fun, []}}, BT}} =
                (catch parse_and_run("fun F(A) -> A end().")),
            check_backtrace([{erl_eval,do_apply,6}, ?MODULE], BT)
    end(),
    backtrace_check("foo().",
                    undef,
                    [{erl_eval,foo,0},{erl_eval,local_func,8}],
                    none, none),
    backtrace_check("a orelse false.",
                    {badarg, a},
                    [{erl_eval,expr,6}, ?MODULE]),
    backtrace_check("a andalso false.",
                    {badarg, a},
                    [{erl_eval,expr,6}, ?MODULE]),
    backtrace_check("t = u.",
                    {badmatch, u},
                    [{erl_eval,expr,6}, ?MODULE]),
    backtrace_check("{math,sqrt}(2).",
                    {badfun, {math,sqrt}},
                    [{erl_eval,expr,6}, ?MODULE]),
    backtrace_check("erl_eval_SUITE:simple().",
                    simple,
                    [{?MODULE,simple1,0},{?MODULE,simple,0},erl_eval]),
    Args = [{integer,1,I} || I <- lists:seq(1, 30)],
    backtrace_check("fun(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,"
                    "19,20,21,22,23,24,25,26,27,28,29,30) -> a end.",
                    {argument_limit,
                     {'fun',1,[{clause,1,Args,[],[{atom,1,a}]}]}},
                    [{erl_eval,expr,6}, ?MODULE]),
    backtrace_check("fun F(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,"
                    "19,20,21,22,23,24,25,26,27,28,29,30) -> a end.",
                    {argument_limit,
                     {named_fun,1,'F',[{clause,1,Args,[],[{atom,1,a}]}]}},
                    [{erl_eval,expr,6}, ?MODULE]),
    backtrace_check("#r{}.",
                    {undef_record,r},
                    [{erl_eval,expr,6}, ?MODULE],
                    none, none),
    %% eval_bits
    backtrace_check("<<100:8/bitstring>>.",
                    badarg,
                    [{eval_bits,eval_exp_field,6},
                     eval_bits,eval_bits,erl_eval]),
    backtrace_check("<<100:8/foo>>.",
                    {undefined_bittype,foo},
                    [{eval_bits,make_bit_type,4},eval_bits,
                     eval_bits,eval_bits],
                    none, none),
    backtrace_check("B = <<\"foo\">>, <<B/binary-unit:7>>.",
                    badarg,
                    [{eval_bits,eval_exp_field,6},
                     eval_bits,eval_bits,erl_eval],
                    none, none),

    %% eval_bits with error info
    {error_info, #{cause := _, override_segment_position := 1}} =
        error_info_catch("<<100:8/bitstring>>.", badarg),

    {error_info, #{cause := _, override_segment_position := 2}} =
        error_info_catch("<<0:8, 100:8/bitstring>>.", badarg),

    ok.

simple() ->
    A = simple1(),
    {A}.

simple1() ->
    %% If the compiler could see that this function would always
    %% throw an error exception, it would rewrite simple() like this:
    %%
    %%   simple() -> simple1().
    %%
    %% That would change the stacktrace. To prevent the compiler from
    %% doing that optimization, we must obfuscate the code.
    case get(a_key_that_is_not_defined) of
        undefined -> erlang:error(simple);
        WillNeverHappen -> WillNeverHappen
    end.

custom_stacktrace(Config) when is_list(Config) ->
    EFH = {value, fun custom_stacktrace_eval_handler/3},

    backtrace_check("1 + atom.", badarith,
                    [{erlang,'+',[1,atom]}, mystack(1)], none, EFH),
    backtrace_check("\n1 + atom.", badarith,
                    [{erlang,'+',[1,atom]}, mystack(2)], none, EFH),

    backtrace_check("lists:flatten(atom).", function_clause,
                    [{lists,flatten,[atom]}, mystack(1)], none, EFH),

    backtrace_check("invalid andalso true.", {badarg, invalid},
                    [mystack(1)], none, EFH),
    backtrace_check("invalid orelse true.", {badarg, invalid},
                    [mystack(1)], none, EFH),

    backtrace_check("invalid = valid.", {badmatch, valid},
                    [erl_eval, mystack(1)], none, EFH),

    backtrace_check("1:2.", {badexpr, ':'},
                    [erl_eval, mystack(1)], none, EFH),

    backtrace_check("Unknown.", {unbound, 'Unknown'},
                    [erl_eval, mystack(1)], none, EFH),

    backtrace_check("#unknown{}.", {undef_record,unknown},
                    [erl_eval, mystack(1)], none, EFH),
    backtrace_check("#unknown{foo=bar}.", {undef_record,unknown},
                    [erl_eval, mystack(1)], none, EFH),
    backtrace_check("#unknown.index.", {undef_record,unknown},
                    [erl_eval, mystack(1)], none, EFH),

    backtrace_check("foo(1, 2).", undef,
                    [{erl_eval, foo, 2}, erl_eval, mystack(1)], none, EFH),

    fun() ->
            {'EXIT', {{badarity, {_Fun, []}}, BT}} =
                (catch parse_and_run("fun(A) -> A end().", none, EFH)),
            check_backtrace([erl_eval, mystack(1)], BT)
    end(),

    fun() ->
            {'EXIT', {{badarity, {_Fun, []}}, BT}} =
                (catch parse_and_run("fun F(A) -> A end().", none, EFH)),
            check_backtrace([erl_eval, mystack(1)], BT)
    end(),

    backtrace_check("[X || X <- 1].", {bad_generator, 1},
                    [erl_eval, mystack(1)], none, EFH),
    backtrace_check("[X || <<X>> <= 1].", {bad_generator, 1},
                    [erl_eval, mystack(1)], none, EFH),
    backtrace_check("<<X || X <- 1>>.", {bad_generator, 1},
                    [erl_eval, mystack(1)], none, EFH),
    backtrace_check("<<X || <<X>> <= 1>>.", {bad_generator, 1},
                    [erl_eval, mystack(1)], none, EFH),

    backtrace_check("if false -> true end.", if_clause,
                    [erl_eval, mystack(1)], none, EFH),
    backtrace_check("case 0 of 1 -> true end.", {case_clause, 0},
                    [erl_eval, mystack(1)], none, EFH),
    backtrace_check("try 0 of 1 -> true after ok end.", {try_clause, 0},
                    [mystack(1)], none, EFH),

    backtrace_check("fun(0) -> 1 end(1).", function_clause,
                    [{erl_eval,'-inside-an-interpreted-fun-', [1]}, erl_eval, mystack(1)],
                    none, EFH),
    backtrace_check("fun F(0) -> 1 end(1).", function_clause,
                    [{erl_eval,'-inside-an-interpreted-fun-', [1]}, erl_eval, mystack(1)],
                    none, EFH),

    fun() ->
            {'EXIT', {{illegal_pattern,_}, BT}} =
                (catch parse_and_run("make_ref() = 1.", none, EFH)),
            check_backtrace([erl_eval, mystack(1)], BT)
    end(),

    %% eval_bits
    backtrace_check("<<100:8/bitstring>>.",
                    badarg,
                    [{eval_bits,eval_exp_field,6}, mystack(1)],
                    none, EFH),
    backtrace_check("<<100:8/foo>>.",
                    {undefined_bittype,foo},
                    [{eval_bits,make_bit_type,4}, mystack(1)],
                    none, EFH),
    backtrace_check("B = <<\"foo\">>, <<B/binary-unit:7>>.",
                    badarg,
                    [{eval_bits,eval_exp_field,6}, mystack(1)],
                    none, EFH),

    ok.

mystack(Line) ->
    {my_module, my_function, 0, [{file, "evaluator"}, {line, Line}]}.

custom_stacktrace_eval_handler(Ann, FunOrModFun, Args) ->
    try
        case FunOrModFun of
            {Mod, Fun} -> apply(Mod, Fun, Args);
            Fun -> apply(Fun, Args)
        end
    catch
        Kind:Reason:Stacktrace ->
            %% Take everything up to the evaluation function
            Pruned =
                lists:takewhile(fun
                  ({erl_eval_SUITE,backtrace_check,5,_}) -> false;
                  (_) -> true
                end, Stacktrace),
            %% Now we prune any shared code path from erl_eval
            {current_stacktrace, Current} =
                erlang:process_info(self(), current_stacktrace),
            Reversed = drop_common(lists:reverse(Current), lists:reverse(Pruned)),
            Location = [{file, "evaluator"}, {line, erl_anno:line(Ann)}],
            %% Add our file+line information at the bottom
            Custom = lists:reverse([{my_module, my_function, 0, Location} | Reversed]),
            erlang:raise(Kind, Reason, Custom)
    end.

drop_common([H | T1], [H | T2]) -> drop_common(T1, T2);
drop_common([H | T1], T2) -> drop_common(T1, T2);
drop_common([], [{?MODULE, custom_stacktrace_eval_handler, _, _} | T2]) -> T2;
drop_common([], T2) -> T2.

%% Simple cases, just to cover some code.
funs(Config) when is_list(Config) ->
    do_funs(none, none),
    do_funs(lfh(), none),
    do_funs(none, efh()),
    do_funs(lfh(), efh()),
    do_funs(none, ann_efh()),
    do_funs(lfh(), ann_efh()),

    error_check("nix:foo().", {access_not_allowed,nix}, lfh(), efh()),
    error_check("nix:foo().", {access_not_allowed,nix}, lfh(), ann_efh()),
    error_check("bar().", undef, none, none),

    check(fun() -> F1 = fun(F,N) -> ?MODULE:count_down(F, N) end,
                         F1(F1, 1000) end,
                "begin F1 = fun(F,N) -> count_down(F, N) end,"
                "F1(F1,1000) end.",
		0, ['F1'], lfh(), none),

    check(fun() -> F1 = fun(F,N) -> ?MODULE:count_down(F, N) end,
                         F1(F1, 1000) end,
                "begin F1 = fun(F,N) -> count_down(F, N) end,"
                "F1(F1,1000) end.",
		0, ['F1'], lfh_value(), none),

    check(fun() -> F1 = fun(F,N) -> ?MODULE:count_down(F, N) end,
                         F1(F1, 1000) end,
                "begin F1 = fun(F,N) -> count_down(F, N) end,"
                "F1(F1,1000) end.",
		0, ['F1'], lfh_value_extra(), none),

    check(fun() -> F1 = fun(F,N) -> ?MODULE:count_down(F, N) end,
                         F1(F1, 1000) end,
                "begin F1 = fun(F,N) -> count_down(F, N) end,"
                "F1(F1,1000) end.",
		0, ['F1'], {?MODULE,local_func_value}, none),
    %% This is not documented, and only for backward compatibility (good!).
    B0 = erl_eval:new_bindings(),
    check(fun() -> is_function(?MODULE:count_down_fun()) end,
                "begin is_function(count_down_fun()) end.",
                true, [], {?MODULE,local_func,[B0]},none),

    EF = fun({timer,sleep}, As) when length(As) == 1 -> exit({got_it,sleep});
            ({M,F}, As) -> apply(M, F, As)
         end,
    EFH = {value, EF},
    error_check("apply(timer, sleep, [1]).", got_it, none, EFH),
    error_check("begin F = fun(T) -> timer:sleep(T) end,F(1) end.",
                      got_it, none, EFH),

    AnnEF = fun(1, {timer,sleep}, As) when length(As) == 1 -> exit({got_it,sleep});
               (1, {M,F}, As) -> apply(M, F, As)
         end,
    AnnEFH = {value, AnnEF},
    error_check("apply(timer, sleep, [1]).", got_it, none, AnnEFH),
    error_check("begin F = fun(T) -> timer:sleep(T) end,F(1) end.",
                      got_it, none, AnnEFH),

    error_check("fun a:b/0().", undef),

    MaxArgs = 20,
    [true] =
        lists:usort([run_many_args(SAs) || SAs <- many_args(MaxArgs)]),
    {'EXIT',{{argument_limit,_},_}} =
        (catch run_many_args(many_args1(MaxArgs+1))),

    check(fun() -> M = lists, F = fun M:reverse/1,
			 [1,2] = F([2,1]), ok end,
		"begin M = lists, F = fun M:reverse/1,"
		" [1,2] = F([2,1]), ok end.",
		ok),

    %% Test that {M,F} is not accepted as a fun.
    error_check("{" ?MODULE_STRING ",module_info}().",
		{badfun,{?MODULE,module_info}}),

    %% Test defining and calling a fun based on an auto-imported BIF.
    check(fun() ->
                  F = fun is_binary/1,
                  true = F(<<>>),
                  false = F(a)
          end,
          ~S"""
           F = fun is_binary/1,
           true = F(<<>>),
           false = F(a).
           """,
          false, ['F'], lfh(), none),

    %% Test defining and calling a local fun defined in the shell.
    check(fun() ->
                  D = fun my_div/2,
                  3 = D(15, 5)
          end,
          ~S"""
           D = fun my_div/2,
           3 = D(15, 5).
           """,
          3, ['D'], lfh(), efh()),

    ok.

my_div(A, B) ->
    A div B.

run_many_args({S, As}) ->
    apply(eval_string(S), As) =:= As.

many_args(N) ->
    [many_args1(I) || I <- lists:seq(1, N)].

many_args1(N) ->
    F = fun(L, P) ->
                tl(lists:flatten([","++P++integer_to_list(E) || E <- L]))
        end,
    L = lists:seq(1, N),
    T = F(L, "V"),
    S = lists:flatten(io_lib:format("fun(~s) -> [~s] end.", [T, T])),
    {S, L}.

do_funs(LFH, EFH) ->
    %% LFH is not really used by these examples...

    %% These tests do not prove that tail recursive functions really
    %% work (that the process does not grow); one should also run them
    %% manually with 1000 replaced by 1000000.

    M = atom_to_list(?MODULE),
    check(fun() -> F1 = fun(F,N) -> ?MODULE:count_down(F, N) end,
                         F1(F1, 1000) end,
                concat(["begin F1 = fun(F,N) -> ", M,
                        ":count_down(F, N) end, F1(F1,1000) end."]),
		0, ['F1'], LFH, EFH),
    check(fun() -> F1 = fun(F,N) -> apply(?MODULE,count_down,[F,N])
                              end, F1(F1, 1000) end,
                concat(["begin F1 = fun(F,N) -> apply(", M,
                        ",count_down,[F, N]) end, F1(F1,1000) end."]),
		0, ['F1'], LFH, EFH),
    check(fun() -> F = fun(F,N) when N > 0 -> apply(F,[F,N-1]);
                                (_F,0) -> ok end,
                         F(F, 1000)
                end,
                "begin F = fun(F,N) when N > 0 -> apply(F,[F,N-1]);"
                             "(_F,0) -> ok end,"
                       "F(F, 1000) end.",
                ok, ['F'], LFH, EFH),
    check(fun() -> F = fun(F,N) when N > 0 ->
                                     apply(erlang,apply,[F,[F,N-1]]);
                                (_F,0) -> ok end,
                         F(F, 1000)
                end,
                "begin F = fun(F,N) when N > 0 ->"
                                   "apply(erlang,apply,[F,[F,N-1]]);"
                             "(_F,0) -> ok end,"
                       "F(F, 1000) end.",
                ok, ['F'], LFH, EFH),
    check(fun() -> F = count_down_fun(),
                         SF = fun(SF, F1, N) -> F(SF, F1, N) end,
                         SF(SF, F, 1000) end,
                concat(["begin F = ", M, ":count_down_fun(),"
                        "SF = fun(SF, F1, N) -> F(SF, F1, N) end,"
                        "SF(SF, F, 1000) end."]),
                ok, ['F','SF'], LFH, EFH),


    check(fun() -> F = fun(X) -> A = 1+X, {X,A} end,
                         true = {2,3} == F(2) end,
                "begin F = fun(X) -> A = 1+X, {X,A} end,
                       true = {2,3} == F(2) end.", true, ['F'], LFH, EFH),
    check(fun() -> F = fun(X) -> erlang:'+'(X,2) end,
		   true = 3 == F(1) end,
	  "begin F = fun(X) -> erlang:'+'(X,2) end,"
	  "      true = 3 == F(1) end.", true, ['F'],
	  LFH, EFH),
    check(fun() -> F = fun(X) -> byte_size(X) end,
                         ?MODULE:do_apply(F,<<"hej">>) end,
                concat(["begin F = fun(X) -> size(X) end,",
                        M,":do_apply(F,<<\"hej\">>) end."]),
                3, ['F'], LFH, EFH),

    check(fun() -> F1 = fun(X, Z) -> {X,Z} end,
                         Z = 5,
                         F2 = fun(X, Y) -> F1(Z,{X,Y}) end,
                         F3 = fun(X, Y) -> {a,F1(Z,{X,Y})} end,
                         {5,{x,y}} = F2(x,y),
                         {a,{5,{y,x}}} = F3(y,x),
                         {5,{5,y}} = F2(Z,y),
                         true = {5,{x,5}} == F2(x,Z) end,
                "begin F1 = fun(X, Z) -> {X,Z} end,
                       Z = 5,
                       F2 = fun(X, Y) -> F1(Z,{X,Y}) end,
                       F3 = fun(X, Y) -> {a,F1(Z,{X,Y})} end,
                       {5,{x,y}} = F2(x,y),
                       {a,{5,{y,x}}} = F3(y,x),
                       {5,{5,y}} = F2(Z,y),
                       true = {5,{x,5}} == F2(x,Z) end.",
                true, ['F1','Z','F2','F3'], LFH, EFH),
    check(fun() -> F = fun(X) -> byte_size(X) end,
                         F2 = fun(Y) -> F(Y) end,
                         ?MODULE:do_apply(F2,<<"hej">>) end,
                concat(["begin F = fun(X) -> size(X) end,",
                        "F2 = fun(Y) -> F(Y) end,",
                        M,":do_apply(F2,<<\"hej\">>) end."]),
                3, ['F','F2'], LFH, EFH),
    check(fun() -> Z = 5, F = fun(X) -> {Z,X} end,
                         F2 = fun(Z) -> F(Z) end, F2(3) end,
                "begin Z = 5, F = fun(X) -> {Z,X} end,
                       F2 = fun(Z) -> F(Z) end, F2(3) end.",
                {5,3},['F','F2','Z'], LFH, EFH),
    check(fun() -> F = fun(Z) -> Z end,
                         F2 = fun(X) -> F(X), Z = {X,X}, Z end,
                         {1,1} = F2(1), Z = 7, Z end,
                "begin F = fun(Z) -> Z end,
                       F2 = fun(X) -> F(X), Z = {X,X}, Z end,
                       {1,1} = F2(1), Z = 7, Z end.", 7, ['F','F2','Z'],
                LFH, EFH),
    check(fun() -> F = fun(F, N) -> [?MODULE:count_down(F,N) || X <-[1]]
                             end, F(F,2) end,
                concat(["begin F = fun(F, N) -> [", M,
                       ":count_down(F,N) || X <-[1]] end, F(F,2) end."]),
                [[[0]]], ['F'], LFH, EFH),
    ok.

count_down(F, N) when N > 0 ->
    F(F, N-1);
count_down(_F, N) ->
    N.

count_down_fun() ->
    fun(SF,F,N) when N > 0 -> SF(SF,F,N-1);
       (_SF,_F,_N) -> ok
    end.

do_apply(F, V) ->
    F(V).

lfh() ->
    {eval, fun(F, As, Bs) -> local_func(F, As, Bs) end}.

local_func(F, As0, Bs0) when is_atom(F) ->
    {As,Bs} = erl_eval:expr_list(As0, Bs0, lfh()),
    case erlang:function_exported(?MODULE, F, length(As)) of
	true ->
	    {value,apply(?MODULE, F, As),Bs};
	false ->
	    {value,apply(shell_default, F, As),Bs}
    end.

lfh_value_extra() ->
    %% Not documented.
    {value, fun(F, As, a1, a2) -> local_func_value(F, As) end, [a1, a2]}.

lfh_value() ->
    {value, fun(F, As) -> local_func_value(F, As) end}.

local_func_value(F, As) when is_atom(F) ->
    case erlang:function_exported(?MODULE, F, length(As)) of
	true ->
	    apply(?MODULE, F, As);
	false ->
	    apply(shell_default, F, As)
    end.

efh() ->
    {value, fun(F, As) -> external_func(F, As) end}.

ann_efh() ->
    {value, fun(_Ann, F, As) -> external_func(F, As) end}.

external_func({M,_}, _As) when M == nix ->
    exit({{access_not_allowed,M},[mfa]});
external_func(F, As) when is_function(F) ->
    apply(F, As);
external_func({M,F}, As) ->
    apply(M, F, As).



%% Test try-of-catch-after-end statement.
try_catch(Config) when is_list(Config) ->
    %% Match in of with catch
    check(fun() -> try 1 of 1 -> 2 catch _:_ -> 3 end end,
		"try 1 of 1 -> 2 catch _:_ -> 3 end.", 2),
    check(fun() -> try 1 of 1 -> 2; 3 -> 4 catch _:_ -> 5 end end,
		"try 1 of 1 -> 2; 3 -> 4 catch _:_ -> 5 end.", 2),
    check(fun() -> try 3 of 1 -> 2; 3 -> 4 catch _:_ -> 5 end end,
		"try 3 of 1 -> 2; 3 -> 4 catch _:_ -> 5 end.", 4),
    %% Just after
    check(fun () -> X = try 1 after put(try_catch, 2) end,
			  {X,get(try_catch)} end,
		"begin X = try 1 after put(try_catch, 2) end, "
		"{X,get(try_catch)} end.", {1,2}),
    %% Match in of with after
    check(fun() -> X = try 1 of 1 -> 2 after put(try_catch, 3) end,
			 {X,get(try_catch)} end,
		"begin X = try 1 of 1 -> 2 after put(try_catch, 3) end, "
		"{X,get(try_catch)} end.", {2,3}),
    check(fun() -> X = try 1 of 1 -> 2; 3 -> 4
			     after put(try_catch, 5) end,
			 {X,get(try_catch)} end,
		"begin X = try 1 of 1 -> 2; 3 -> 4 "
		"          after put(try_catch, 5) end, "
		"      {X,get(try_catch)} end.", {2,5}),
    check(fun() -> X = try 3 of 1 -> 2; 3 -> 4
			     after put(try_catch, 5) end,
			 {X,get(try_catch)} end,
		"begin X = try 3 of 1 -> 2; 3 -> 4 "
		"          after put(try_catch, 5) end, "
		"      {X,get(try_catch)} end.", {4,5}),
    %% Nomatch in of
    error_check("try 1 of 2 -> 3 catch _:_ -> 4 end.",
		      {try_clause,1}),
    %% Nomatch in of with after
    check(fun () -> {'EXIT',{{try_clause,1},_}} =
			      begin catch try 1 of 2 -> 3
				          after put(try_catch, 4) end end,
			  get(try_catch) end,
		"begin {'EXIT',{{try_clause,1},_}} = "
		"          begin catch try 1 of 2 -> 3 "
		"                      after put(try_catch, 4) end end, "
		"      get(try_catch) end. ", 4),
    %% Exception in try
    check(fun () -> try 1=2 catch error:{badmatch,2} -> 3 end end,
		"try 1=2 catch error:{badmatch,2} -> 3 end.", 3),
    check(fun () -> try 1=2 of 3 -> 4
			  catch error:{badmatch,2} -> 5 end end,
		"try 1=2 of 3 -> 4 "
		"catch error:{badmatch,2} -> 5 end.", 5),
    %% Exception in try with after
    check(fun () -> X = try 1=2
			      catch error:{badmatch,2} -> 3
			      after put(try_catch, 4) end,
			  {X,get(try_catch)} end,
		"begin X = try 1=2 "
		"          catch error:{badmatch,2} -> 3 "
		"          after put(try_catch, 4) end, "
		"      {X,get(try_catch)} end. ", {3,4}),
    check(fun () -> X = try 1=2 of 3 -> 4
			      catch error:{badmatch,2} -> 5
			      after put(try_catch, 6) end,
			  {X,get(try_catch)} end,
		"begin X = try 1=2 of 3 -> 4"
		"          catch error:{badmatch,2} -> 5 "
		"          after put(try_catch, 6) end, "
		"      {X,get(try_catch)} end. ", {5,6}),
    %% Uncaught exception
    error_check("try 1=2 catch error:undefined -> 3 end. ",
		      {badmatch,2}),
    error_check("try 1=2 of 3 -> 4 catch error:undefined -> 5 end. ",
		      {badmatch,2}),
    %% Uncaught exception with after
    check(fun () -> {'EXIT',{{badmatch,2},_}} =
			      begin catch try 1=2
					  after put(try_catch, 3) end end,
			  get(try_catch) end,
		"begin {'EXIT',{{badmatch,2},_}} = "
		"          begin catch try 1=2 "
		"                      after put(try_catch, 3) end end, "
		"      get(try_catch) end. ", 3),
    check(fun () -> {'EXIT',{{badmatch,2},_}} =
			      begin catch try 1=2 of 3 -> 4
					  after put(try_catch, 5) end end,
			  get(try_catch) end,
		"begin {'EXIT',{{badmatch,2},_}} = "
		"          begin catch try 1=2 of 3 -> 4"
		"                      after put(try_catch, 5) end end, "
		"      get(try_catch) end. ", 5),
    check(fun () -> {'EXIT',{{badmatch,2},_}} =
			      begin catch try 1=2 catch error:undefined -> 3
					  after put(try_catch, 4) end end,
			  get(try_catch) end,
		"begin {'EXIT',{{badmatch,2},_}} = "
		"          begin catch try 1=2 catch error:undefined -> 3 "
		"                      after put(try_catch, 4) end end, "
		"      get(try_catch) end. ", 4),
    check(fun () -> {'EXIT',{{badmatch,2},_}} =
			      begin catch try 1=2 of 3 -> 4
					  catch error:undefined -> 5
					  after put(try_catch, 6) end end,
			  get(try_catch) end,
		"begin {'EXIT',{{badmatch,2},_}} = "
		"          begin catch try 1=2 of 3 -> 4 "
		"                      catch error:undefined -> 5 "
		"                      after put(try_catch, 6) end end, "
		"      get(try_catch) end. ", 6),
    ok.


%% OTP-7933.
eval_expr_5(Config) when is_list(Config) ->
    {ok,Tokens ,_} =
	erl_scan:string("if a+4 == 4 -> yes; true -> no end. "),
    {ok, [Expr]} = erl_parse:parse_exprs(Tokens),
    {value, no, []} = erl_eval:expr(Expr, [], none, none, none),
    no = erl_eval:expr(Expr, [], none, none, value),
    try
	erl_eval:expr(Expr, [], none, none, 4711),
	function_clause = should_never_reach_here
    catch
	error:function_clause ->
	    ok
    end.

zero_width(Config) when is_list(Config) ->
    check(fun() ->
			{'EXIT',{badarg,_}} = (catch <<not_a_number:0>>),
			ok
		end, "begin {'EXIT',{badarg,_}} = (catch <<not_a_number:0>>), "
		"ok end.", ok),
    ok.

eep37(Config) when is_list(Config) ->
    check(fun () -> (fun _(X) -> X end)(42) end,
          "(fun _(X) -> X end)(42).",
          42),
    check(fun () -> (fun _Id(X) -> X end)(42) end,
          "(fun _Id(X) -> X end)(42).", 42),
    check(fun () -> is_function((fun Self() -> Self end)(), 0) end,
          "is_function((fun Self() -> Self end)(), 0).",
          true),
    check(fun () ->
                  F = fun Fact(N) when N > 0 ->
                              N * Fact(N - 1);
                          Fact(0) ->
                              1
                       end,
                  F(6)
          end,
          "(fun Fact(N) when N > 0 -> N * Fact(N - 1); Fact(0) -> 1 end)(6).",
          720),
    ok.

eep43(Config) when is_list(Config) ->
    check(fun () -> #{} end, " #{}.", #{}),
    check(fun () -> #{a => b} end, "#{a => b}.", #{a => b}),
    check(fun () ->
                  Map = #{a => b},
                  {Map#{a := b},Map#{a => c},Map#{d => e}}
          end,
          "begin "
          "    Map = #{a => B=b}, "
          "    {Map#{a := B},Map#{a => c},Map#{d => e}} "
          "end.",
          {#{a => b},#{a => c},#{a => b,d => e}}),
    check(fun () ->
                  lists:map(fun (X) -> X#{price := 0} end,
                            [#{hello => 0, price => nil}])
          end,
          "lists:map(fun (X) -> X#{price := 0} end,
                     [#{hello => 0, price => nil}]).",
          [#{hello => 0, price => 0}]),
    check(fun () ->
		Map = #{ <<33:333>> => "wat" },
		#{ <<33:333>> := "wat" } = Map
	  end,
	  "begin "
	  "   Map = #{ <<33:333>> => \"wat\" }, "
	  "   #{ <<33:333>> := \"wat\" } = Map  "
	  "end.",
	  #{ <<33:333>> => "wat" }),
    check(fun () ->
		K1 = 1,
		K2 = <<42:301>>,
		K3 = {3,K2},
		Map = #{ K1 => 1, K2 => 2, K3 => 3, {2,2} => 4},
		#{ K1 := 1, K2 := 2, K3 := 3, {2,2} := 4} = Map
	  end,
	  "begin "
	  "    K1 = 1, "
	  "    K2 = <<42:301>>, "
	  "    K3 = {3,K2}, "
	  "    Map = #{ K1 => 1, K2 => 2, K3 => 3, {2,2} => 4}, "
	  "    #{ K1 := 1, K2 := 2, K3 := 3, {2,2} := 4} = Map "
	  "end.",
	  #{ 1 => 1, <<42:301>> => 2, {3,<<42:301>>} => 3, {2,2} => 4}),
    check(fun () ->
		X = key,
		(fun(#{X := value}) -> true end)(#{X => value})
	  end,
	  "begin "
	  "    X = key, "
	  "    (fun(#{X := value}) -> true end)(#{X => value}) "
	  "end.",
	  true),

    error_check("[camembert]#{}.", {badmap,[camembert]}),
    error_check("[camembert]#{nonexisting:=v}.", {badmap,[camembert]}),
    error_check("#{} = 1.", {badmatch,1}),
    error_check("[]#{a=>error(bad)}.", bad),
    error_check("(#{})#{nonexisting:=value}.", {badkey,nonexisting}),
    ok.

otp_15035(Config) when is_list(Config) ->
    check(fun() ->
                  fun() when #{} ->
                          a;
                     () when #{a => b} ->
                          b;
                     () when #{a => b} =:= #{a => b} ->
                          c
                  end()
          end,
          "fun() when #{} ->
                   a;
              () when #{a => b} ->
                   b;
              () when #{a => b} =:= #{a => b} ->
                   c
           end().",
          c),
    check(fun() ->
                  F = fun(M) when M#{} ->
                              a;
                         (M) when M#{a => b} ->
                              b;
                         (M) when M#{a := b} ->
                              c;
                         (M) when M#{a := b} =:= M#{a := b} ->
                              d;
                         (M) when M#{a => b} =:= M#{a => b} ->
                              e
                      end,
                  {F(#{}), F(#{a => b})}
          end,
          "fun() ->
                  F = fun(M) when M#{} ->
                              a;
                         (M) when M#{a => b} ->
                              b;
                         (M) when M#{a := b} ->
                              c;
                         (M) when M#{a := b} =:= M#{a := b} ->
                              d;
                         (M) when M#{a => b} =:= M#{a => b} ->
                              e
                      end,
                  {F(#{}), F(#{a => b})}
          end().",
          {e, d}),
    ok.

otp_16439(Config) when is_list(Config) ->
    check(fun() -> + - 5 end, "+ - 5.", -5),
    check(fun() -> - + - 5 end, "- + - 5.", 5),
    check(fun() -> case 7 of - - 7 -> seven end end,
         "case 7 of - - 7 -> seven end.", seven),

    {ok,Ts,_} = erl_scan:string("- #{}. "),
    A = erl_anno:new(1),
    {ok,[{op,A,'-',{map,A,[]}}]} = erl_parse:parse_exprs(Ts),

    ok.

%% Test guard expressions in keys for maps and in sizes in binary matching.

otp_14708(Config) when is_list(Config) ->
    check(fun() -> X = 42, #{{tag,X} := V} = #{{tag,X} => a}, V end,
          "begin X = 42, #{{tag,X} := V} = #{{tag,X} => a}, V end.",
          a),
    check(fun() ->
                  T = {x,y,z},
                  Map = #{x => 99, y => 100},
                  #{element(1, T) := V1, element(2, T) := V2} = Map,
                  {V1, V2}
          end,
          "begin
                  T = {x,y,z},
                  Map = #{x => 99, y => 100},
                  #{element(1, T) := V1, element(2, T) := V2} = Map,
                  {V1, V2}
          end.",
          {99, 100}),
    error_check("#{term_to_binary(42) := _} = #{}.", illegal_guard_expr),

    check(fun() ->
                  <<Sz:16,Body:(Sz-1)/binary>> = <<4:16,1,2,3>>,
                  Body
          end,
          "begin
              <<Sz:16,Body:(Sz-1)/binary>> = <<4:16,1,2,3>>,
             Body
          end.",
          <<1,2,3>>),
    check(fun() ->
                  Sizes = #{0 => 3, 1 => 7},
                  <<SzTag:1,Body:(map_get(SzTag, Sizes))/binary>> =
                      <<1:1,1,2,3,4,5,6,7>>,
                  Body
          end,
          "begin
             Sizes = #{0 => 3, 1 => 7},
             <<SzTag:1,Body:(map_get(SzTag, Sizes))/binary>> =
                 <<1:1,1,2,3,4,5,6,7>>,
             Body
          end.",
          <<1,2,3,4,5,6,7>>),
    error_check("<<X:(process_info(self()))>> = <<>>.", illegal_bitsize),

    ok.

otp_16545(Config) when is_list(Config) ->
    case eval_string("<<$W/utf16-native>> = <<$W/utf16-native>>.") of
        <<$W/utf16-native>> -> ok
    end,
    case eval_string("<<$W/utf32-native>> = <<$W/utf32-native>>.") of
        <<$W/utf32-native>> -> ok
    end,
    check(fun() -> <<10/unsigned,"fgbz":86>> end,
          "<<10/unsigned,\"fgbz\":86>>.",
          <<10,0,0,0,0,0,0,0,0,0,1,152,0,0,0,0,0,0,0,0,0,6,112,0,0,
            0,0,0,0,0,0,0,24,128,0,0,0,0,0,0,0,0,0,122>>),
    check(fun() -> <<"":16/signed>> end,
          "<<\"\":16/signed>>.",
          <<>>),
    error_check("<<\"\":problem/signed>>.", badarg),
    ok.

otp_16865(Config) when is_list(Config) ->
    check(fun() -> << <<>> || <<34:(1/0)>> <= <<"string">> >> end,
          "<< <<>> || <<34:(1/0)>> <= <<\"string\">> >>.",
          <<>>),
    %% The order of evaluation is important. Follow the example set by
    %% compiled code:
    error_check("<< <<>> || <<>> <= <<1:(-1), (fun() -> a = b end())>> >>.",
                {badmatch, b}),
    ok.

eep49(Config) when is_list(Config) ->
    check(fun() ->
                  maybe empty end
          end,
          "maybe empty end.",
          empty),
    check(fun() ->
                  maybe ok ?= ok end
          end,
          "maybe ok ?= ok end.",
          ok),
    check(fun() ->
                  maybe {ok,A} ?= {ok,good}, A end
          end,
          "maybe {ok,A} ?= {ok,good}, A end.",
          good),
    check(fun() ->
                  maybe {ok,A} ?= {ok,good}, {ok,B} ?= {ok,also_good}, {A,B} end
          end,
          "maybe {ok,A} ?= {ok,good}, {ok,B} ?= {ok,also_good}, {A,B} end.",
          {good,also_good}),
    check(fun() ->
                  maybe {ok,A} ?= {ok,good}, {ok,B} ?= {error,wrong}, {A,B} end
          end,
          "maybe {ok,A} ?= {ok,good}, {ok,B} ?= {error,wrong}, {A,B} end.",
          {error,wrong}),

    %% Test maybe ... else ... end.
    check(fun() ->
                  maybe empty else _ -> error end
          end,
          "maybe empty else _ -> error end.",
          empty),
    check(fun() ->
                  maybe ok ?= ok else _ -> error end
          end,
          "maybe ok ?= ok else _ -> error end.",
          ok),
    check(fun() ->
                  maybe ok ?= other else _ -> error end
          end,
          "maybe ok ?= other else _ -> error end.",
          error),
    check(fun() ->
                  maybe {ok,A} ?= {ok,good}, {ok,B} ?= {ok,also_good}, {A,B}
                  else {error,_} -> error end
          end,
          "maybe {ok,A} ?= {ok,good}, {ok,B} ?= {ok,also_good}, {A,B} "
          "else {error,_} -> error end.",
          {good,also_good}),
    check(fun() ->
                  maybe {ok,A} ?= {ok,good}, {ok,B} ?= {error,other}, {A,B}
                  else {error,_} -> error end
          end,
          "maybe {ok,A} ?= {ok,good}, {ok,B} ?= {error,other}, {A,B} "
          "else {error,_} -> error end.",
          error),
    error_check("maybe ok ?= simply_wrong else {error,_} -> error end.",
                {else_clause,simply_wrong}),
    ok.

%% GH-6348/OTP-18297: Lift restrictions for matching of binaries and maps.
binary_and_map_aliases(Config) when is_list(Config) ->
    check(fun() ->
                  <<A:16>> = <<B:8,C:8>> = <<16#cafe:16>>,
                  {A,B,C}
          end,
          "begin <<A:16>> = <<B:8,C:8>> = <<16#cafe:16>>, {A,B,C} end.",
          {16#cafe,16#ca,16#fe}),
    check(fun() ->
                  <<A:8/bits,B:24/bits>> =
                      <<C:16,D:16>> =
                      <<E:8,F:8,G:8,H:8>> =
                      <<16#abcdef57:32>>,
                  {A,B,C,D,E,F,G,H}
          end,
          "begin <<A:8/bits,B:24/bits>> =
                 <<C:16,D:16>> =
                 <<E:8,F:8,G:8,H:8>> =
                 <<16#abcdef57:32>>,
                 {A,B,C,D,E,F,G,H}
           end.",
          {<<16#ab>>,<<16#cdef57:24>>, 16#abcd,16#ef57, 16#ab,16#cd,16#ef,16#57}),
    check(fun() ->
                  #{K := V} = #{k := K} = #{k => my_key, my_key => 42},
                  V
          end,
          "begin #{K := V} = #{k := K} = #{k => my_key, my_key => 42}, V end.",
          42),
    ok.

%% EEP 58: Map comprehensions.
eep58(Config) when is_list(Config) ->
    check(fun() -> X = 32, #{X => X*X || X <- [1,2,3]} end,
	  "begin X = 32, #{X => X*X || X <- [1,2,3]} end.",
	  #{1 => 1, 2 => 4, 3 => 9}),
    check(fun() ->
                  K = V = none,
                  #{K => V*V || K := V <- #{1 => 1, 2 => 2, 3 => 3}}
          end,
          "begin K = V = none, #{K => V*V || K := V <- #{1 => 1, 2 => 2, 3 => 3}} end.",
	  #{1 => 1, 2 => 4, 3 => 9}),
    check(fun() ->
                  #{K => V*V || K := V <- maps:iterator(#{1 => 1, 2 => 2, 3 => 3})}
          end,
          "#{K => V*V || K := V <- maps:iterator(#{1 => 1, 2 => 2, 3 => 3})}.",
	  #{1 => 1, 2 => 4, 3 => 9}),
    check(fun() -> << <<K:8,V:24>> || K := V <- #{42 => 7777} >> end,
          "<< <<K:8,V:24>> || K := V <- #{42 => 7777} >>.",
	  <<42:8,7777:24>>),
    check(fun() -> [X || X := X <- #{a => 1, b => b}] end,
          "[X || X := X <- #{a => 1, b => b}].",
	  [b]),
    check(fun() -> #{A => B || {A, B} <- [{1, 2}, {1, 3}]} end,
          "#{A => B || {A, B} <- [{1, 2}, {1, 3}]}.",
	  #{1 => 3}),
    check(fun() -> #{A => B || X <- [1, 5], {A, B} <- [{X, X+1}, {X, X+3}]} end,
          "#{A => B || X <- [1, 5], {A, B} <- [{X, X+1}, {X, X+3}]}.",
	  #{1 => 4,5 => 8}),
    error_check("[K+V || K := V <- a].", {bad_generator,a}),
    error_check("[K+V || K := V <- [-1|#{}]].", {bad_generator,[-1|#{}]}),

    ok.

strict_generators(Config) when is_list(Config) ->
    %% Basic scenario for each comprehension and generator type
    check(fun() -> [X+1 || X <:- [1,2,3]] end,
          "[X+1 || X <:- [1,2,3]].",
          [2,3,4]),
    check(fun() -> [X+1 || <<X>> <:= <<1,2,3>>] end,
          "[X+1 || <<X>> <:= <<1,2,3>>].",
          [2,3,4]),
    check(fun() -> [X*Y || X := Y <:- #{1 => 2, 3 => 4}] end,
          "[X*Y || X := Y <:- #{1 => 2, 3 => 4}].",
          [2,12]),
    check(fun() -> << <<(X+1)>> || X <:- [1,2,3]>> end,
          "<< <<(X+1)>> || X <:- [1,2,3]>>.",
          <<2,3,4>>),
    check(fun() -> << <<(X+1)>> || <<X>> <:= <<1,2,3>> >> end,
          "<< <<(X+1)>> || <<X>> <:= <<1,2,3>> >>.",
          <<2,3,4>>),
    check(fun() -> << <<(X*Y)>> || X := Y <:- #{1 => 2, 3 => 4} >> end,
          "<< <<(X*Y)>> || X := Y <:- #{1 => 2, 3 => 4} >>.",
          <<2,12>>),
    check(fun() -> #{X => X+1 || X <:- [1,2,3]} end,
          "#{X => X+1 || X <:- [1,2,3]}.",
          #{1 => 2, 2 => 3, 3 => 4}),
    check(fun() -> #{X => X+1 || <<X>> <:= <<1,2,3>>} end,
          "#{X => X+1 || <<X>> <:= <<1,2,3>>}.",
          #{1 => 2, 2 => 3, 3 => 4}),
    check(fun() -> #{X+1 => Y*2 || X := Y <:- #{1 => 2, 3 => 4}} end,
          "#{X+1 => Y*2 || X := Y <:- #{1 => 2, 3 => 4}}.",
          #{2 => 4, 4 => 8}),

    %% A failing guard following a strict generator is ok
    check(fun() -> [X+1 || X <:- [1,2,3], X > 1] end,
          "[X+1 || X <:- [1,2,3], X > 1].",
          [3,4]),
    check(fun() -> [X+1 || <<X>> <:= <<1,2,3>>, X > 1] end,
          "[X+1 || <<X>> <:= <<1,2,3>>, X > 1].",
          [3,4]),
    check(fun() -> [X*Y || X := Y <:- #{1 => 2, 3 => 4}, X > 1] end,
          "[X*Y || X := Y <:- #{1 => 2, 3 => 4}, X > 1].",
          [12]),
    check(fun() -> << <<(X+1)>> || X <:- [1,2,3], X > 1>> end,
          "<< <<(X+1)>> || X <:- [1,2,3], X > 1>>.",
          <<3,4>>),
    check(fun() -> << <<(X+1)>> || <<X>> <:= <<1,2,3>>, X > 1 >> end,
          "<< <<(X+1)>> || <<X>> <:= <<1,2,3>>, X > 1 >>.",
          <<3,4>>),
    check(fun() -> << <<(X*Y)>> || X := Y <:- #{1 => 2, 3 => 4}, X > 1 >> end,
          "<< <<(X*Y)>> || X := Y <:- #{1 => 2, 3 => 4}, X > 1 >>.",
          <<12>>),
    check(fun() -> #{X => X+1 || X <:- [1,2,3], X > 1} end,
          "#{X => X+1 || X <:- [1,2,3], X > 1}.",
          #{2 => 3, 3 => 4}),
    check(fun() -> #{X => X+1 || <<X>> <:= <<1,2,3>>, X > 1} end,
          "#{X => X+1 || <<X>> <:= <<1,2,3>>, X > 1}.",
          #{2 => 3, 3 => 4}),
    check(fun() -> #{X+1 => Y*2 || X := Y <:- #{1 => 2, 3 => 4}, X > 1} end,
          "#{X+1 => Y*2 || X := Y <:- #{1 => 2, 3 => 4}, X > 1}.",
          #{4 => 8}),

    %% Non-matching elements cause a badmatch error
    error_check("[X || {ok, X} <:- [{ok,1},2,{ok,3}]].",
                {badmatch,2}),
    error_check("[X || <<0:1, X:7>> <:= <<1,128,2>>].",
                {badmatch,<<128,2>>}),
    error_check("[X || X := ok <:- #{1 => ok, 2 => error, 3 => ok}].",
                {badmatch,{2,error}}),
    error_check("<< <<X>> || {ok, X} <:- [{ok,1},2,{ok,3}] >>.",
                {badmatch,2}),
    error_check("<< <<X>> || <<0:1, X:7>> <:= <<1,128,2>> >>.",
                {badmatch,<<128,2>>}),
    error_check("<< <<X>> || X := ok <:- #{1 => ok, 2 => error, 3 => ok} >>.",
                {badmatch,{2,error}}),
    error_check("#{X => X+1 || {ok, X} <:- [{ok,1},2,{ok,3}]}.",
                {badmatch,2}),
    error_check("#{X => X+1 || <<0:1, X:7>> <:= <<1,128,2>>}.",
                {badmatch,<<128,2>>}),
    error_check("#{X => X+1 || X := ok <:- #{1 => ok, 2 => error, 3 => ok}}.",
                {badmatch,{2,error}}),

    %% Binary generators don't allow unused bits at the end either
    error_check("[X || <<X:3>> <:= <<0>>].",
                {badmatch,<<0:2>>}),
    error_check("[Y || <<X, Y:X>> <:= <<8,1,9,2>>].",
                {badmatch,<<9,2>>}),
    ok.

binary_skip(Config) when is_list(Config) ->
    check(fun() -> X = 32, [X || <<X:64/float>> <= <<-1:64, 0:64, 0:64, 0:64>>] end,
	  "begin X = 32, [X || <<X:64/float>> <= <<-1:64, 0:64, 0:64, 0:64>>] end.",
	  [+0.0,+0.0,+0.0]),
    check(fun() -> X = 32, [X || <<X:64/float>> <= <<0:64, -1:64, 0:64, 0:64>>] end,
	  "begin X = 32, [X || <<X:64/float>> <= <<0:64, -1:64, 0:64, 0:64>>] end.",
	  [+0.0,+0.0,+0.0]),
    check(fun() -> [a || <<0:64/float>> <= <<0:64, 1:64, 0:64, 0:64>> ] end,
	  "begin [a || <<0:64/float>> <= <<0:64, 1:64, 0:64, 0:64>> ] end.",
	  [a,a,a]),
    ok.

%% Check the string in different contexts: as is; in fun; from compiled code.
check(F, String, Result) ->
    check1(F, String, Result),
    FunString = concat(["fun() -> ", no_final_dot(String), " end(). "]),
    check1(F, FunString, Result),
    CompileString = concat(["hd(lists:map(fun(_) -> ", no_final_dot(String),
                            " end, [foo])). "]),
    check1(F, CompileString, Result).

check1(F, String, Result) ->
    Result = F(),
    Expr = parse_expr(String),
    case catch erl_eval:expr(Expr, []) of
        {value, Result, Bs} when is_list(Bs) ->
            ok;
        Other1 ->
            ct:fail({eval, Other1, Result})
    end,
    case catch erl_eval:expr(Expr, #{}) of
        {value, Result, MapBs} when is_map(MapBs) ->
            ok;
        Other2 ->
            ct:fail({eval, Other2, Result})
    end.

check(F, String, Result, BoundVars, LFH, EFH) ->
    Result = F(),
    Exprs = parse_exprs(String),
    case catch erl_eval:exprs(Exprs, [], LFH, EFH) of
        {value, Result, Bs} ->
            %% We just assume that Bs is an orddict...
            Keys = orddict:fetch_keys(Bs),
            case sort(BoundVars) == sort(Keys) of
                true ->
                    ok;
                false ->
                    ct:fail({check, BoundVars, Keys})
            end,
            ok;
        Other1 ->
            ct:fail({check, Other1, Result})
    end,
    case catch erl_eval:exprs(Exprs, #{}, LFH, EFH) of
        {value, Result, MapBs} ->
            MapKeys = maps:keys(MapBs),
            case sort(BoundVars) == sort(MapKeys) of
                true ->
                    ok;
                false ->
                    ct:fail({check, BoundVars, MapKeys})
            end,
            ok;
        Other2 ->
            ct:fail({check, Other2, Result})
    end.

error_check(String, Result) ->
    Expr = parse_expr(String),
    case catch erl_eval:expr(Expr, []) of
        {'EXIT', {Result,_}} ->
            ok;
        Other1 ->
            ct:fail({eval, Other1, Result})
    end,
    case catch erl_eval:expr(Expr, #{}) of
        {'EXIT', {Result,_}} ->
            ok;
        Other2 ->
            ct:fail({eval, Other2, Result})
    end.

error_check(String, Result, LFH, EFH) ->
    Exprs = parse_exprs(String),
    case catch erl_eval:exprs(Exprs, [], LFH, EFH) of
        {'EXIT', {Result,_}} ->
            ok;
        Other1 ->
            ct:fail({eval, Other1, Result})
    end,
    case catch erl_eval:exprs(Exprs, #{}, LFH, EFH) of
        {'EXIT', {Result,_}} ->
            ok;
        Other2 ->
            ct:fail({eval, Other2, Result})
    end.

backtrace_check(String, Result, Backtrace) ->
    case catch parse_and_run(String) of
        {'EXIT', {Result, BT}} ->
            check_backtrace(Backtrace, remove_error_info(BT));
        Other ->
            ct:fail({eval, Other, Result})
    end.

backtrace_check(String, Result, Backtrace, LFH, EFH) ->
    case catch parse_and_run(String, LFH, EFH) of
        {'EXIT', {Result, BT}} ->
            check_backtrace(Backtrace, remove_error_info(BT));
        Other ->
            ct:fail({eval, Other, Result})
    end.

remove_error_info([{M, F, As, Info} | T]) ->
    [{M, F, As, lists:keydelete(error_info, 1, Info)} | T].

backtrace_catch(String, Result, Backtrace) ->
    case parse_and_run(String) of
        {value, {'EXIT', {Result, BT}}, _Bindings} ->
            check_backtrace(Backtrace, remove_error_info(BT));
        Other ->
            ct:fail({eval, Other, Result})
    end.

error_info_catch(String, Result) ->
    case catch parse_and_run(String) of
        {'EXIT', {Result, [{_, _, _, Info}|_]}} ->
            lists:keyfind(error_info, 1, Info);
        Other ->
            ct:fail({eval, Other, Result})
    end.

check_backtrace([B1|Backtrace], [B2|BT]) ->
    case {B1, B2} of
        {M, {M,_,_,_}} ->
            ok;
        {{M,F,A}, {M,F,A,_}} ->
            ok;
        {B, B} ->
            ok
    end,
    check_backtrace(Backtrace, BT);
check_backtrace([], _) ->
    ok.

eval_string(String) ->
    {value, Result, _} = parse_and_run(String),
    Result.

parse_expr(String) ->
    Tokens = erl_scan_string(String),
    {ok, [Expr]} = erl_parse:parse_exprs(Tokens),
    Expr.

parse_exprs(String) ->
    Tokens = erl_scan_string(String),
    {ok, Exprs} = erl_parse:parse_exprs(Tokens),
    Exprs.

erl_scan_string(String) ->
    %% FIXME: When the experimental features EEP has been implemented, we should
    %% dig out all keywords defined in all features.
    ResWordFun =
        fun('maybe') -> true;
           ('else') -> true;
           (Other) -> erl_scan:reserved_word(Other)
        end,
    {ok,Tokens,_} = erl_scan:string(String, 1, [{reserved_word_fun,ResWordFun}]),
    Tokens.

parse_and_run(String) ->
    erl_eval:expr(parse_expr(String), []).

parse_and_run(String, LFH, EFH) ->
    erl_eval:exprs(parse_exprs(String), [], LFH, EFH).

no_final_dot(S) ->
    case lists:reverse(S) of
        " ." ++ R -> lists:reverse(R);
        "." ++ R -> lists:reverse(R);
        _ -> S
    end.
