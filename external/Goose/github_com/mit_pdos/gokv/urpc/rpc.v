(* autogenerated from github.com/mit-pdos/gokv/urpc/rpc *)
From Perennial.goose_lang Require Import prelude.
From Perennial.goose_lang Require Import ffi.grove_prelude.

From Goose Require github_com.goose_lang.std.
From Goose Require github_com.tchajed.marshal.

Definition HostName: ty := uint64T.

Definition RPCServer := struct.decl [
  "handlers" :: mapT ((slice.T byteT -> refT (slice.T byteT) -> unitT)%ht)
].

Definition RPCServer__rpcHandle: val :=
  rec: "RPCServer__rpcHandle" "srv" "conn" "rpcid" "seqno" "data" :=
    let: "replyData" := ref (zero_val (slice.T byteT)) in
    let: "f" := Fst (MapGet (struct.loadF RPCServer "handlers" "srv") "rpcid") in
    "f" "data" "replyData";;
    let: "num_bytes" := std.SumAssumeNoOverflow (#8 + #8) (slice.len (![slice.T byteT] "replyData")) in
    let: "e" := marshal.NewEnc "num_bytes" in
    marshal.Enc__PutInt "e" "seqno";;
    marshal.Enc__PutInt "e" (slice.len (![slice.T byteT] "replyData"));;
    marshal.Enc__PutBytes "e" (![slice.T byteT] "replyData");;
    grove_ffi.Send "conn" (marshal.Enc__Finish "e");;
    #().

Definition MakeRPCServer: val :=
  rec: "MakeRPCServer" "handlers" :=
    struct.new RPCServer [
      "handlers" ::= "handlers"
    ].

Definition RPCServer__readThread: val :=
  rec: "RPCServer__readThread" "srv" "conn" :=
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      let: "r" := grove_ffi.Receive "conn" in
      (if: struct.get grove_ffi.ReceiveRet "Err" "r"
      then Break
      else
        let: "data" := struct.get grove_ffi.ReceiveRet "Data" "r" in
        let: "d" := marshal.NewDec "data" in
        let: "rpcid" := marshal.Dec__GetInt "d" in
        let: "seqno" := marshal.Dec__GetInt "d" in
        let: "reqLen" := marshal.Dec__GetInt "d" in
        let: "req" := marshal.Dec__GetBytes "d" "reqLen" in
        RPCServer__rpcHandle "srv" "conn" "rpcid" "seqno" "req";;
        Continue));;
    #().

Definition RPCServer__Serve: val :=
  rec: "RPCServer__Serve" "srv" "host" "numWorkers" :=
    let: "listener" := grove_ffi.Listen "host" in
    Fork (Skip;;
          (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
            let: "conn" := grove_ffi.Accept "listener" in
            Fork (RPCServer__readThread "srv" "conn");;
            Continue));;
    #().

Definition callbackStateWaiting : expr := #0.

Definition callbackStateDone : expr := #1.

Definition callbackStateAborted : expr := #2.

Definition callback := struct.decl [
  "reply" :: refT (slice.T byteT);
  "state" :: refT uint64T;
  "cond" :: condvarRefT
].

Definition RPCClient := struct.decl [
  "mu" :: lockRefT;
  "conn" :: grove_ffi.Connection;
  "seq" :: uint64T;
  "pending" :: mapT (struct.ptrT callback)
].

Definition RPCClient__replyThread: val :=
  rec: "RPCClient__replyThread" "cl" :=
    Skip;;
    (for: (λ: <>, #true); (λ: <>, Skip) := λ: <>,
      let: "r" := grove_ffi.Receive (struct.loadF RPCClient "conn" "cl") in
      (if: struct.get grove_ffi.ReceiveRet "Err" "r"
      then
        lock.acquire (struct.loadF RPCClient "mu" "cl");;
        MapIter (struct.loadF RPCClient "pending" "cl") (λ: <> "cb",
          struct.loadF callback "state" "cb" <-[uint64T] callbackStateAborted;;
          lock.condSignal (struct.loadF callback "cond" "cb"));;
        lock.release (struct.loadF RPCClient "mu" "cl");;
        Break
      else
        let: "data" := struct.get grove_ffi.ReceiveRet "Data" "r" in
        let: "d" := marshal.NewDec "data" in
        let: "seqno" := marshal.Dec__GetInt "d" in
        let: "replyLen" := marshal.Dec__GetInt "d" in
        let: "reply" := marshal.Dec__GetBytes "d" "replyLen" in
        lock.acquire (struct.loadF RPCClient "mu" "cl");;
        let: ("cb", "ok") := MapGet (struct.loadF RPCClient "pending" "cl") "seqno" in
        (if: "ok"
        then
          MapDelete (struct.loadF RPCClient "pending" "cl") "seqno";;
          struct.loadF callback "reply" "cb" <-[slice.T byteT] "reply";;
          struct.loadF callback "state" "cb" <-[uint64T] callbackStateDone;;
          lock.condSignal (struct.loadF callback "cond" "cb")
        else #());;
        lock.release (struct.loadF RPCClient "mu" "cl");;
        Continue));;
    #().

Definition MakeRPCClient: val :=
  rec: "MakeRPCClient" "host_name" :=
    let: "host" := "host_name" in
    let: "a" := grove_ffi.Connect "host" in
    control.impl.Assume (~ (struct.get grove_ffi.ConnectRet "Err" "a"));;
    let: "cl" := struct.new RPCClient [
      "conn" ::= struct.get grove_ffi.ConnectRet "Connection" "a";
      "mu" ::= lock.new #();
      "seq" ::= #1;
      "pending" ::= NewMap (struct.ptrT callback) #()
    ] in
    Fork (RPCClient__replyThread "cl");;
    "cl".

Definition ErrTimeout : expr := #1.

Definition ErrDisconnect : expr := #2.

Definition RPCClient__Call: val :=
  rec: "RPCClient__Call" "cl" "rpcid" "args" "reply" "timeout_ms" :=
    let: "reply_buf" := ref (zero_val (slice.T byteT)) in
    let: "cb" := struct.new callback [
      "reply" ::= "reply_buf";
      "state" ::= ref (zero_val uint64T);
      "cond" ::= lock.newCond (struct.loadF RPCClient "mu" "cl")
    ] in
    struct.loadF callback "state" "cb" <-[uint64T] callbackStateWaiting;;
    lock.acquire (struct.loadF RPCClient "mu" "cl");;
    let: "seqno" := struct.loadF RPCClient "seq" "cl" in
    struct.storeF RPCClient "seq" "cl" (std.SumAssumeNoOverflow (struct.loadF RPCClient "seq" "cl") #1);;
    MapInsert (struct.loadF RPCClient "pending" "cl") "seqno" "cb";;
    lock.release (struct.loadF RPCClient "mu" "cl");;
    let: "num_bytes" := std.SumAssumeNoOverflow (#8 + #8 + #8) (slice.len "args") in
    let: "e" := marshal.NewEnc "num_bytes" in
    marshal.Enc__PutInt "e" "rpcid";;
    marshal.Enc__PutInt "e" "seqno";;
    marshal.Enc__PutInt "e" (slice.len "args");;
    marshal.Enc__PutBytes "e" "args";;
    let: "reqData" := marshal.Enc__Finish "e" in
    (if: grove_ffi.Send (struct.loadF RPCClient "conn" "cl") "reqData"
    then ErrDisconnect
    else
      lock.acquire (struct.loadF RPCClient "mu" "cl");;
      (if: (![uint64T] (struct.loadF callback "state" "cb") = callbackStateWaiting)
      then lock.condWaitTimeout (struct.loadF callback "cond" "cb") "timeout_ms"
      else #());;
      let: "state" := ![uint64T] (struct.loadF callback "state" "cb") in
      (if: ("state" = callbackStateDone)
      then
        "reply" <-[slice.T byteT] ![slice.T byteT] "reply_buf";;
        lock.release (struct.loadF RPCClient "mu" "cl");;
        #0
      else
        lock.release (struct.loadF RPCClient "mu" "cl");;
        (if: ("state" = callbackStateAborted)
        then ErrDisconnect
        else ErrTimeout))).
