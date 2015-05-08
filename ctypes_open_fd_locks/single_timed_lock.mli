module FDL = Openfdlocks.OpenFDLocks
module Single_Timed_Lock :
  sig
    val exclusive_hold : Core.Std.Unix.File_descr.t -> unit
    val exec : arg:string -> unit
    val command : Core.Std.Command.t
  end
