-module(radius_dict).

%% API
-export([add/1, lookup_attribute/1, lookup_value/2, to_list/1]).

-include("radius.hrl").

-define(ATTRS_TABLE, radius_dict_attrs).
-define(VALUES_TABLE, radius_dict_values).

%% @doc Adds RADIUS attribute/value to internal storage
-spec add(#attribute{} | #value{}) -> ok.
add(Attribute) when is_record(Attribute, attribute) ->
    ets:insert(?ATTRS_TABLE, Attribute), ok;
add(Value) when is_record(Value, value) ->
    Key = {Value#value.aname, Value#value.value},
    ets:insert(?VALUES_TABLE, {Key, Value}), ok.

%% @doc Looking for the specified RADIUS attribute
-spec lookup_attribute(string() | non_neg_integer() | tuple()) ->
    not_found | #attribute{}.
lookup_attribute(Name) when is_binary(Name) ->
    Pattern = {attribute, '_', '_', Name, '_'},
    case ets:match_object(?ATTRS_TABLE, Pattern, 1) of
        {[Attribute], _} ->
            Attribute;
        '$end_of_table' ->
            not_found
    end;
lookup_attribute(Code) ->
    case ets:lookup(?ATTRS_TABLE, Code) of
        [Attribute] ->
            Attribute;
        [] ->
            not_found
    end.

%% @doc Looking for the specified RADIUS value
-spec lookup_value(string(), string()) -> not_found | term().
lookup_value(A, V) ->
    case ets:lookup(?VALUES_TABLE, {A, V}) of
        [{_Key, Value}] ->
            Value;
        [] ->
            not_found
    end.

%% @doc Returns the list of registered attributes or values.
to_list(attrs) ->
    ets:tab2list(?ATTRS_TABLE);
to_list(values) ->
    ets:tab2list(?VALUES_TABLE).
