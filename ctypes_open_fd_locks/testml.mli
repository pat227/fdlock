module FDL = Openfdlocks.OpenFDLocks
module Testml :
  sig
    (*val filename : string*)
    val exclusive_write : int -> Core.Std.Unix.File_descr.t -> unit
    val athread : string -> int -> 'a -> int
    val exec : arg:string -> unit
    val command : Core.Std.Command.t
  end
