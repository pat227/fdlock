open Core.Std
open Flock
open Flock_t
module F = Flock
module TestLock = struct
  let exec ~args =
    let path = List.nth_exn args 0 in
    let alock = F.create path in
    let _ = printf "\nCreated lock..." in
    if (F.acquire alock)
    then
      printf "\nAcquired the lock at %s" alock.path
    else
      printf "\nFailed to acquire the lock at %s" alock.path
	     
  let command = 
    let open Core.Std.Command.Spec in 
    Core.Std.Command.basic 
      ~summary:"Test a rudimentary lock file implementation safe for use over buggy or old nfs mounts."
      (empty 
       +> flag "-lockfilepath" (required string) ~doc:"the path of the lock file")
      (fun arg1 () -> (exec ~args:[arg1]))
      
      (*  let () = Command.run command*)
end 
