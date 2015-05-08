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
module Single_Timed_Lock = struct
  let exclusive_hold (fd:Core.Std.Unix.File_descr.t) =
    let r = FDL.acquireLock (Core.Std.Unix.File_descr.to_int fd) in
    if ((Ctypes.ptr_compare (Ctypes.to_voidp r)(Ctypes.to_voidp Ctypes.null)) <> 0) then
      let sp = Core.Std.Time.Span.of_int_sec 10 in
      let _ = Core.Std.Time.pause sp in 
      let _ = FDL.releaseLock r (Core.Std.Unix.File_descr.to_int fd) in ()
    else
      let p = string_of_int (Core.Std.Pid.to_int (getpid ())) in
      printf "\nError. Call to acquire lock failed in thread %s" p;;

  let exec ~arg =
    let _  = with_file ~perm:0o600 ~mode:[O_CREAT;O_RDWR] arg ~f:(exclusive_hold) in ();;

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
		  
