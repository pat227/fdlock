open Ctypes;;
open Unsigned;;
open Signed;;
module OpenFDLocks :
  sig
    type flock64
    val flock64 : flock64 Ctypes.structure Ctypes.typ
    (*val openfdlockdl : Dl.library*)
    val acquireLock : int -> flock64 Ctypes.structure Ctypes_static.ptr
    val releaseLock : flock64 Ctypes.structure Ctypes_static.ptr -> int -> unit
  end
