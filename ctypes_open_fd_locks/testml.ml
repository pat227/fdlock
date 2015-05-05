open Core.Std;;
(*
DO NOT use async here...want no interleaving of threads by async so we are 
assured interleaving is due to open file descriptor lock. AND use PARMAP
so we have > 1 thread contending for lock on > 1 cores.
open Async.Std;;
open Async_kernel;;
*)
open Lib_openfd_ctypes;;
open Core.Std.Unix;;
module FDL = OpenFDLocks;;
module Testml = struct
  let filename = "foo";;
  let exclusive_write i (fd:Core.Std.Unix.File_descr.t) =
    let r = FDL.acquireLock (Core.Std.Unix.File_descr.to_int fd) in
    if ((Ctypes.ptr_compare (Ctypes.to_voidp r)(Ctypes.to_voidp Ctypes.null)) = 0) then
      let sofi = string_of_int i in 
      let _ = lseek fd Int64.zero SEEK_END in
      let _ = single_write fd ("\nTesting open fd locks i:" ^ sofi) in
      let _ = FDL.releaseLock r (Core.Std.Unix.File_descr.to_int fd) in
      let sp = Core.Std.Time.Span.of_int_sec 1 in
      Core.Std.Time.pause sp
    else
      printf "Error. Call to acquire lock failed in thread";;
  let athread i () =
    let _  = with_file ~perm:0o600 ~mode:[O_CREAT;O_RDWR] filename ~f:(exclusive_write i) in ();;

  let exec () =
    let _ = Parmap.parfold ~ncores:2 (athread) (Parmap.A [|1;2;3|]) () in ();;

  let command = 
    let open Command.Spec in 
    Command.basic 
      ~summary:"Test a ctypes binding to open file descriptor locks in linux, under which locks are associated with open file descriptions, not with the process or thread obtaining the lock. Locks work across processes and even amongst threads within the same process."
      (empty)
      (fun () -> (exec ()));;

  let () = Command.run command;;
end
		  
