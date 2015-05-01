open Core.Std;;
open Async.Std;;
open Lib_openfd_ctypes;;
open Core.Std.Unix;;
module FDL = OpenFDLocks;;
module Testml = struct
  let filename = "foo";;
  let exclusive_write (i:int) (fd:Core.Std.Unix.File_descr.t) =
    let sofi = string_of_int i in
    (*Uses blocking call to fcntl...returns only when lock can be acquired*)
    let r = FDL.acquireLock (Core.Std.Unix.File_descr.to_int fd) in
    if (Ctypes.raw_address_of_ptr (Ctypes.to_voidp r) = (Ctypes.raw_address_of_ptr (Ctypes.to_voidp Ctypes.null))) then
      let _ = lseek fd Int64.zero SEEK_END in
      let _ = single_write fd ("\nTesting open fd locks i:" ^ sofi) in
      FDL.releaseLock r (Core.Std.Unix.File_descr.to_int fd);;
  let athread i () =
    with_file ~perm:0o600 ~mode:[O_CREAT;O_RDWR] filename ~f:(exclusive_write i);;
  
end
		  
