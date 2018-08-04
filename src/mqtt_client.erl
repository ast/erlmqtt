%%%-------------------------------------------------------------------
%%% @author albin
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 24. Jul 2017 08.57
%%%-------------------------------------------------------------------
-module(mqtt_client).
-author("albin").

-behaviour(gen_server).

%% API
-export([start_link/1,
  start/1,
  stop/1,
  publish/3,
  subscribe/2,
  ping/1]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-include("mqtt.hrl").

-define(SERVER, ?MODULE).

-record(state, {parent :: pid(),
  client_identifier = "default" :: string(),
  host = "localhost" :: inet:ip_address() | string(),
  port = 1883 :: inet:port_number(),
  sock :: inet:socket(),
  data = <<>> :: binary()}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Args :: term()) ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Opts) when is_list(Opts) ->
  gen_server:start_link(?MODULE, Opts, []).
start(Opts) when is_list(Opts) ->
  gen_server:start(?MODULE, Opts, []).
stop(C) ->
  gen_server:stop(C).

publish(C, Topic, Payload) ->
  gen_server:cast(C, {mqtt_publish, Topic, Payload}).
ping(C) ->
  gen_server:cast(C, mqtt_ping).
subscribe(C, Topic) ->
  gen_server:cast(C, {mqtt_subscribe, Topic}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init(Opts) ->
  io:format("~p ~n", [Opts]),
  State = init(Opts, #state{}),
  self() ! mqtt_connect,
  {ok, State}.

% Get options
init([], State) ->
  State;
init([{client_identifier, ClientIdentifier} | Opts], State) ->
  init(Opts, State#state{client_identifier = ClientIdentifier});
init([{host, Host} | Opts], State) ->
  init(Opts, State#state{host = Host});
init([{port, Port} | Opts], State) ->
  init(Opts, State#state{port = Port}).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).

handle_cast(mqtt_ping, #state{sock = Sock} = State) ->
  gen_tcp:send(Sock, pingreq_packet()),
  {noreply, State};

handle_cast({mqtt_subscribe, Topic}, #state{sock = Sock} = State) ->
  gen_tcp:send(Sock, subscribe_packet(16, [{Topic, 0}])),
  {noreply, State};

handle_cast({mqtt_publish, Topic, Payload}, #state{sock = Sock} = State) ->
  gen_tcp:send(Sock, publish_packet(Topic, Payload, [])),
  {noreply, State};

handle_cast(_Request, State) ->
  io:format("unhandled cast~n"),
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_info(mqtt_connect, #state{host = Host, port = Port, client_identifier = ClientIdentifier} = State) ->
  {ok, Sock} = gen_tcp:connect(Host, Port,
    [binary, {packet, 0}]),
  gen_tcp:send(Sock, connect_packet(ClientIdentifier, [])),
  {noreply, State#state{sock = Sock}};
handle_info({tcp, Sock, Data1}, #state{sock = Sock, data = Data0} = State) ->
  Data3 = <<Data0/binary, Data1/binary>>,
  NState = case handle_packet(Data3) of
             ok -> State#state{data = <<>>};          % consumed all data
             {ok, Rest} -> State#state{data = Rest};  % left some data
             more_data -> State#state{data = Data3}   % need more data
           end,
  %io:format("State: ~p ~n", [NState]),
  {noreply, NState};
handle_info(Info, State) ->
  io:format("unhandled: ~p~n", [Info]),
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

handle_packet(<<Type:4, Flags:4, Rest/binary>>) ->
  {ExpectedLength, Data} = decode_length(Rest),
  Length = byte_size(Data),
  if
    ExpectedLength =:= Length ->
      handle_packet(Type, Flags, Data);
    ExpectedLength > Length ->
      <<Payload2:ExpectedLength/binary, Rest2/binary>> = Data,
      Ret = handle_packet(Type, Flags, Payload2),
      {Ret, Rest2};
    ExpectedLength < Length ->
      more_data
  end.

handle_packet(?CONNACK, ?CONNACK_FLAGS, <<0:7, SessionPresent:1, ReturnCode:8>>) ->
  io:format("CONNACK: ~p ~p ~n", [SessionPresent, ReturnCode]),
  ok;

handle_packet(?PUBLISH, Flags, Data) ->
  <<Dup:1, QoS:2, Retain:1>> = <<Flags:4>>,
  {Topic, Payload} = decode_string(Data),
  io:format("PUBLISH: ~p ~p ~p ~p ~p ~n", [Dup, QoS, Retain, Topic, Payload]),
  ok;

handle_packet(?SUBACK, ?SUBACK_FLAGS, <<PacketIdentifier:16, ReturnCodes/binary>>) ->
  io:format("SUBACK: ~p ~p ~n", [PacketIdentifier, ReturnCodes]),
  ok;

handle_packet(?PINGRESP, ?PINGRESP_FLAGS, <<>>) ->
  io:format("PINGRESP: ~n"),
  ok;

handle_packet(Type, Flags, Payload) ->
  io:format("Unknown: ~p ~p ~p ~n", [Type, Flags, Payload]),
  ok.

connect_packet(ClientIdentifier) ->
  connect_packet(ClientIdentifier, []).

connect_packet(ClientIdentifier, Opts) when is_list(Opts) ->
  FH = <<?CONNECT:4, ?CONNECT_FLAGS:4>>,

  % Options
  KeepAlive = proplists:get_value(keep_alive, Opts, ?DEFAULT_KEEP_ALIVE),

  {UsernameFlag, Username} =
    case proplists:get_value(username, Opts) of
      U when is_list(U) -> {1, encode_string(U)};
      undefined -> {0, <<>>}
    end,

  {PasswordFlag, Password} =
    case proplists:get_value(username, Opts) of
      P when is_list(P) -> {1, encode_string(P)};
      undefined -> {0, <<>>}
    end,

  {WillFlag, WillQoS, WillRetain, WillTopic, WillMessage} =
    case proplists:get_value(will, Opts) of
      {WT, WM} -> {1, 0, 0, encode_string(WT), <<(byte_size(WM)):16, WM/binary>>};
      {WT, WM, WQoS} -> {1, WQoS, 0, encode_string(WT), <<(byte_size(WM)):16, WM/binary>>};
      {WT, WM, WQoS, true} -> {1, WQoS, 1, encode_string(WT), <<(byte_size(WM)):16, WM/binary>>};
      undefined -> {0, 0, 0, <<>>, <<>>}
    end,

  CleanSessionFlag = bool_to_int(proplists:get_value(clean_session, Opts, false)),

  VH =
    <<(encode_string("MQTT"))/binary,
      ?PROTOCOL_LEVEL:8,
      UsernameFlag:1,
      PasswordFlag:1,
      WillRetain:1,
      WillQoS:2,
      WillFlag:1,
      CleanSessionFlag:1,
      0:1, % Reserved
      KeepAlive:16>>,

  % Taking advantage here of the fact that Erlang allows empty binaries.
  Payload =
    <<(encode_string(ClientIdentifier))/binary,
      WillTopic/binary,
      WillMessage/binary,
      Username/binary,
      Password/binary>>,

  RemainingLength = byte_size(VH) + byte_size(Payload),
  <<FH/binary,
    (encode_length(RemainingLength))/binary,
    VH/binary,
    Payload/binary>>.

connack_packet(SessionPresent, ReturnCode) ->
  SP = bool_to_int(SessionPresent),
  RemainingLength = 2,
  <<?CONNACK:4, ?CONNACK_FLAGS:4, RemainingLength, 0:7, SP:1, ReturnCode>>.

publish_packet(Topic, Message, Opts) ->
  Dup = bool_to_int(proplists:get_value(dup, Opts, false)),
  QoS = proplists:get_value(qos, Opts, 0),
  Retain = bool_to_int(proplists:get_value(retain, Opts, false)),

  Flags = <<Dup:1, QoS:2, Retain:1>>,
  FH = <<?PUBLISH:4, Flags:4/bitstring>>,
  Payload = Message,
  % Topic Name, Packet Identifier.
  VH = <<(encode_string(Topic))/binary>>,
  RemainingLength = byte_size(VH) + byte_size(Payload),
  <<FH/binary,
    (encode_length(RemainingLength))/binary,
    VH/binary,
    Payload/binary>>.

pubrel_packet(PacketIdentifier) ->
  RemainingLength = 2,
  <<?PUBREL:4, ?PUBREL_FLAGS:4, RemainingLength, PacketIdentifier:16>>.

puback_packet(PacketIdentifier) ->
  RemainingLength = 2,
  <<?PUBACK:4, ?PUBACK_FLAGS:4, RemainingLength, PacketIdentifier:16>>.

pubrec_packet(PacketIdentifier) ->
  RemainingLength = 2,
  <<?PUBREC:4, ?PUBREC_FLAGS:4, RemainingLength, PacketIdentifier:16>>.

pubcomp_packet(PacketIdentifier) ->
  RemainingLength = 2,
  <<?PUBCOMP:4, ?PUBCOMP_FLAGS:4, RemainingLength, PacketIdentifier:16>>.

subscribe_packet(PacketIdentifier, Topics) ->
  FH = <<?SUBSCRIBE:4, ?SUBSCRIBE_FLAGS:4>>,
  VH = <<PacketIdentifier:16>>,
  Payload = <<<<(encode_string(T))/binary, 0:6, QoS:2>> || {T, QoS} <- Topics>>,
  RemainingLength = byte_size(VH) + byte_size(Payload),
  <<FH/binary,
    (encode_length(RemainingLength))/binary,
    VH/binary,
    Payload/binary>>.

suback_packet(PacketIdentifier, ReturnCodes) when is_list(ReturnCodes) ->
  FH = <<?SUBACK:4, ?SUBACK_FLAGS:4>>,
  VH = <<PacketIdentifier:16>>,
  Payload = <<<<Code>> || Code <- ReturnCodes>>,
  RemainingLength = byte_size(VH) + byte_size(Payload),
  <<FH/binary,
    (encode_length(RemainingLength))/binary,
    VH/binary,
    Payload/binary>>.

unsubscribe_packet(PacketIdentifier, Topics) when is_list(Topics) ->
  FH = <<?UNSUBSCRIBE:4, ?UNSUBSCRIBE_FLAGS:4>>,
  VH = <<PacketIdentifier:16>>,
  Payload = <<<<(encode_string(Topic))/binary>> || Topic <- Topics>>,
  RemainingLength = byte_size(VH) + byte_size(Payload),
  <<FH/binary,
    (encode_length(RemainingLength))/binary,
    VH/binary,
    Payload/binary>>.

unsuback_packet(PacketIdentifier) ->
  RemainingLength = 2,
  <<?UNSUBACK:4, ?UNSUBACK_FLAGS:4, RemainingLength, PacketIdentifier:16>>.

pingreq_packet() ->
  RemainingLength = 0, % PINGREQ length is always 0.
  <<?PINGREQ:4, ?PINGREQ_FLAGS:4, RemainingLength:8>>.

pingresp_packet() ->
  RemainingLength = 0,
  <<?PINGRESP:4, ?PINGRESP_FLAGS:4, RemainingLength>>.

disconnect_packet() ->
  RemainingLength = 0,
  <<?DISCONNECT:4, ?DISCONNECT_FLAGS:4, RemainingLength>>.


%% Utility functions

bool_to_int(true) -> 1;
bool_to_int(false) -> 0.

decode_string(<<Length:16, Utf8:Length/binary, Rest/binary>>) ->
  String = unicode:characters_to_list(Utf8),
  {String, Rest}.

encode_string(String) ->
  B = unicode:characters_to_binary(String),
  L = byte_size(B),
  <<L:16, B/binary>>.

%% Remaining length of payload
decode_length(Bin) ->
  decode_length(Bin, 1).
decode_length(<<0:1, B:7, Rest/binary>>, Mul) ->
  {B * Mul, Rest};
decode_length(<<1:1, B:7, Rest/binary>>, Mul) when Mul < (128 * 128 * 128) ->
  B * Mul + decode_length(Rest, Mul * 128).

encode_length(Length) when is_integer(Length), Length < (128 * 128 * 128 * 128) ->
  encode_length(Length, <<>>).
encode_length(Length, Bin) ->
  B = Length rem 128,
  R = Length div 128,
  if
    R > 0 -> encode_length(R, <<Bin/binary, 1:1, B:7>>);
    R =:= 0 -> <<Bin/binary, 0:1, B:7>>
  end.