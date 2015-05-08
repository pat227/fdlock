open Core.Std
open Flock
open Flock_t
module F = Flock
module TestLock = struct
  let exec ~arg1 ~(arg2:int option) =
    (*let path = arg1 List.nth_exn args 0 in*)
    let alock = F.create arg1 in
    let leaselength = arg2 (*List.nth_exn args 1 in*) in
    let _ = printf "\nCreated lock..." in
    if (F.acquire alock leaselength)
    then
      printf "\nAcquired the lock at %s" alock.path
	     (* WORKS: let _ = F.release alock in printf "\nReleased the lock." *)
	     (* WORKS: if (F.acquire alock) then printf "Acquired our lock 2nd time...OK" else printf "Failed to acquire own lock 2nd time." *)
    else
      (*WORKS if lock present with another pid*)
      printf "\nFailed to acquire the lock at %s" alock.path
	     
  let command = 
    let open Core.Std.Command.Spec in 
    Core.Std.Command.basic 
      ~summary:"Test a rudimentary lock file implementation safe for use over buggy or old nfs mounts."
      (empty 
       +> flag "-lockfile-path" (required string) ~doc:"The path of the lock file."
       +> flag "-lease-seconds" (optional int) ~doc:("Optional: the lease time of each lock beyond which we" ^
						       " can assume the lock is free. Assumed to be infinite if not specified.")
      )
      (fun arg1 arg2 () -> (exec ~arg1 ~arg2));;
      
  let () = Command.run command;;
end 
