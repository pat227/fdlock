open Core.Std;;
(*
DO NOT use async here...want no interleaving of threads by async so we are 
assured interleaving is due to open file descriptor lock. AND use PARMAP
so we have > 1 thread contending for lock on > 1 cores.
open Async.Std;;
open Async_kernel;;
*)
open Core.Std.Unix;;
module FDL = Openfdlocks.OpenFDLocks;;
module Testml = struct
  let exclusive_write i (fd:Core.Std.Unix.File_descr.t) =
    let r = FDL.acquireLock (Core.Std.Unix.File_descr.to_int fd) in
    let sofi = string_of_int i in 
    if ((Ctypes.ptr_compare (Ctypes.to_voidp r)(Ctypes.to_voidp Ctypes.null)) <> 0) then
      let _ = lseek fd Int64.zero SEEK_END in
      let _ = single_write fd ("\nTesting open fd locks i:" ^ sofi ^ " within pid:" ^ (string_of_int (Pid.to_int (getpid ())))) in
      let _ = FDL.releaseLock r (Core.Std.Unix.File_descr.to_int fd) in 
      let sp = Core.Std.Time.Span.of_int_sec 1 in
	  Core.Std.Time.pause sp
    else
      printf "\nError. Call to acquire lock failed in thread %s" sofi;;

  let athread fname i i2 =
    let _  = with_file ~perm:0o600 ~mode:[O_CREAT;O_RDWR] fname ~f:(exclusive_write i) in 1;;

  let exec ~arg =
    let _ = Parmap.parfold ~ncores:2 (athread arg) (Parmap.A [|1;2;3;4;5;6;7;8;9;10|]) 0 (fun x y -> x + y) in ();;

  let command = 
    let open Core.Std.Command.Spec in 
    Command.basic 
      ~summary:"Test a ctypes binding to open file descriptor locks in linux, under which locks are associated with open file descriptions, not with the process or thread obtaining the lock. Locks work across processes and even amongst threads within the same process."
      (empty
	 +> flag "-lockfile-path" (required string) ~doc:"The path of the lock file."
      )
      (fun arg () -> (exec ~arg));;

    let () = Command.run command;;
end
		  
