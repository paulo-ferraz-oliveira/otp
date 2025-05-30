%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 1996-2025. All Rights Reserved.
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
%%
-module(io_lib_pretty).
-moduledoc false.

%%% Pretty printing Erlang terms
%%%
%%% In this module "print" means the formatted printing while "write"
%%% means just writing out onto one line.

-export([print/1,print/2,print/3,print/4,print/5,print/6,
         print_bin/2]).

%% To be used by io_lib only.
-export([intermediate/7, write/1, write/2]).

%%%
%%% Exported functions
%%%

%% print(Term) -> [Chars]
%% print(Term, Column, LineLength, Depth) -> [Chars]
%% Depth = -1 gives unlimited print depth. Use io_lib:write for atomic terms.

-spec print(term()) -> io_lib:chars().

print(Term) ->
    print(Term, 1, 80, -1).

%% print(Term, RecDefFun) -> [Chars]
%% print(Term, Depth, RecDefFun) -> [Chars]
%% RecDefFun = fun(Tag, NoFields) -> [FieldTag] | no
%% Used by the shell for printing records and for Unicode.

-type rec_print_fun() :: fun((Tag :: atom(), NFields :: non_neg_integer()) ->
                                  'no' | [FieldName :: atom()]).
-type column() :: integer().
-type encoding() :: epp:source_encoding() | 'unicode'.
-type line_length() :: pos_integer().
-type depth() :: integer().
-type line_max_chars() :: integer().
-type chars_limit() :: integer().

-type chars() :: io_lib:chars().
-type option() :: {'chars_limit', chars_limit()}
                | {'column', column()}
                | {'depth', depth()}
                | {'encoding', encoding()}
                | {'line_length', line_length()}
                | {'line_max_chars', line_max_chars()}
                | {'record_print_fun', rec_print_fun()}
                | {'strings', boolean()}
                | {'maps_order', maps:iterator_order()}.
-type options() :: [option()].
-type options_map() :: map().

-spec print_bin(term(), options_map()) -> {unicode:unicode_binary(), Sz::integer(), Col::integer()}.
print_bin(Term, Options) when is_map(Options) ->
    Col = maps:get(column, Options, 1),
    Ll = maps:get(line_length, Options, 80),
    D = maps:get(depth, Options, -1),
    M = maps:get(line_max_chars, Options, -1),
    T = maps:get(chars_limit, Options, -1),
    RecDefFun = maps:get(record_print_fun, Options, no_fun),
    InEncoding = maps:get(encoding, Options, epp:default_encoding()),
    Strings = maps:get(strings, Options, true),
    MapsOrder = maps:get(maps_order, Options, undefined),
    print_bin(Term, Col, Ll, D, M, T, RecDefFun, {InEncoding, utf8}, Strings, MapsOrder);
print_bin(Term, Options) when is_list(Options) ->
    print_bin(Term, maps:from_list(Options)).


-spec print(term(), rec_print_fun()) -> chars();
           (term(), options()) -> chars().

print(Term, Options) when is_list(Options) ->
    Col = get_option(column, Options, 1),
    Ll = get_option(line_length, Options, 80),
    D = get_option(depth, Options, -1),
    M = get_option(line_max_chars, Options, -1),
    T = get_option(chars_limit, Options, -1),
    RecDefFun = get_option(record_print_fun, Options, no_fun),
    Encoding = get_option(encoding, Options, epp:default_encoding()),
    Strings = get_option(strings, Options, true),
    MapsOrder = get_option(maps_order, Options, undefined),
    print(Term, Col, Ll, D, M, T, RecDefFun, Encoding, Strings, MapsOrder);
print(Term, RecDefFun) ->
    print(Term, -1, RecDefFun).

-spec print(term(), depth(), rec_print_fun()) -> chars().

print(Term, Depth, RecDefFun) ->
    print(Term, 1, 80, Depth, RecDefFun).

-spec print(term(), column(), line_length(), depth()) -> chars().

print(Term, Col, Ll, D) ->
    print(Term, Col, Ll, D, _M=-1, _T=-1, no_fun, latin1, true, undefined).

-spec print(term(), column(), line_length(), depth(), rec_print_fun()) ->
                   chars().
print(Term, Col, Ll, D, RecDefFun) ->
    print(Term, Col, Ll, D, _M=-1, RecDefFun).

-spec print(term(), column(), line_length(), depth(), line_max_chars(),
            rec_print_fun()) -> chars().

print(Term, Col, Ll, D, M, RecDefFun) ->
    print(Term, Col, Ll, D, M, _T=-1, RecDefFun, latin1, true, undefined).

%% D = Depth, default -1 (infinite), or LINEMAX=30 when printing from shell
%% T = chars_limit, that is, maximal number of characters, default -1
%%   Used together with D to limit the output. It is possible that
%%   more than T characters are returned.
%% Col = current column, default 1
%% Ll = line length/~p field width, default 80
%% M = CHAR_MAX (-1 if no max, 60 when printing from shell)
print(_, _, _, 0, _M, _T, _RF, _Enc, _Str, _Ord) -> "...";
print(_, _, _, _D, _M, 0, _RF, _Enc, _Str, _Ord) -> "...";
print(Term, Col, Ll, D, M, T, RecDefFun, Enc, Str, Ord)
  when Col =< 0 ->
    %% ensure Col is at least 1
    print(Term, 1, Ll, D, M, T, RecDefFun, Enc, Str, Ord);
print(Atom, _Col, _Ll, _D, _M, _T, _RF, Enc, _Str, _Ord)
  when is_atom(Atom) ->
    write_atom(Atom, Enc);
print(Term, Col, Ll, D, M0, T, RecDefFun, Enc, Str, Ord)
  when is_tuple(Term); is_list(Term); is_map(Term); is_bitstring(Term) ->
    %% preprocess and compute total number of chars
    {_, Len, _Dots, _} = If =
        case T < 0 of
            true -> print_length(Term, D, T, RecDefFun, Enc, Str, Ord);
            false -> intermediate(Term, D, T, RecDefFun, Enc, Str, Ord)
        end,
    %% use Len as CHAR_MAX if M0 = -1
    M = max_cs(M0, Len),
    if
        Ll =:= 0 ->
            write(If, Enc);
        Len < Ll - Col, Len =< M ->
            %% write the whole thing on a single line when there is room
            write(If, Enc);
        true ->
            %% compute the indentation TInd for tagged tuples and records
            TInd = while_fail([-1, 4],
                              fun(I) -> cind(If, Col, Ll, M, I, 0, 0) end,
                              1),
            pp(If, Col, Ll, M, TInd, indent(Col), 0, 0)
    end;
print(Term, _Col, _Ll, _D, _M, _T, _RF, _Enc, _Str, _Ord) ->
    %% atomic data types (bignums, atoms, ...) are never truncated
    io_lib:write(Term).

print_bin(_, _Col, _, 0, _M, _T, _RF, _Enc, _Str, _Ord) ->
    {~"...", 3, -3};
print_bin(_, _Col, _, _D, _M, 0, _RF, _Enc, _Str, _Ord) ->
    {~"...", 3, -3};
print_bin(Term, Col, Ll, D, M, T, RecDefFun, Enc, Str, Ord)
  when Col =< 0 ->
    %% ensure Col is at least 1
    print_bin(Term, 1, Ll, D, M, T, RecDefFun, Enc, Str, Ord);
print_bin(Atom, _Col, _Ll, _D, _M, _T, _RF, {InEnc, _}, _Str, _Ord)
  when is_atom(Atom) ->
    {Bin, Sz} = io_lib:write_bin(Atom, -1, InEnc, undefined, -1),
    {Bin, Sz, -Sz};
print_bin(Term, Col, Ll, D, M0, T, RecDefFun, Enc, Str, Ord)
  when is_tuple(Term); is_list(Term); is_map(Term); is_bitstring(Term) ->
    %% preprocess and compute total number of chars
    {_, Len, _Dots, _} = If =
        case T < 0 of
            true -> print_length(Term, D, T, RecDefFun, Enc, Str, Ord);
            false -> intermediate(Term, D, T, RecDefFun, Enc, Str, Ord)
        end,
    %% use Len as CHAR_MAX if M0 = -1
    M = max_cs(M0, Len),
    if
        Ll =:= 0 ->
            {write_bin(If, <<>>), Len, -Len};
        Len < Ll - Col, Len =< M ->
            %% write the whole thing on a single line when there is room
            {write_bin(If,<<>>), Len, -Len};
        true ->
            %% compute the indentation TInd for tagged tuples and records
            TInd = while_fail([-1, 4],
                              fun(I) -> cind(If, Col, Ll, M, I, 0, 0) end,
                              1),
            {Bin, NL, W} = pp_bin(If, Col, Ll, M, TInd, indent(Col), 0, 0, 0, 0, <<>>),
            case NL > 0 of
                true ->
                    {Bin, Len+Col*NL, W-1};
                false ->
                    {Bin, Len, -W}
            end
    end;
print_bin(Term, _Col, _Ll, _D, _M, _T, _RF, _Enc, _Str, _Ord) ->
    %% atomic data types (bignums, atoms, ...) are never truncated
    {Bin, Sz} = io_lib:write_bin(Term, -1, unicode, undefined, -1),
    {Bin, Sz, -Sz}.

%%%
%%% Local functions
%%%

%% use M only if nonnegative, otherwise use Len as default value
max_cs(M, Len) when M < 0 ->
    Len;
max_cs(M, _Len) ->
    M.

-define(ATM(T), (is_list(element(1, T)) orelse is_binary(element(1, T)))).
-define(ATM_PAIR(Pair),
        ?ATM(element(2, element(1, Pair))) % Key
        andalso
        ?ATM(element(3, element(1, Pair)))). % Value
-define(ATM_FLD(Field), ?ATM(element(4, element(1, Field)))).

pp({_S,Len,_,_} = If, Col, Ll, M, _TInd, _Ind, LD, W)
                      when Len < Ll - Col - LD, Len + W + LD =< M ->
    write(If);
pp({{list,L}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, W) ->
    [$[, pp_list(L, Col + 1, Ll, M, TInd, indent(1, Ind), LD, $|, W + 1), $]];
pp({{tuple,true,L}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, W) ->
    [${, pp_tag_tuple(L, Col, Ll, M, TInd, Ind, LD, W + 1), $}];
pp({{tuple,false,L}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, W) ->
    [${, pp_list(L, Col + 1, Ll, M, TInd, indent(1, Ind), LD, $,, W + 1), $}];
pp({{map,Pairs}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, W) ->
    [$#, ${, pp_map(Pairs, Col + 2, Ll, M, TInd, indent(2, Ind), LD, W + 1),
     $}];
pp({{record,[{Name,NLen} | L]}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, W) ->
    [Name, ${, pp_record(L, NLen, Col, Ll, M, TInd, Ind, LD, W + NLen+1), $}];
pp({{bin,S}, _Len, _, _}, Col, Ll, M, _TInd, Ind, LD, W) ->
    pp_binary(S, Col + 2, Ll, M, indent(2, Ind), LD, W);
pp({S,_Len,_,_}, _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    S.

%%  Print a tagged tuple by indenting the rest of the elements
%%  differently to the tag. Tuple has size >= 2.
pp_tag_tuple({dots, _, _, _}, _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    "...";
pp_tag_tuple([{Tag,Tlen,_,_} | L], Col, Ll, M, TInd, Ind, LD, W) ->
    %% this uses TInd
    TagInd = Tlen + 2,
    Tcol = Col + TagInd,
    S = $,,
    if
        TInd > 0, TagInd > TInd ->
            Col1 = Col + TInd,
            Indent = indent(TInd, Ind),
            [Tag|pp_tail(L, Col1, Tcol, Ll, M, TInd, Indent, LD, S, W+Tlen)];
        true ->
            Indent = indent(TagInd, Ind),
            [Tag, S | pp_list(L, Tcol, Ll, M, TInd, Indent, LD, S, W+Tlen+1)]
    end.

pp_map([], _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    "";                                         % cannot happen
pp_map({dots, _, _, _}, _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    "...";                                      % cannot happen
pp_map([P | Ps], Col, Ll, M, TInd, Ind, LD, W) ->
    {PS, PW} = pp_pair(P, Col, Ll, M, TInd, Ind, last_depth(Ps, LD), W),
    [PS | pp_pairs_tail(Ps, Col, Col + PW, Ll, M, TInd, Ind, LD, PW)].

pp_pairs_tail([], _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    "";
pp_pairs_tail({dots, _, _, _}, _Col0, _Col, _M, _Ll, _TInd, _Ind, _LD, _W) ->
    ",...";
pp_pairs_tail([{_, Len, _, _}=P | Ps], Col0, Col, Ll, M, TInd, Ind, LD, W) ->
    LD1 = last_depth(Ps, LD),
    ELen = 1 + Len,
    if
        LD1 =:= 0, ELen + 1 < Ll - Col, W + ELen + 1 =< M, ?ATM_PAIR(P);
        LD1 > 0, ELen < Ll - Col - LD1, W + ELen + LD1 =< M, ?ATM_PAIR(P) ->
            [$,, write_pair(P) |
             pp_pairs_tail(Ps, Col0, Col+ELen, Ll, M, TInd, Ind, LD, W+ELen)];
        true ->
            {PS, PW} = pp_pair(P, Col0, Ll, M, TInd, Ind, LD1, 0),
            [$,, $\n, Ind, PS |
             pp_pairs_tail(Ps, Col0, Col0 + PW, Ll, M, TInd, Ind, LD, PW)]
    end.

pp_pair({_, Len, _, _}=Pair, Col, Ll, M, _TInd, _Ind, LD, W)
         when Len < Ll - Col - LD, Len + W + LD =< M ->
    {write_pair(Pair), if
                          ?ATM_PAIR(Pair) ->
                              Len;
                          true ->
                              Ll % force nl
                      end};
pp_pair({{map_pair, K, V}, _Len, _, _}, Col0, Ll, M, TInd, Ind0, LD, W) ->
    I = map_value_indent(TInd),
    Ind = indent(I, Ind0),
    {[pp(K, Col0, Ll, M, TInd, Ind0, LD, W), " =>\n",
      Ind | pp(V, Col0 + I, Ll, M, TInd, Ind, LD, 0)], Ll}. % force nl

pp_record([], _Nlen, _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    "";
pp_record({dots, _, _, _}, _Nlen, _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    "...";
pp_record([F | Fs], Nlen, Col0, Ll, M, TInd, Ind0, LD, W0) ->
    Nind = Nlen + 1,
    {Col, Ind, S, W} = rec_indent(Nind, TInd, Col0, Ind0, W0),
    {FS, FW} = pp_field(F, Col, Ll, M, TInd, Ind, last_depth(Fs, LD), W),
    [S, FS | pp_fields_tail(Fs, Col, Col + FW, Ll, M, TInd, Ind, LD, W + FW)].

pp_fields_tail([], _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, _W) ->
    "";
pp_fields_tail({dots, _, _ ,_}, _Col0, _Col, _M, _Ll, _TInd, _Ind, _LD, _W) ->
    ",...";
pp_fields_tail([{_, Len, _, _}=F | Fs], Col0, Col, Ll, M, TInd, Ind, LD, W) ->
    LD1 = last_depth(Fs, LD),
    ELen = 1 + Len,
    if
        LD1 =:= 0, ELen + 1 < Ll - Col, W + ELen + 1 =< M, ?ATM_FLD(F);
        LD1 > 0, ELen < Ll - Col - LD1, W + ELen + LD1 =< M, ?ATM_FLD(F) ->
            [$,, write_field(F) |
             pp_fields_tail(Fs, Col0, Col+ELen, Ll, M, TInd, Ind, LD, W+ELen)];
        true ->
            {FS, FW} = pp_field(F, Col0, Ll, M, TInd, Ind, LD1, 0),
            [$,, $\n, Ind, FS |
             pp_fields_tail(Fs, Col0, Col0 + FW, Ll, M, TInd, Ind, LD, FW)]
    end.

pp_field({_, Len, _, _}=Fl, Col, Ll, M, _TInd, _Ind, LD, W)
         when Len < Ll - Col - LD, Len + W + LD =< M ->
    {write_field(Fl), if
                          ?ATM_FLD(Fl) -> 
                              Len;
                          true -> 
                              Ll % force nl
                      end};
pp_field({{field, Name, NameL, F},_,_, _}, Col0, Ll, M, TInd, Ind0, LD, W0) ->
    {Col, Ind, S, W} = rec_indent(NameL, TInd, Col0, Ind0, W0 + NameL),
    Sep = case S of
              [$\n | _] -> " =";
              _ -> " = "
          end,
    {[Name, Sep, S | pp(F, Col, Ll, M, TInd, Ind, LD, W)], Ll}. % force nl

rec_indent(RInd, TInd, Col0, Ind0, W0) ->
    %% this uses TInd
    Nl = (TInd > 0) and (RInd > TInd),
    DCol = case Nl of
               true -> TInd;
               false -> RInd
           end,
    Col = Col0 + DCol,
    Ind = indent(DCol, Ind0),
    S = case Nl of
            true -> [$\n | Ind];
            false -> ""
        end,
    W = case Nl of
            true -> 0;
            false -> W0
        end,
    {Col, Ind, S, W}.

pp_list({dots, _, _, _}, _Col0, _Ll, _M, _TInd, _Ind, _LD, _S, _W) ->
    "...";
pp_list([E | Es], Col0, Ll, M, TInd, Ind, LD, S, W) ->
    {ES, WE} = pp_element(E, Col0, Ll, M, TInd, Ind, last_depth(Es, LD), W),
    [ES | pp_tail(Es, Col0, Col0 + WE, Ll, M, TInd, Ind, LD, S, W + WE)].

pp_tail([], _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, _S, _W) ->
    [];
pp_tail([{_, Len, _, _}=E | Es], Col0, Col, Ll, M, TInd, Ind, LD, S, W) ->
    LD1 = last_depth(Es, LD),
    ELen = 1 + Len,
    if 
        LD1 =:= 0, ELen + 1 < Ll - Col, W + ELen + 1 =< M, ?ATM(E);
        LD1 > 0, ELen < Ll - Col - LD1, W + ELen + LD1 =< M, ?ATM(E) ->
            [$,, write(E) | 
             pp_tail(Es, Col0, Col + ELen, Ll, M, TInd, Ind, LD, S, W+ELen)];
        true ->
            {ES, WE} = pp_element(E, Col0, Ll, M, TInd, Ind, LD1, 0),
            [$,, $\n, Ind, ES | 
             pp_tail(Es, Col0, Col0 + WE, Ll, M, TInd, Ind, LD, S, WE)]
    end;
pp_tail({dots, _, _, _}, _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, S, _W) ->
    [S | "..."];
pp_tail({_, Len, _, _}=E, _Col0, Col, Ll, M, _TInd, _Ind, LD, S, W)
  when Len + 1 < Ll - Col - (LD + 1),
       Len + 1 + W + (LD + 1) =< M,
       ?ATM(E) ->
    [S | write(E)];
pp_tail(E, Col0, _Col, Ll, M, TInd, Ind, LD, S, _W) ->
    [S, $\n, Ind | pp(E, Col0, Ll, M, TInd, Ind, LD + 1, 0)].

pp_element({_, Len, _, _}=E, Col, Ll, M, _TInd, _Ind, LD, W)
           when Len < Ll - Col - LD, Len + W + LD =< M, ?ATM(E) ->
    {write(E), Len};
pp_element(E, Col, Ll, M, TInd, Ind, LD, W) ->
    {pp(E, Col, Ll, M, TInd, Ind, LD, W), Ll}. % force nl

%% Reuse the list created by io_lib:write_binary()...
pp_binary([LT,LT,S,GT,GT], Col, Ll, M, Ind, LD, W) ->
    N = erlang:max(8, erlang:min(Ll - Col, M - 4 - W) - LD),
    [LT,LT,pp_binary(S, N, N, Ind),GT,GT].

pp_binary([BS, $, | S], N, N0, Ind) ->
    Len = length(BS) + 1,
    case N - Len of
        N1 when N1 < 0 ->
            [$\n, Ind, BS, $, | pp_binary(S, N0 - Len, N0, Ind)];
        N1 ->
            [BS, $, | pp_binary(S, N1, N0, Ind)]
    end;
pp_binary([BS1, $:, BS2]=S, N, _N0, Ind) 
         when length(BS1) + length(BS2) + 1 > N ->
    [$\n, Ind, S];
pp_binary(S, N, _N0, Ind) ->
    case iolist_size(S) > N of
        true ->
            [$\n, Ind, S];
        false ->
            S
    end.


-define(IND(Spaces), (list_to_binary(Spaces))/binary).

pp_bin({_S,Len,_,_} = If, Col, Ll, M, _TInd, _Ind, LD, NL, W, Pos, Acc)
  when Len < Ll - Col - LD, Len + W + LD =< M ->
    {write_bin(If, Acc), NL, Pos+Len};
pp_bin({{list,L}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, NL, W, Pos, Acc) ->
    pp_list_bin(L, Col+1, Ll, M, TInd, indent(1, Ind), LD, $|, $], NL, W+1, Pos+1,
                <<Acc/binary, $[>>);
pp_bin({{tuple,true,L}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, NL, W, Pos, Acc) ->
    pp_tag_tuple_bin(L, Col, Ll, M, TInd, Ind, LD, NL, W+1, Pos+1,
                     <<Acc/binary, ${>>);
pp_bin({{tuple,false,L}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, NL, W, Pos, Acc) ->
    pp_list_bin(L, Col+1, Ll, M, TInd, indent(1, Ind), LD, $,, $}, NL, W+1, Pos+1,
                <<Acc/binary, ${>>);
pp_bin({{map,Pairs}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, NL, W, Pos, Acc) ->
    pp_map_bin(Pairs, Col+2, Ll, M, TInd, indent(2, Ind), LD, NL, W+2, Pos,
               <<Acc/binary, $#, ${>>);
pp_bin({{record,[{Name0,NLen} | L]}, _Len, _, _}, Col, Ll, M, TInd, Ind, LD, NL, W, Pos, Acc) ->
    Name = unicode:characters_to_binary(Name0),
    pp_record_bin(L, NLen, Col, Ll, M, TInd, Ind, LD, NL, W+NLen+1, Pos+NLen+1,
                  <<Acc/binary, Name/binary, ${>>);
pp_bin({{bin,S}, _Len, _, _}, Col, Ll, M, _TInd, Ind, LD, NL, W, Pos, Acc) ->
    pp_binary_bin(S, Col+2, Ll, M, indent(2, Ind), LD, NL, W, Pos, Acc);
pp_bin({S,Len,_,_}, _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    Bin = unicode:characters_to_binary(S),
    {<<Acc/binary, Bin/binary>>, NL, Pos+Len}.

%%  Print a tagged tuple by indenting the rest of the elements
%%  differently to the tag. Tuple has size >= 2.
pp_tag_tuple_bin({dots, _, _, _}, _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, "...}">>, NL, Pos+4};
pp_tag_tuple_bin([{Tag0,Tlen,_,_} | L], Col, Ll, M, TInd, Ind, LD, NL, W, Pos, Acc) ->
    %% this uses TInd
    TagInd = Tlen+2,
    Tcol = Col+TagInd,
    Tag = unicode:characters_to_binary(Tag0),
    S = $,,
    if
        TInd > 0, TagInd > TInd ->
            Col1 = Col+TInd,
            Indent = indent(TInd, Ind),
            pp_tail_bin(L, Col1, Tcol, Ll, M, TInd, Indent, LD, S, $}, NL, W+Tlen, Pos+Tlen,
                        <<Acc/binary, Tag/binary>>);
        true ->
            Indent = indent(TagInd, Ind),
            pp_list_bin(L, Tcol, Ll, M, TInd, Indent, LD, S, $}, NL, W+Tlen+1, Pos+Tlen+1,
                        <<Acc/binary, Tag/binary, S>>)
    end.

pp_map_bin([], _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, $}>>, NL, Pos+1};                           % cannot happen
pp_map_bin({dots, _, _, _}, _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, "...}">>, NL, Pos+4};                       % cannot happen
pp_map_bin([P | Ps], Col, Ll, M, TInd, Ind, LD, NL0, W, Pos0, Acc) ->
    {PS, NL, Pos, PW} = pp_pair_bin(P, Col, Ll, M, TInd, Ind, last_depth(Ps, LD), NL0, W, Pos0, Acc),
    pp_pairs_tail_bin(Ps, Col, Col+PW, Ll, M, TInd, Ind, LD, NL, PW, Pos, PS).

pp_pairs_tail_bin([], _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, $}>>, NL, Pos+1};
pp_pairs_tail_bin({dots, _, _, _}, _Col0, _Col, _M, _Ll, _TInd, _Ind, _L, NL, _W, Pos, Acc) ->
    {<<Acc/binary, ",...}">>, NL, Pos+5};
pp_pairs_tail_bin([{_, Len, _, _}=P | Ps], Col0, Col, Ll, M, TInd, Ind, LD, NL0, W, Pos, Acc) ->
    LD1 = last_depth(Ps, LD),
    ELen = 1+Len,
    if
        LD1 =:= 0, ELen+1 < Ll-Col, W+ELen+1 =< M, ?ATM_PAIR(P);
        LD1 > 0, ELen < Ll-Col-LD1, W+ELen+LD1 =< M, ?ATM_PAIR(P) ->
            pp_pairs_tail_bin(Ps, Col0, Col+ELen, Ll, M, TInd, Ind, LD, NL0, W+ELen, Pos+ELen,
                              write_bin(P, <<Acc/binary, $,>>));
        true ->
            {PS, NL, Pos1, PW} = pp_pair_bin(P, Col0, Ll, M, TInd, Ind, LD1, NL0+1, 0, Col0,
                                             <<Acc/binary, $,, $\n, ?IND(Ind)>>),
            pp_pairs_tail_bin(Ps, Col0, Col0+PW, Ll, M, TInd, Ind, LD, NL, PW, Pos1, PS)
    end.

pp_pair_bin({_, Len, _, _}=Pair, Col, Ll, M, _TInd, _Ind, LD, NL, W, Pos, Acc)
  when Len < Ll - Col - LD, Len+W+LD =< M ->
    {write_bin(Pair, Acc),
     NL,
     Len+Pos,
     if
         ?ATM_PAIR(Pair) ->
             Len;
         true ->
             Ll % force nl
     end};
pp_pair_bin({{map_pair, K, V}, _Len, _, _}, Col0, Ll, M, TInd, Ind0, LD, NL0, W, Pos0, Acc0) ->
    I = map_value_indent(TInd),
    Ind = indent(I, Ind0),
    {Acc1, NL1, _} = pp_bin(K, Col0, Ll, M, TInd, Ind0, LD, NL0, W, Pos0, Acc0),
    {Acc2, NL, Pos} = pp_bin(V, Col0+I, Ll, M, TInd, Ind, LD, NL1+1, 0, Col0+I,
                             <<Acc1/binary, " =>\n", ?IND(Ind)>>),
    {Acc2, NL, Pos, Ll}.

pp_record_bin([], _Nlen, _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, $}>>, NL, Pos+1};
pp_record_bin({dots, _, _, _}, _Nlen, _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, "...}">>, NL, Pos+4};
pp_record_bin([F | Fs], Nlen, Col0, Ll, M, TInd, Ind0, LD, NL0, W0, Pos0, Acc) ->
    Nind = Nlen+1,
    {Col, Ind, S, W} = rec_indent(Nind, TInd, Col0, Ind0, W0),
    {Pos1, NL1} = if W == 0 -> {Col, NL0+1}; true -> {Pos0, NL0} end,
    {FS, NL, Pos, FW} = pp_field_bin(F, Col, Ll, M, TInd, Ind, last_depth(Fs, LD), NL1, W, Pos1,
                                     <<Acc/binary, ?IND(S)>>),
    pp_fields_tail_bin(Fs, Col, Col+FW, Ll, M, TInd, Ind, LD, NL, W+FW, Pos, FS).

pp_fields_tail_bin([], _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, $}>>, NL, Pos+1};
pp_fields_tail_bin({dots, _, _ ,_}, _Col0, _Col, _M, _Ll, _TInd, _Ind, _LD, NL, _W, Pos, Acc) ->
    {<<Acc/binary, ",...}">>, NL, Pos+5};
pp_fields_tail_bin([{_, Len, _, _}=F | Fs], Col0, Col, Ll, M, TInd, Ind, LD, NL0, W, Pos0, Acc) ->
    LD1 = last_depth(Fs, LD),
    ELen = 1+Len,
    if
        LD1 =:= 0, ELen+1 < Ll-Col, W+ELen+1 =< M, ?ATM_FLD(F);
        LD1 > 0, ELen < Ll-Col-LD1, W+ELen+LD1 =< M, ?ATM_FLD(F) ->
            pp_fields_tail_bin(Fs, Col0, Col+ELen, Ll, M, TInd, Ind, LD, NL0, W+ELen, Pos0+ELen,
                               write_field_bin(F, <<Acc/binary, $,>>));
        true ->
            {FS, NL, Pos, FW} = pp_field_bin(F, Col0, Ll, M, TInd, Ind, LD1, NL0+1, 0, Col0,
                                             <<Acc/binary, $,, $\n, ?IND(Ind)>>),
            pp_fields_tail_bin(Fs, Col0, Col0+FW, Ll, M, TInd, Ind, LD, NL, FW, Pos, FS)
    end.

pp_field_bin({_, Len, _, _}=Fl, Col, Ll, M, _TInd, _Ind, LD, NL, W, Pos, Acc)
  when Len < Ll-Col-LD, Len+W+LD =< M ->
    {write_field_bin(Fl, Acc),
     NL,
     Len+Pos,
     if
         ?ATM_FLD(Fl) -> Len;
         true -> Ll % force nl
     end};
pp_field_bin({{field, Name0, NameL, F},_,_, _}, Col0, Ll, M, TInd, Ind0, LD, NL0, W0, Pos0, Acc0) ->
    {Col, Ind, S, W} = rec_indent(NameL, TInd, Col0, Ind0, W0+NameL),
    Name = unicode:characters_to_binary(Name0),
    {Acc, NL, Pos} =
        case W of
            0 ->
                Acc1 = <<Acc0/binary, Name/binary, " =", ?IND(S)>>,
                pp_bin(F, Col, Ll, M, TInd, Ind, LD, NL0+1, W, Col, Acc1);
            _ ->
                Acc1 = <<Acc0/binary, Name/binary, " = ", ?IND(S)>>,
                pp_bin(F, Col, Ll, M, TInd, Ind, LD, NL0, W, Pos0, Acc1)
        end,
    {Acc, NL, Pos, Ll}. % force nl

pp_list_bin({dots, _, _, _}, _Col0, _Ll, _M, _TInd, _Ind, _LD, _S, C, NL, _W, Pos, Acc) ->
    {<<Acc/binary, "...", C>>, NL, Pos+4};
pp_list_bin([E | Es], Col0, Ll, M, TInd, Ind, LD, S, C, NL0, W, Pos0, Acc) ->
    {ES, NL, Pos, WE} = pp_element_bin(E, Col0, Ll, M, TInd, Ind, last_depth(Es, LD), NL0, W, Pos0, Acc),
    pp_tail_bin(Es, Col0, Col0+WE, Ll, M, TInd, Ind, LD, S, C, NL, W+WE, Pos, ES).

pp_tail_bin([], _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, _S, C, NL, _W, Pos, Acc) ->
    {<<Acc/binary, C>>, NL, Pos+1};
pp_tail_bin([{_, Len, _, _}=E | Es], Col0, Col, Ll, M, TInd, Ind, LD, S, C, NL0, W, Pos0, Acc) ->
    LD1 = last_depth(Es, LD),
    ELen = 1+Len,
    if
        LD1 =:= 0, ELen+1 < Ll-Col, W+ELen+1 =< M, ?ATM(E);
        LD1 > 0, ELen < Ll-Col-LD1, W+ELen+LD1 =< M, ?ATM(E) ->
            pp_tail_bin(Es, Col0, Col+ELen, Ll, M, TInd, Ind, LD, S, C, NL0, W+ELen, Pos0+ELen,
                        write_bin(E, <<Acc/binary, $,>>));
        true ->
            {ES, NL, Pos, WE} = pp_element_bin(E, Col0, Ll, M, TInd, Ind, LD1, NL0+1, 0, Col0,
                                               <<Acc/binary, $,, $\n, ?IND(Ind)>>),
            pp_tail_bin(Es, Col0, Col0+WE, Ll, M, TInd, Ind, LD, S, C, NL, WE, Pos, ES)
    end;
pp_tail_bin({dots, _, _, _}, _Col0, _Col, _Ll, _M, _TInd, _Ind, _LD, S, C, NL, _W, Pos, Acc) ->
    {<<Acc/binary, S, "...", C>>, NL, Pos+5};
pp_tail_bin({_, Len, _, _}=E, _Col0, Col, Ll, M, _TInd, _Ind, LD, S, C, NL, W, Pos, Acc)
  when Len+1 < Ll - Col - (LD+1),
       Len+1+W+(LD+1) =< M,
       ?ATM(E) ->
    Acc1 = write_bin(E, <<Acc/binary, S>>),
    {<<Acc1/binary, C>>, NL, Pos+1+Len};
pp_tail_bin(E, Col0, _Col, Ll, M, TInd, Ind, LD, S, C, NL0, _W, _Pos0, Acc) ->
    {Acc1, NL, Pos} = pp_bin(E, Col0, Ll, M, TInd, Ind, LD+1, NL0+1, 0, Col0,
                             <<Acc/binary, S, $\n, ?IND(Ind)>>),
    {<<Acc1/binary, C>>, NL, Pos+1}.

pp_element_bin({_, Len, _, _}=E, Col, Ll, M, _TInd, _Ind, LD, NL, W, Pos, Acc)
  when Len < Ll - Col - LD, Len+W+LD =< M, ?ATM(E) ->
    {write_bin(E, Acc), NL, Pos+Len, Len};
pp_element_bin(E, Col, Ll, M, TInd, Ind, LD, NL0, W, Pos0, Acc) ->
    {Acc1, NL, Pos} = pp_bin(E, Col, Ll, M, TInd, Ind, LD, NL0, W, Pos0, Acc),
    {Acc1, NL, Pos, Ll}. % force nl

pp_binary_bin(Orig, Col, Ll, M, Ind, LD, NL, W, Pos, Acc) ->
    N = erlang:max(8, erlang:min(Ll - Col, M - 4 - W) - LD),
    <<$<,$<,Rest/binary>> = Orig,
    pp_binary_bin_ind(Rest, Orig, Ind, 0, 2, N, N, NL, Pos, Acc).

pp_binary_bin_ind(<<_,$,, Rest/binary>>, Orig, Ind, S, I, N, N0, NL, Pos, Acc) ->
    N1 = N-2,
    case N1 < 0 of
        false ->
            pp_binary_bin_ind(Rest, Orig, Ind, S, I+2, N1, N0, NL, Pos, Acc);
        true ->
            Part = binary:part(Orig, S, I),
            pp_binary_bin_ind(Rest, Orig, Ind, S+I, 2, N0-2, N0, NL+1, 0,
                              <<Acc/binary, Part/binary, $\n, ?IND(Ind)>>)
    end;
pp_binary_bin_ind(<<_,_,$,, Rest/binary>>, Orig, Ind, S, I, N, N0, NL, Pos, Acc) ->
    N1 = N-3,
    case N1 < 0 of
        false ->
            pp_binary_bin_ind(Rest, Orig, Ind, S, I+3, N1, N0, NL, Pos, Acc);
        true ->
            Part = binary:part(Orig, S, I),
            pp_binary_bin_ind(Rest, Orig, Ind, S+I, 3, N0-3, N0, NL+1, Pos,
                              <<Acc/binary, Part/binary, $\n, ?IND(Ind)>>)
    end;
pp_binary_bin_ind(<<_,_,_,$,, Rest/binary>>, Orig, Ind, S, I, N, N0, NL, Pos, Acc) ->
    N1 = N-4,
    case N1 < 0 of
        false ->
            pp_binary_bin_ind(Rest, Orig, Ind, S, I+4, N1, N0, NL, Pos, Acc);
        true ->
            Part = binary:part(Orig, S, I),
            pp_binary_bin_ind(Rest, Orig, Ind, S+I, 4, N0-4, N0, NL+1, Pos,
                              <<Acc/binary, Part/binary, $\n, ?IND(Ind)>>)
    end;
pp_binary_bin_ind(Bin, Orig, Ind, S, I, N, _, NL, Pos0, Acc) ->
    Col = iolist_size(Ind)+1,
    Pos = if Pos0 =:= 0 -> Col; true -> Pos0 end,
    case (byte_size(Bin)-2) > N of  %% Don't count bin closing ">>"
        false when S =:= 0 ->
            Sz = byte_size(Orig),
            {<<Acc/binary, Orig/binary>>, NL, Pos+Sz};
        false ->
            Sz = byte_size(Orig)-S,
            Part = binary:part(Orig, S, Sz),
            {<<Acc/binary, Part/binary>>, NL, Pos+Sz};
        true ->
            Part1 = binary:part(Orig, S, I),
            Sz = byte_size(Orig) - (S+I),
            Part2 = binary:part(Orig, S+I, Sz),
            {<<Acc/binary, Part1/binary, $\n, ?IND(Ind), Part2/binary>>,
             NL+1, Col+Sz}
    end.

%% write the whole thing on a single line

write(If, {_, utf8}) ->
    write_bin(If, <<>>);
write(If, _) ->
    write(If).

write({{tuple, _IsTagged, L}, _, _, _}) ->
    [${, write_list(L, $,), $}];
write({{list, L}, _, _, _}) ->
    [$[, write_list(L, $|), $]];
write({{map, Pairs}, _, _, _}) ->
    [$#,${, write_list(Pairs, $,), $}];
write({{map_pair, _K, _V}, _, _, _}=Pair) ->
    write_pair(Pair);
write({{record, [{Name,_} | L]}, _, _, _}) ->
    [Name, ${, write_fields(L), $}];
write({{bin, S}, _, _, _}) ->
    S;
write({S, _, _, _}) ->
    S.

write_pair({{map_pair, K, V}, _, _, _}) ->
    [write(K), " => ", write(V)].

write_fields([]) ->
    "";
write_fields({dots, _, _, _}) ->
    "...";
write_fields([F | Fs]) ->
    [write_field(F) | write_fields_tail(Fs)].

write_fields_tail([]) ->
    "";
write_fields_tail({dots, _, _, _}) ->
    ",...";
write_fields_tail([F | Fs]) ->
    [$,, write_field(F) | write_fields_tail(Fs)].

write_field({{field, Name, _NameL, F}, _, _, _}) ->
    [Name, " = " | write(F)].

write_list({dots, _, _, _}, _S) ->
    "...";
write_list([E | Es], S) ->
    [write(E) | write_tail(Es, S)].

write_tail([], _S) ->
    [];
write_tail([E | Es], S) ->
    [$,, write(E) | write_tail(Es, S)];
write_tail({dots, _, _, _}, S) ->
    [S | "..."];
write_tail(E, S) ->
    [S | write(E)].


%% write the whole thing on a single line
write_bin({{tuple, _IsTagged, L}, _, _, _}, Acc) ->
    write_list_bin(L, $,, $}, <<Acc/binary, ${>>);
write_bin({{list, L}, _, _, _}, Acc) ->
    write_list_bin(L, $|, $], <<Acc/binary, $[>>);
write_bin({{map, Pairs}, _, _, _}, Acc) ->
    write_list_bin(Pairs, $,, $}, <<Acc/binary, "#{">>);
write_bin({{map_pair, K, V}, _, _, _}, Acc0) ->
    Acc = write_bin(K, Acc0),
    write_bin(V, <<Acc/binary, " => ">>);
write_bin({{record, [{Name0,_} | L]}, _, _, _}, Acc) ->
    Name = unicode:characters_to_binary(Name0),
    write_fields_bin(L, <<Acc/binary, Name/binary, ${>>);
write_bin({{bin, S}, _, _, _}, Acc) ->
    <<Acc/binary, S/binary>>;
write_bin({S, _, _, _}, Acc) when is_binary(S) ->
    <<Acc/binary, S/binary>>;
write_bin({S, _, _, _}, Acc) ->
    Bin = unicode:characters_to_binary(S),
    <<Acc/binary, Bin/binary>>.

write_fields_bin([], Acc) ->
    <<Acc/binary, $}>>;
write_fields_bin({dots, _, _, _}, Acc) ->
    <<Acc/binary, "...}">>;
write_fields_bin([F | Fs], Acc) ->
    write_fields_tail_bin(Fs, write_field_bin(F, Acc)).

write_fields_tail_bin([], Acc) ->
    <<Acc/binary, $}>>;
write_fields_tail_bin({dots, _, _, _}, Acc) ->
    <<Acc/binary, ",...}">>;
write_fields_tail_bin([F | Fs], Acc) ->
    write_fields_tail_bin(Fs, write_field_bin(F, <<Acc/binary, $,>>)).

write_field_bin({{field, Name, _NameL, F}, _, _, _}, Acc) ->
    Bin = unicode:characters_to_binary(Name),
    true = is_binary(Bin),
    write_bin(F, <<Acc/binary, Bin/binary, " = ">>).

write_list_bin({dots, _, _, _}, _S, End, Acc) ->
    <<Acc/binary, "...", End>>;
write_list_bin([E | Es], S, End, Acc) ->
    write_tail_bin(Es, S, End, write_bin(E, Acc)).

write_tail_bin([], _S, End, Acc) ->
    <<Acc/binary, End>>;
write_tail_bin([E | Es], S, End, Acc) ->
    write_tail_bin(Es, S, End, write_bin(E, <<Acc/binary, $,>>));
write_tail_bin({dots, _, _, _}, S, End, Acc) ->
    <<Acc/binary, S, "...", End>>;
write_tail_bin(E, S, End, Acc) ->
    Bin = write_bin(E, <<Acc/binary, S>>),
    <<Bin/binary, End>>.

-type more() :: fun((chars_limit(), DeltaDepth :: non_neg_integer()) ->
                            intermediate_format()).

-type if_list() :: maybe_improper_list(intermediate_format(),
                                       {'dots', non_neg_integer(),
                                        non_neg_integer(), more()}).

-type intermediate_format() ::
        {chars()
         | {'bin', chars()}
         | 'dots'
         | {'field', Name :: chars(), NameLen :: non_neg_integer(),
                     intermediate_format()}
         | {'list', if_list()}
         | {'map', if_list()}
         | {'map_pair', K :: intermediate_format(),
                        V :: intermediate_format()}
         | {'record', [{Name :: chars(), NameLen :: non_neg_integer()}
                       | if_list()]}
         | {'tuple', IsTagged :: boolean(), if_list()},
         Len :: non_neg_integer(),
         NumOfDots :: non_neg_integer(),
         More :: more() | 'no_more'
        }.

-spec intermediate(term(), depth(), pos_integer(), rec_print_fun(),
                   encoding() | {encoding, utf8},
                   boolean(), maps:iterator_order() | undefined) ->
          intermediate_format().

intermediate(Term, D, T, RF, Enc, Str, Ord) when T > 0 ->
    D0 = 1,
    If = print_length(Term, D0, T, RF, Enc, Str, Ord),
    case If of
        {_, Len, Dots, _} when Dots =:= 0; Len > T; D =:= 1 ->
            If;
        {_, Len, _, _} ->
            find_upper(If, Term, T, D0, 2, D, RF, Enc, Str, Ord, Len)
    end.

find_upper(Lower, Term, T, Dl, Dd, D, RF, Enc, Str, Ord, LastLen) ->
    Dd2 = Dd * 2,
    D1 = case D < 0 of
             true -> Dl+Dd2;
             false -> min(Dl+Dd2, D)
         end,
    If = expand(Lower, T, D1 - Dl),
    case If of
        {_, _, _Dots=0, _} -> % even if Len > T
            If;
        {_, LastLen, _, _} ->
            %% Cannot happen if print_length() is free of bugs.
            If;
        {_, Len, _, _} when Len =< T, D1 < D orelse D < 0 ->
	    find_upper(If, Term, T, D1, Dd2, D, RF, Enc, Str, Ord, Len);
        _ ->
	    search_depth(Lower, If, Term, T, Dl, D1, RF, Enc, Str, Ord)
    end.

%% Lower has NumOfDots > 0 and Len =< T.
%% Upper has NumOfDots > 0 and Len > T.
search_depth(Lower, Upper, _Term, T, Dl, Du, _RF, _Enc, _Str, _Ord)
        when Du - Dl =:= 1 ->
    %% The returned intermediate format has Len >= T.
    case Lower of
        {_, T, _, _} ->
            Lower;
        _ ->
            Upper
    end;
search_depth(Lower, Upper, Term, T, Dl, Du, RF, Enc, Str, Ord) ->
    D1 = (Dl +Du) div 2,
    If = expand(Lower, T, D1 - Dl),
    case If of
	{_, Len, _, _} when Len > T ->
            %% Len can be greater than Upper's length.
            %% This is a bit expensive since the work to
            %% crate Upper is wasted. It is the price
            %% to pay to get a more balanced output.
            search_depth(Lower, If, Term, T, Dl, D1, RF, Enc, Str, Ord);
        _ ->
            search_depth(If, Upper, Term, T, D1, Du, RF, Enc, Str, Ord)
    end.

%% The depth (D) is used for extracting and counting the characters to
%% print. The structure is kept so that the returned intermediate
%% format can be formatted. The separators (list, tuple, record, map) are
%% counted but need to be added later.

%% D =/= 0
print_length([], _D, _T, _RF, _Enc, _Str, _Ord) ->
    {"[]", 2, 0, no_more};
print_length({}, _D, _T, _RF, _Enc, _Str, _Ord) ->
    {"{}", 2, 0, no_more};
print_length(#{}=M, _D, _T, _RF, _Enc, _Str, _Ord) when map_size(M) =:= 0 ->
    {"#{}", 3, 0, no_more};
print_length(Atom, _D, _T, _RF, Enc, _Str, _Ord) when is_atom(Atom) ->
    S = write_atom(Atom, Enc),
    {S, io_lib:chars_length(S), 0, no_more};
print_length(List, D, T, RF, Enc, Str, Ord) when is_list(List) ->
    %% only flat lists are "printable"
    case Str andalso printable_list(List, D, T, Enc) of
        true ->
            %% print as string, escaping double-quotes in the list
            {S, Len} = write_string(List, Enc),
            {S, Len, 0, no_more};
        {true, Prefix} ->
            %% Truncated lists when T < 0 could break some existing code.
            {S, Len} = write_string(Prefix, Enc),
            %% NumOfDots = 0 to avoid looping--increasing the depth
            %% does not make Prefix longer.
            {[S | "..."], 3 + Len, 0, no_more};
        false ->
            case print_length_list(List, D, T, RF, Enc, Str, Ord) of
                {What, Len, Dots, _More} when Dots > 0 ->
                    More = fun(T1, Dd) ->
                                   ?FUNCTION_NAME(List, D+Dd, T1, RF, Enc, Str, Ord)
                           end,
                    {What, Len, Dots, More};
                If ->
                    If
            end
    end;
print_length(Fun, _D, _T, _RF, _Enc, _Str, _Ord) when is_function(Fun) ->
    S = io_lib:write(Fun),
    {S, iolist_size(S), 0, no_more};
print_length(R, D, T, RF, Enc, Str, Ord) when is_atom(element(1, R)),
                                              is_function(RF) ->
    case RF(element(1, R), tuple_size(R) - 1) of
        no -> 
            print_length_tuple(R, D, T, RF, Enc, Str, Ord);
        RDefs ->
            print_length_record(R, D, T, RF, RDefs, Enc, Str, Ord)
    end;
print_length(Tuple, D, T, RF, Enc, Str, Ord) when is_tuple(Tuple) ->
    print_length_tuple(Tuple, D, T, RF, Enc, Str, Ord);
print_length(Map, D, T, RF, Enc, Str, Ord) when is_map(Map) ->
    print_length_map(Map, D, T, RF, Enc, Str, Ord);
print_length(<<>>, _D, _T, _RF, _Enc, _Str, _Ord) ->
    {"<<>>", 4, 0, no_more};
print_length(<<_/bitstring>> = Bin, 1, _T, RF, Enc, Str, Ord) ->
    More = fun(T1, Dd) -> ?FUNCTION_NAME(Bin, 1+Dd, T1, RF, Enc, Str, Ord) end,
    {"<<...>>", 7, 3, More};
print_length(<<_/bitstring>> = Bin, D, T, RF, Enc, Str, Ord) ->
    print_length_binary(Bin, D, T, RF, Enc, Str, Ord);
print_length(Term, _D, _T, _RF, _Enc, _Str, _Ord) ->
    S = io_lib:write(Term),
    %% S can contain unicode, so iolist_size(S) cannot be used here
    {S, io_lib:chars_length(S), 0, no_more}.

print_length_map(Map, 1, _T, RF, Enc, Str, Ord) ->
    More = fun(T1, Dd) -> ?FUNCTION_NAME(Map, 1+Dd, T1, RF, Enc, Str, Ord) end,
    {"#{...}", 6, 3, More};
print_length_map(Map, D, T, RF, Enc, Str, Ord) when is_map(Map) ->
    Next = maps:next(maps:iterator(Map, Ord)),
    PairsS = print_length_map_pairs(Next, D, D - 1, tsub(T, 3), RF, Enc, Str, Ord),
    {Len, Dots} = list_length(PairsS, 3, 0),
    {{map, PairsS}, Len, Dots, no_more}.

print_length_map_pairs(none, _D, _D0, _T, _RF, _Enc, _Str, _Ord) ->
    [];
print_length_map_pairs(Term, D, D0, T, RF, Enc, Str, Ord) when D =:= 1; T =:= 0->
    More = fun(T1, Dd) ->
                   ?FUNCTION_NAME(Term, D+Dd, D0, T1, RF, Enc, Str, Ord)
           end,
    {dots, 3, 3, More};
print_length_map_pairs({K, V, Iter}, D, D0, T, RF, Enc, Str, Ord) ->
    Next = maps:next(Iter),
    T1 = case Next =:= none of
             false -> tsub(T, 1);
             true -> T
         end,
    Pair1 = print_length_map_pair(K, V, D0, T1, RF, Enc, Str, Ord),
    {_, Len1, _, _} = Pair1,
    [Pair1 |
     print_length_map_pairs(Next, D - 1, D0, tsub(T1, Len1), RF, Enc, Str, Ord)].

print_length_map_pair(K, V, D, T, RF, Enc, Str, Ord) ->
    {_, KL, KD, _} = P1 = print_length(K, D, T, RF, Enc, Str, Ord),
    KL1 = KL + 4,
    {_, VL, VD, _} = P2 = print_length(V, D, tsub(T, KL1), RF, Enc, Str, Ord),
    {{map_pair, P1, P2}, KL1 + VL, KD + VD, no_more}.

print_length_tuple(Tuple, 1, _T, RF, Enc, Str, Ord) ->
    More = fun(T1, Dd) -> ?FUNCTION_NAME(Tuple, 1+Dd, T1, RF, Enc, Str, Ord) end,
    {"{...}", 5, 3, More};
print_length_tuple(Tuple, D, T, RF, Enc, Str, Ord) ->
    L = print_length_tuple1(Tuple, 1, D, tsub(T, 2), RF, Enc, Str, Ord),
    IsTagged = is_atom(element(1, Tuple)) and (tuple_size(Tuple) > 1),
    {Len, Dots} = list_length(L, 2, 0),
    {{tuple,IsTagged,L}, Len, Dots, no_more}.

print_length_tuple1(Tuple, I, _D, _T, _RF, _Enc, _Str, _Ord)
             when I > tuple_size(Tuple) ->
    [];
print_length_tuple1(Tuple, I, D, T, RF, Enc, Str, Ord) when D =:= 1; T =:= 0->
    More = fun(T1, Dd) -> ?FUNCTION_NAME(Tuple, I, D+Dd, T1, RF, Enc, Str, Ord) end,
    {dots, 3, 3, More};
print_length_tuple1(Tuple, I, D, T, RF, Enc, Str, Ord) ->
    E = element(I, Tuple),
    T1 = case I =:= tuple_size(Tuple) of
             false -> tsub(T, 1);
             true -> T
         end,
    {_, Len1, _, _} = Elem1 = print_length(E, D - 1, T1, RF, Enc, Str, Ord),
    T2 = tsub(T1, Len1),
    [Elem1 | print_length_tuple1(Tuple, I + 1, D - 1, T2, RF, Enc, Str, Ord)].

print_length_record(Tuple, 1, _T, RF, RDefs, Enc, Str, Ord) ->
    More = fun(T1, Dd) ->
                   ?FUNCTION_NAME(Tuple, 1+Dd, T1, RF, RDefs, Enc, Str, Ord)
           end,
    {"{...}", 5, 3, More};
print_length_record(Tuple, D, T, RF, RDefs, Enc, Str, Ord) ->
    Name = [$# | write_atom(element(1, Tuple), Enc)],
    NameL = io_lib:chars_length(Name),
    T1 = tsub(T, NameL+2),
    L = print_length_fields(RDefs, D - 1, T1, Tuple, 2, RF, Enc, Str, Ord),
    {Len, Dots} = list_length(L, NameL + 2, 0),
    {{record, [{Name,NameL} | L]}, Len, Dots, no_more}.

print_length_fields([], _D, _T, Tuple, I, _RF, _Enc, _Str, _Ord)
                when I > tuple_size(Tuple) ->
    [];
print_length_fields(Term, D, T, Tuple, I, RF, Enc, Str, Ord)
                when D =:= 1; T =:= 0 ->
    More = fun(T1, Dd) ->
                   ?FUNCTION_NAME(Term, D+Dd, T1, Tuple, I, RF, Enc, Str, Ord)
           end,
    {dots, 3, 3, More};
print_length_fields([Def | Defs], D, T, Tuple, I, RF, Enc, Str, Ord) ->
    E = element(I, Tuple),
    T1 = case I =:= tuple_size(Tuple) of
             false -> tsub(T, 1);
             true -> T
         end,
    Field1 = print_length_field(Def, D - 1, T1, E, RF, Enc, Str, Ord),
    {_, Len1, _, _} = Field1,
    T2 = tsub(T1, Len1),
    [Field1 |
     print_length_fields(Defs, D - 1, T2, Tuple, I + 1, RF, Enc, Str, Ord)].

print_length_field(Def, D, T, E, RF, Enc, Str, Ord) ->
    Name = write_atom(Def, Enc),
    NameL = io_lib:chars_length(Name) + 3,
    {_, Len, Dots, _} =
        Field = print_length(E, D, tsub(T, NameL), RF, Enc, Str, Ord),
    {{field, Name, NameL, Field}, NameL + Len, Dots, no_more}.

print_length_list(List, D, T, RF, Enc, Str, Ord) ->
    L = print_length_list1(List, D, tsub(T, 2), RF, Enc, Str, Ord),
    {Len, Dots} = list_length(L, 2, 0),
    {{list, L}, Len, Dots, no_more}.

print_length_list1([], _D, _T, _RF, _Enc, _Str, _Ord) ->
    [];
print_length_list1(Term, D, T, RF, Enc, Str, Ord) when D =:= 1; T =:= 0->
    More = fun(T1, Dd) -> ?FUNCTION_NAME(Term, D+Dd, T1, RF, Enc, Str, Ord) end,
    {dots, 3, 3, More};
print_length_list1([E | Es], D, T, RF, Enc, Str, Ord) ->
    %% If E is the last element in list, don't account length for a comma.
    T1 = case Es =:= [] of
             false -> tsub(T, 1);
             true -> T
         end,
    {_, Len1, _, _} = Elem1 = print_length(E, D - 1, T1, RF, Enc, Str, Ord),
    [Elem1 | print_length_list1(Es, D - 1, tsub(T1, Len1), RF, Enc, Str, Ord)];
print_length_list1(E, D, T, RF, Enc, Str, Ord) ->
    print_length(E, D - 1, T, RF, Enc, Str, Ord).

list_length([], Acc, DotsAcc) ->
    {Acc, DotsAcc};
list_length([{_, Len, Dots, _} | Es], Acc, DotsAcc) ->
    list_length_tail(Es, Acc + Len, DotsAcc + Dots);
list_length({_, Len, Dots, _}, Acc, DotsAcc) ->
    {Acc + Len, DotsAcc + Dots}.

list_length_tail([], Acc, DotsAcc) ->
    {Acc, DotsAcc};
list_length_tail([{_, Len, Dots, _} | Es], Acc, DotsAcc) ->
    list_length_tail(Es, Acc + 1 + Len, DotsAcc + Dots);
list_length_tail({_, Len, Dots, _}, Acc, DotsAcc) ->
    {Acc + 1 + Len, DotsAcc + Dots}.

print_length_binary(Bin, D, T, RF, {InEnc, utf8} = Enc, Str, Ord) ->
    D1 = D - 1,
    case
        Str andalso
        (bit_size(Bin) rem 8) =:= 0 andalso
        printable_bin0(Bin, D1, tsub(T, 6), InEnc, binary)
    of
        {true, _Bin} ->
            {Utf8, Len} = io_lib:write_string_bin(Bin, [], latin1),
            {[$<,$<,$",Utf8,$",$>,$>], 6 + Len, 0, no_more};
        {false, _Bin} ->
            {Utf8, Len} = io_lib:write_string_bin(Bin, [], unicode),
            {[$<,$<,$",Utf8,"\"/utf8>>"], 11 + Len, 0, no_more};
        {true, true, Prefix} ->
            {S, Len} = io_lib:write_string_bin(Prefix, [], latin1), %"
            More = fun(T1, Dd) ->
                           ?FUNCTION_NAME(Bin, D+Dd, T1, RF, Enc, Str, Ord)
                   end,
            {[$<,$<,$",S|"\"...>>"], 9 + Len, 3, More};
        {false, true, Prefix} ->
            {S, Len} = io_lib:write_string_bin(Prefix, [], unicode), %"
            More = fun(T1, Dd) ->
                           ?FUNCTION_NAME(Bin, D+Dd, T1, RF, Enc, Str, Ord)
                   end,
            {[$<,$<,$",S|"\"/utf8...>>"], 14 + Len, 3, More};
        false ->
            case io_lib:write_binary_bin(Bin, D, T, <<>>) of
                {S, <<>>} ->
                    {{bin, S}, iolist_size(S), 0, no_more};
                {S, _Rest} ->
                    More = fun(T1, Dd) ->
                                   ?FUNCTION_NAME(Bin, D+Dd, T1, RF, Enc, Str, Ord)
                           end,
                    {{bin, S}, iolist_size(S), 3, More}
            end
    end;
print_length_binary(Bin, D, T, RF, Enc, Str, Ord) ->  %% list output
    D1 = D - 1,
    case
        Str andalso
        (bit_size(Bin) rem 8) =:= 0 andalso
        printable_bin0(Bin, D1, tsub(T, 6), Enc, list)
    of
        {true, List} when is_list(List) ->
            S = io_lib:write_string(List, $"), %"
            {[$<,$<,S,$>,$>], 4 + length(S), 0, no_more};
        {false, List} when is_list(List) ->
            S = io_lib:write_string(List, $"), %"
            {[$<,$<,S,"/utf8>>"], 9 + io_lib:chars_length(S), 0, no_more};
        {true, true, Prefix} ->
            S = io_lib:write_string(Prefix, $"), %"
            More = fun(T1, Dd) ->
                           ?FUNCTION_NAME(Bin, D+Dd, T1, RF, Enc, Str, Ord)
                   end,
            {[$<,$<,S|"...>>"], 7 + length(S), 3, More};
        {false, true, Prefix} ->
            S = io_lib:write_string(Prefix, $"), %"
            More = fun(T1, Dd) ->
                           ?FUNCTION_NAME(Bin, D+Dd, T1, RF, Enc, Str, Ord)
                   end,
            {[$<,$<,S|"/utf8...>>"], 12 + io_lib:chars_length(S), 3, More};
        false ->
            case io_lib:write_binary(Bin, D, T) of
                {S, <<>>} ->
                    {{bin, S}, iolist_size(S), 0, no_more};
                {S, _Rest} ->
                    More = fun(T1, Dd) ->
                                   ?FUNCTION_NAME(Bin, D+Dd, T1, RF, Enc, Str, Ord)
                           end,
                    {{bin, S}, iolist_size(S), 3, More}
            end
    end.

%% ?CHARS printable characters has depth 1.
-define(CHARS, 4).

%% only flat lists are "printable"
printable_list(_L, 1, _T, _Enc) ->
    false;
printable_list(L, D, T, {latin1, _}) ->
    printable_list(L, D, T, latin1);
printable_list(L, _D, T, latin1) when T < 0 ->
    io_lib:printable_latin1_list(L);
printable_list(L, _D, T, latin1) when T >= 0 ->
    N = tsub(T, 2),
    case printable_latin1_list(L, N) of
        all ->
            true;
        0 ->
            {L1, _} = lists:split(N, L),
            {true, L1};
        _NC ->
            false
    end;
printable_list(L, _D, T, _Unicode) when T >= 0 ->
    N = tsub(T, 2),
    %% Be careful not to traverse more of L than necessary.
    try string:slice(L, 0, N) of
        "" ->
            false;
        Prefix ->
            case is_flat(L, lists:flatlength(Prefix)) of
                true ->
                    case string:equal(Prefix, L) of
                        true ->
                            io_lib:printable_list(L);
                        false ->
                            io_lib:printable_list(Prefix)
                            andalso {true, Prefix}
                    end;
                false ->
                    false
            end
    catch _:_ -> false
    end;
printable_list(L, _D, T, _Uni) when T < 0->
    io_lib:printable_list(L).

is_flat(_L, 0) ->
    true;
is_flat([C|Cs], N) when is_integer(C) ->
    is_flat(Cs, N - 1);
is_flat(_, _N) ->
    false.

printable_bin0(Bin, D, T, InEnc, Type) ->
    Len = case D >= 0 of
              true ->
                  %% Use byte_size() also if Enc =/= latin1.
                  DChars = erlang:min(?CHARS * D, byte_size(Bin)),
                  case T >= 0 of
                      true ->
                          erlang:min(T, DChars);
                      false ->
                          DChars
                  end;
              false when T < 0 ->
                  byte_size(Bin);
              false when T >= 0 -> % cannot happen
                  T
          end,
    printable_bin(Bin, Len, D, InEnc, Type).

printable_bin(_Bin, 0, _D, _In, _Out) ->
    false;
printable_bin(Bin, Len, D, latin1, Out) when is_binary(Bin) ->
    case printable_latin1_bin(Bin, Len) of
        all when Len =:= byte_size(Bin) ->
            case Out of
                binary -> {true, Bin};
                list -> {true, binary_to_list(Bin)}
            end;
        all ->
            case Out of
                binary -> {true, true, binary:part(Bin, 0, Len)};
                list -> {true, true, binary_to_list(Bin, 1, Len)}
            end;
        NC when is_integer(NC), D > 0, Len - NC >= D ->
            case Out of
                binary -> {true, true, binary:part(Bin, 0, Len - NC)};
                list -> {true, true, binary_to_list(Bin, 1, Len - NC)}
            end;
        NC when is_integer(NC) ->
            false
    end;
printable_bin(Bin, Len, D, _Uni, Out) ->
    case printable_unicode_bin(Bin, Len, io:printable_range()) of
        not_utf8 ->
            printable_bin(Bin, Len, D, latin1, Out);
        {N, <<>>} when (Len - N) =:= byte_size(Bin) ->  %% Ascii only
            case Out of
                binary ->  {true, Bin};
                list -> {true, binary_to_list(Bin)}
            end;
        {_N, <<>>} ->
            case Out of
                binary -> {false, Bin};
                list -> {false, unicode:characters_to_list(Bin)}
            end;
        {N, RestBin} when D > 0, Len - N >= D ->
            Sz = byte_size(Bin)-byte_size(RestBin),
            Part = binary:part(Bin, 0, Sz),
            case Out of
                binary -> {Sz =:= (Len - N), true, Part};
                list -> {Sz =:= (Len - N), true, unicode:characters_to_list(Part)}
            end;
        _ ->
            false
    end.

%% -> all | integer() >=0. Adopted from io_lib.erl.
printable_latin1_list([_ | _], 0) -> 0;
printable_latin1_list([C | Cs], N) when is_integer(C), C >= $\s, C =< $~ ->
    printable_latin1_list(Cs, N - 1);
printable_latin1_list([C | Cs], N) when is_integer(C), C >= $\240, C =< $\377 ->
    printable_latin1_list(Cs, N - 1);
printable_latin1_list([$\n | Cs], N) -> printable_latin1_list(Cs, N - 1);
printable_latin1_list([$\r | Cs], N) -> printable_latin1_list(Cs, N - 1);
printable_latin1_list([$\t | Cs], N) -> printable_latin1_list(Cs, N - 1);
printable_latin1_list([$\v | Cs], N) -> printable_latin1_list(Cs, N - 1);
printable_latin1_list([$\b | Cs], N) -> printable_latin1_list(Cs, N - 1);
printable_latin1_list([$\f | Cs], N) -> printable_latin1_list(Cs, N - 1);
printable_latin1_list([$\e | Cs], N) -> printable_latin1_list(Cs, N - 1);
printable_latin1_list([], _) -> all;
printable_latin1_list(_, N) -> N.

printable_latin1_bin(<<>>, _) -> all;
printable_latin1_bin(_, 0) -> 0;
printable_latin1_bin(<<Char:8, Rest/binary>>, N) ->
    case printable_char(Char, latin1) of
        true -> printable_latin1_bin(Rest, N-1);
        false -> N
    end.

printable_unicode_bin(<<C/utf8, R/binary>>=Bin, I, Range) when I > 0 ->
    case printable_char(C, Range) of
        true -> printable_unicode_bin(R, I-1, Range);
        false -> {I, Bin}
    end;
printable_unicode_bin(<<_/utf8, _/binary>>=Bin, I, _Range) ->
    {I, Bin};
printable_unicode_bin(<<>>, I, _Range) ->
    {I, <<>>};
printable_unicode_bin(_, _, _) ->
    not_utf8.

printable_char($\n,_) -> true;
printable_char($\r,_) -> true;
printable_char($\t,_) -> true;
printable_char($\v,_) -> true;
printable_char($\b,_) -> true;
printable_char($\f,_) -> true;
printable_char($\e,_) -> true;
printable_char(C,latin1) ->
    C >= $\s andalso C =< $~ orelse
    C >= 16#A0 andalso C =< 16#FF;
printable_char(C,unicode) ->
    C >= $\s andalso C =< $~ orelse
    C >= 16#A0 andalso C < 16#D800 orelse
    C > 16#DFFF andalso C < 16#FFFE orelse
    C > 16#FFFF andalso C =< 16#10FFFF.

write_atom(A, latin1) ->
    io_lib:write_atom_as_latin1(A);
write_atom(A, {latin1, _}) ->
    io_lib:write_atom_as_latin1(A);
write_atom(A, _Uni) ->
    io_lib:write_atom(A).

write_string(S0, latin1) ->
    S = io_lib:write_latin1_string(S0, $"), %"
    {S, io_lib:chars_length(S)};
write_string(S0, {InEnc, _Out}) ->
    io_lib:write_string_bin(S0, $", InEnc); %"
write_string(S0, _Uni) ->
    S = io_lib:write_string(S0, $"), %"
    {S, io_lib:chars_length(S)}.

expand({_, _, _Dots=0, no_more} = If, _T, _Dd) -> If;
expand({{tuple,IsTagged,L}, _Len, _, no_more}, T, Dd) ->
    {NL, NLen, NDots} = expand_list(L, T, Dd, 2),
    {{tuple,IsTagged,NL}, NLen, NDots, no_more};
expand({{map, Pairs}, _Len, _, no_more}, T, Dd) ->
    {NPairs, NLen, NDots} = expand_list(Pairs, T, Dd, 3),
    {{map, NPairs}, NLen, NDots, no_more};
expand({{map_pair, K, V}, _Len, _, no_more}, T, Dd) ->
    {_, KL, KD, _} = P1 = expand(K, tsub(T, 1), Dd),
    KL1 = KL + 4,
    {_, VL, VD, _} = P2 = expand(V, tsub(T, KL1), Dd),
    {{map_pair, P1, P2}, KL1 + VL, KD + VD, no_more};
expand({{record, [{Name,NameL} | L]}, _Len, _, no_more}, T, Dd) ->
    {NL, NLen, NDots} = expand_list(L, T, Dd, NameL + 2),
    {{record, [{Name,NameL} | NL]}, NLen, NDots, no_more};
expand({{field, Name, NameL, Field}, _Len, _, no_more}, T, Dd) ->
    F = {_S, L, Dots, _} = expand(Field, tsub(T, NameL), Dd),
    {{field, Name, NameL, F}, NameL + L, Dots, no_more};
expand({_, _, _, More}, T, Dd) ->
    More(T, Dd).

expand_list(Ifs, T, Dd, L0) ->
    L = expand_list(Ifs, tsub(T, L0), Dd),
    {Len, Dots} = list_length(L, L0, 0),
    {L, Len, Dots}.

expand_list([], _T, _Dd) ->
    [];
expand_list([If | Ifs], T, Dd) ->
    T1 = case Ifs =:= [] of
             false -> tsub(T, 1);
             true -> T
         end,
    {_, Len1, _, _} = Elem1 = expand(If, T1, Dd),
    [Elem1 | expand_list(Ifs, tsub(T1, Len1), Dd)];
expand_list({_, _, _, More}, T, Dd) ->
    More(T, Dd).

%% Make sure T does not change sign.
tsub(T, _) when T < 0 -> T;
tsub(T, E) when T >= E -> T - E;
tsub(_, _) -> 0.

%% Throw 'no_good' if the indentation exceeds half the line length
%% unless there is room for M characters on the line.

cind({_S, Len, _, _}, Col, Ll, M, Ind, LD, W) when Len < Ll - Col - LD,
                                                   Len + W + LD =< M ->
    Ind;
cind({{list,L}, _Len, _, _}, Col, Ll, M, Ind, LD, W) ->
    cind_list(L, Col + 1, Ll, M, Ind, LD, W + 1);
cind({{tuple,true,L}, _Len, _ ,_}, Col, Ll, M, Ind, LD, W) ->
    cind_tag_tuple(L, Col, Ll, M, Ind, LD, W + 1);
cind({{tuple,false,L}, _Len, _, _}, Col, Ll, M, Ind, LD, W) ->
    cind_list(L, Col + 1, Ll, M, Ind, LD, W + 1);
cind({{map,Pairs}, _Len, _, _}, Col, Ll, M, Ind, LD, W) ->
    cind_map(Pairs, Col + 2, Ll, M, Ind, LD, W + 2);
cind({{record,[{_Name,NLen} | L]}, _Len, _, _}, Col, Ll, M, Ind, LD, W) ->
    cind_record(L, NLen, Col, Ll, M, Ind, LD, W + NLen + 1);
cind({{bin,_S}, _Len, _, _}, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind;
cind({_S,_Len,_,_}, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind.

cind_tag_tuple([{_Tag,Tlen,_,_} | L], Col, Ll, M, Ind, LD, W) ->
    TagInd = Tlen + 2,
    Tcol = Col + TagInd,
    if
        Ind > 0, TagInd > Ind ->
            Col1 = Col + Ind,
            if
                M + Col1 =< Ll; Col1 =< Ll div 2 ->
                    cind_tail(L, Col1, Tcol, Ll, M, Ind, LD, W + Tlen);
                true ->
                    throw(no_good)
            end;
        M + Tcol < Ll; Tcol < Ll div 2 ->
            cind_list(L, Tcol, Ll, M, Ind, LD, W + Tlen + 1);
        true ->
            throw(no_good)
    end;
cind_tag_tuple(_, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind.

cind_map([P | Ps], Col, Ll, M, Ind, LD, W) ->
    PW = cind_pair(P, Col, Ll, M, Ind, last_depth(Ps, LD), W),
    cind_pairs_tail(Ps, Col, Col + PW, Ll, M, Ind, LD, W + PW);
cind_map(_, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind.                                        % cannot happen

cind_pairs_tail([{_, Len, _, _} = P | Ps], Col0, Col, Ll, M, Ind, LD, W) ->
    LD1 = last_depth(Ps, LD),
    ELen = 1 + Len,
    if
        LD1 =:= 0, ELen + 1 < Ll - Col, W + ELen + 1 =< M, ?ATM_PAIR(P);
        LD1 > 0, ELen < Ll - Col - LD1, W + ELen + LD1 =< M, ?ATM_PAIR(P) ->
            cind_pairs_tail(Ps, Col0, Col + ELen, Ll, M, Ind, LD, W + ELen);
        true ->
            PW = cind_pair(P, Col0, Ll, M, Ind, LD1, 0),
            cind_pairs_tail(Ps, Col0, Col0 + PW, Ll, M, Ind, LD, PW)
    end;
cind_pairs_tail(_, _Col0, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind.

cind_pair({{map_pair, _Key, _Value}, Len, _, _}=Pair, Col, Ll, M, _Ind, LD, W)
         when Len < Ll - Col - LD, Len + W + LD =< M ->
    if
        ?ATM_PAIR(Pair) ->
            Len;
        true ->
            Ll
    end;
cind_pair({{map_pair, K, V}, _Len, _, _}, Col0, Ll, M, Ind, LD, W0) ->
    cind(K, Col0, Ll, M, Ind, LD, W0),
    I = map_value_indent(Ind),
    cind(V, Col0 + I, Ll, M, Ind, LD, 0),
    Ll.

map_value_indent(TInd) ->
    case TInd > 0 of
        true ->
            TInd;
        false ->
            4
    end.

cind_record([F | Fs], Nlen, Col0, Ll, M, Ind, LD, W0) ->
    Nind = Nlen + 1,
    {Col, W} = cind_rec(Nind, Col0, Ll, M, Ind, W0),
    FW = cind_field(F, Col, Ll, M, Ind, last_depth(Fs, LD), W),
    cind_fields_tail(Fs, Col, Col + FW, Ll, M, Ind, LD, W + FW);
cind_record(_, _Nlen, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind.

cind_fields_tail([{_, Len, _, _} = F | Fs], Col0, Col, Ll, M, Ind, LD, W) ->
    LD1 = last_depth(Fs, LD),
    ELen = 1 + Len,
    if
        LD1 =:= 0, ELen + 1 < Ll - Col, W + ELen + 1 =< M, ?ATM_FLD(F);
        LD1 > 0, ELen < Ll - Col - LD1, W + ELen + LD1 =< M, ?ATM_FLD(F) ->
            cind_fields_tail(Fs, Col0, Col + ELen, Ll, M, Ind, LD, W + ELen);
        true ->
            FW = cind_field(F, Col0, Ll, M, Ind, LD1, 0),
            cind_fields_tail(Fs, Col0, Col + FW, Ll, M, Ind, LD, FW)
    end;
cind_fields_tail(_, _Col0, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind.

cind_field({{field, _N, _NL, _F}, Len, _, _}=Fl, Col, Ll, M, _Ind, LD, W)
         when Len < Ll - Col - LD, Len + W + LD =< M ->
    if
        ?ATM_FLD(Fl) ->
            Len;
        true ->
            Ll
    end;
cind_field({{field, _Name, NameL, F},_Len,_,_}, Col0, Ll, M, Ind, LD, W0) ->
    {Col, W} = cind_rec(NameL, Col0, Ll, M, Ind, W0 + NameL),
    cind(F, Col, Ll, M, Ind, LD, W),
    Ll.

cind_rec(RInd, Col0, Ll, M, Ind, W0) ->
    Nl = (Ind > 0) and (RInd > Ind),
    DCol = case Nl of
               true -> Ind;
               false -> RInd
           end,
    Col = Col0 + DCol,
    if
        M + Col =< Ll; Col =< Ll div 2 ->        
            W = case Nl of
                    true -> 0;
                    false -> W0
                end,
            {Col, W};
        true ->
            throw(no_good)
    end.

cind_list({dots, _, _, _}, _Col0, _Ll, _M, Ind, _LD, _W) ->
    Ind;
cind_list([E | Es], Col0, Ll, M, Ind, LD, W) ->
    WE = cind_element(E, Col0, Ll, M, Ind, last_depth(Es, LD), W),
    cind_tail(Es, Col0, Col0 + WE, Ll, M, Ind, LD, W + WE).

cind_tail([], _Col0, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind;
cind_tail([{_, Len, _, _} = E | Es], Col0, Col, Ll, M, Ind, LD, W) ->
    LD1 = last_depth(Es, LD),
    ELen = 1 + Len,
    if 
        LD1 =:= 0, ELen + 1 < Ll - Col, W + ELen + 1 =< M, ?ATM(E);
        LD1 > 0, ELen < Ll - Col - LD1, W + ELen + LD1 =< M, ?ATM(E) ->
            cind_tail(Es, Col0, Col + ELen, Ll, M, Ind, LD, W + ELen);
        true -> 
            WE = cind_element(E, Col0, Ll, M, Ind, LD1, 0),
            cind_tail(Es, Col0, Col0 + WE, Ll, M, Ind, LD, WE)
    end;
cind_tail({dots, _, _, _}, _Col0, _Col, _Ll, _M, Ind, _LD, _W) ->
    Ind;
cind_tail({_, Len, _, _}=E, _Col0, Col, Ll, M, Ind, LD, W)
                  when Len + 1 < Ll - Col - (LD + 1), 
                       Len + 1 + W + (LD + 1) =< M, 
                       ?ATM(E) ->
    Ind;
cind_tail(E, _Col0, Col, Ll, M, Ind, LD, _W) ->
    cind(E, Col, Ll, M, Ind, LD + 1, 0).

cind_element({_, Len, _, _}=E, Col, Ll, M, _Ind, LD, W)
           when Len < Ll - Col - LD, Len + W + LD =< M, ?ATM(E) ->
    Len;
cind_element(E, Col, Ll, M, Ind, LD, W) ->
    cind(E, Col, Ll, M, Ind, LD, W),
    Ll.

last_depth([_ | _], _LD) ->
    0;
last_depth(_, LD) ->
    LD + 1.

while_fail([], _F, V) ->
    V;
while_fail([A | As], F, V) ->
    try F(A) catch _ -> while_fail(As, F, V) end.

%% make a string of N spaces
indent(N) when is_integer(N), N > 0 ->
    chars($\s, N-1).

%% prepend N spaces onto Ind
indent(1, Ind) -> % Optimization of common case
    [$\s | Ind];
indent(4, Ind) -> % Optimization of common case
    S2 = [$\s, $\s],
    [S2, S2 | Ind];
indent(N, Ind) when is_integer(N), N > 0 ->
    [chars($\s, N) | Ind].

%% A deep version of string:chars/2
chars(_C, 0) ->
    [];
chars(C, 2) ->
    [C, C];
chars(C, 3) ->
    [C, C, C];
chars(C, N) when (N band 1) =:= 0 ->
    S = chars(C, N bsr 1),
    [S | S];
chars(C, N) ->
    S = chars(C, N bsr 1),
    [C, S | S].

get_option(Key, TupleList, Default) ->
    case lists:keyfind(Key, 1, TupleList) of
	false -> Default;
	{Key, Value} -> Value;
	_ -> Default
    end.
