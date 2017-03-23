-module(radius_dict_file).

-export([load/1]).

-include("radius.hrl").

load(File) ->
    {ok, Fd} = file:open(dictionary_path(File), [read]),
    lists:flatten(read_line(Fd)).

%% Internal functions
dictionary_path(File) ->
    PrivDir = case code:priv_dir(radius) of
        {error, bad_name} ->
            "./priv";
        D -> D
    end,
    filename:join([PrivDir, File]).

read_line(Fd) ->
    read_line(Fd, []).
read_line(Fd, Acc) ->
    case io:get_line(Fd, "") of
        eof ->
            ok = file:close(Fd),
            lists:reverse(Acc);
        Line ->
            L = strip_comments(Line),
            case parse_line(string:tokens(L, "\t\n\s")) of
                {ok, Result} ->
                    read_line(Fd, [Result | Acc]);
                _ ->
                    read_line(Fd, Acc)
            end
    end.

strip_comments(Line) ->
    case string:chr(Line, $#) of
        0 ->
            Line;
        I ->
            L = string:sub_string(Line, 1, I - 1),
            string:strip(L)
    end.

parse_line(["$INCLUDE", File]) ->
    {ok, load(File)};

parse_line(["ATTRIBUTE", Name, "0x" ++ Code, Type]) ->
    {ok, #attribute{name = list_to_binary(Name), code = list_to_integer(Code,16), type = list_to_atom(Type)}};

parse_line(["ATTRIBUTE", Name, Code, Type]) ->
    case get(vendor) of
        undefined ->
            {ok, #attribute{name = list_to_binary(Name), code = list_to_integer(Code), type = list_to_atom(Type)}};
        Vendor ->
            C = {Vendor, list_to_integer(Code)},
            A = #attribute{name = Name, code = C, type = list_to_atom(Type)},
            {ok, A}
    end;

parse_line(["ATTRIBUTE", Name, Code, Type, Extra]) ->
    case get(vendor) of
        undefined ->
            Opts = [parse_option(string:tokens(I, "=")) || I <- string:tokens(Extra, ",")],
            A = #attribute{name = list_to_binary(Name), code = list_to_integer(Code), type = list_to_atom(Type)},
            {ok, A#attribute{opts = Opts}};
        Vendor ->
            C = {Vendor, list_to_integer(Code)},
            A = #attribute{name = Name, code = C, type = list_to_atom(Type)},
            {ok, A}
    end;

parse_line(["VALUE", A, Name, "0x" ++ Value]) ->
    V = #value{aname = list_to_binary(A), vname = list_to_binary(Name), value = list_to_integer(Value, 16)},
    {ok, V};

parse_line(["VALUE", A, Name, Value]) ->
    V = #value{aname = list_to_binary(A), vname = list_to_binary(Name), value = list_to_integer(Value)},
    {ok, V};
parse_line(["VENDOR", Name, Code]) ->
    put(vendor, list_to_integer(Code));
parse_line(["END VENDOR" | _ ]) ->
    erase(vendor);
parse_line(_) ->
    ok.

parse_option(["has_tag"]) ->
    has_tag;
parse_option(["concat"]) ->
    concat;
parse_option(["encrypt", Value]) ->
    {encrypt, list_to_integer(Value)}.
