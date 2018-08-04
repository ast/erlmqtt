%%%-------------------------------------------------------------------
%%% @author albin
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 28. Jul 2017 09.59
%%%-------------------------------------------------------------------
-author("albin").

-define(PROTOCOL_LEVEL, 4).

-define(DEFAULT_KEEP_ALIVE, 600).

-define(CONNECT, 1).
-define(CONNACK, 2).
-define(PUBLISH, 3).
-define(PUBACK, 4).
-define(PUBREC, 5).
-define(PUBREL, 6).
-define(PUBCOMP, 7).
-define(SUBSCRIBE, 8).
-define(SUBACK, 9).
-define(UNSUBSCRIBE, 10).
-define(UNSUBACK, 11).
-define(PINGREQ, 12).
-define(PINGRESP, 13).
-define(DISCONNECT, 14).

-define(CONNECT_FLAGS, 0).
-define(CONNACK_FLAGS, 0).
% PUBLISH does not have fixed flags.
-define(PUBACK_FLAGS, 0).
-define(PUBREC_FLAGS, 0).
-define(PUBREL_FLAGS, 2).
-define(PUBCOMP_FLAGS, 0).
-define(SUBSCRIBE_FLAGS, 2).
-define(SUBACK_FLAGS, 0).
-define(UNSUBSCRIBE_FLAGS, 2).
-define(UNSUBACK_FLAGS, 0).
-define(PINGREQ_FLAGS, 0).
-define(PINGRESP_FLAGS, 0).
-define(DISCONNECT_FLAGS, 0).