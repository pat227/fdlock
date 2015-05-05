open Core.Std;;
open Async.Std;;
open Async_kernel;;
open Lib_openfd_ctypes;;
open Core.Std.Unix;;
module FDL = OpenFDLocks;;
module Testml = struct
  let filename = "foo";;
  let exclusive_write i (fd:Core.Std.Unix.File_descr.t) =
    let sofi = string_of_int i in
    let r = FDL.acquireLock (Core.Std.Unix.File_descr.to_int fd) in
    if ((Ctypes.ptr_compare (Ctypes.to_voidp r)(Ctypes.to_voidp Ctypes.null)) = 0) then
      let _ = lseek fd Int64.zero SEEK_END in
      let _ = single_write fd ("\nTesting open fd locks i:" ^ sofi) in
      let _ = FDL.releaseLock r (Core.Std.Unix.File_descr.to_int fd) in
      let sp = Core.Std.Time.Span.of_int_sec 1 in
      Core.Std.Time.pause sp
    else
      printf "Error. Call to acquire lock failed in thread %d" i;;
  let athread i () =
    with_file ~perm:0o600 ~mode:[O_CREAT;O_RDWR] filename ~f:(exclusive_write i);;

  (*====TODO====
      Use: [all ts] returns a deferred that becomes determined when every t in ts
      is determined.  The output is in the same order as the input.
      val all : 'a t list -> 'a list t
   *)
  let exec () =
    Deferred.return ();;

  let command = 
    let open Async_extra.Command.Spec in 
    Async_extra.Command.async 
      ~summary:"Test a ctypes binding to open file descriptor locks in linux, under which locks are associated with open file descriptions, not with the process or thread obtaining the lock. Locks work across processes and even amongst threads within the same process."
      (empty)
      (fun () -> (exec ()));;

  let () = Command.run command;;
end
		  
