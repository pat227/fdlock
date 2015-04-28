(*Inspired by https://github.com/markedup-mobi/file-lock
NOTE on NFS: http://www.time-travellers.org/shane/papers/NFS_considered_harmful.html
The solution for performing atomic file locking using a lockfile is to create a unique file on the same fs (e.g., incorporating hostname and pid), use link(2) to make a link to the lockfile and use stat(2) on the unique file to check if its link count has increased to 2. Do not use the return value of the link() call.
*)
open Flocksig
open Flock_t
module Flock : Flocksig = struct
  (*The status field is misleading since will only be Locked if present on disk, else file is deleted upon release.
    type t = { pid:int; localhostname:string; acquired_dt:string(of Core.Std.Time.t); path:string; status:string};;
   *)
  include Flock_t
  let idendtt t1 t2 =
    let open Core.Std in
    let time1 = Time.of_string_fix_proto `Utc  t1.acquired_dt in
    let time2 = Time.of_string_fix_proto `Utc  t2.acquired_dt in
    if ((t1.pid <> t2.pid) || (t1.localhostname <> t2.localhostname) ||
	  ((Time.compare time1 time2) <>0) ||
	    ((String.compare t1.path t2.path) <>0)) then
      false
    else
      true;;
  exception Unrecognized_lock_state
  type lock_status =
    | Locked
    | Unlocked;;
  let string_of_lockstatus ls =
    match ls with
    | Locked -> "Locked"
    | Unlocked -> "Unlocked";;
  let lockstatus_of_string s =
    match s with
    | "Locked" -> Locked
    | "Unlocked" -> Unlocked
    | _ -> raise Unrecognized_lock_state
    
    (*Serialize / deserialize current time with: 
        Core.Std.Time.to_string_fix_proto `Utc t
        Core.Std.Time.of_string_fix_proto `Utc t
     *)
  exception MyEExist
  exception Impossible_lock2large
  (*lock_ for internal use only*)
  type lock_ = { path:string; status:lock_status };;
  let create_ apath = { path=apath; status=Unlocked };;
  let acquire_ (alockstruct:lock_) ?(leaseseconds=None) =
    let open Core.Std in 
    let open Core.Std.Unix in
    let open Flock_j in
    let thepid = getpid () in
    let thepid_asstring = Core.Std.Pid.to_string thepid in
    let newt = { pid=(int_of_string (thepid_asstring));
		 localhostname=gethostname ();
		 acquired_dt=(Core.Std.Time.to_string_fix_proto `Utc (Time.now ()));
		 path=alockstruct.path;
		 status="Locked" } in
    let create_and_write fd =
      (* Need to link again and count 2 links with fstat to ensure this works over 
         buggy or early NFS versions on which O_EXCL doesnt work, not atomic *)
      let _ = printf "\nAcquiring create_&_write " in
      let uniquename = (gethostname ()) ^ thepid_asstring in
      let _ = printf "\nUniquename33: %s " uniquename in
      let _ = link ~force:true ~target:alockstruct.path ~link_name:uniquename () in
      let thestats = fstat fd in
      match thestats.st_nlink with
      |	2 -> let _ = unlink uniquename in
	     let serialized = string_of_t newt in   
	     let _ = printf "\nAcquiring_40...serialized: %s" serialized in
	     single_write fd ~buf:serialized
      | _ -> let _ = printf "ERROR_85 links:%d" thestats.st_nlink in
	     raise MyEExist in
    let readback_verify fd = 
      let thestats = fstat fd in
      let thesize = (Int64.to_int (thestats.st_size)) in
      match thesize with
	Some size -> let s = (String.create size) in
		     let _ = printf "\nAcquiring_48 ... size: %d" size in 
		     let _ = read fd ~buf:s ~len:size in s
      | None -> let _ = printf "ERROR_92" in
		raise Impossible_lock2large in
    let readback_verify_truncate_update fd =
      let thestats = fstat fd in
      let thesize = (Int64.to_int (thestats.st_size)) in 
      match thesize with
      | Some size -> let s = (String.create size) in
		     let _ = read fd ~buf:s ~len:size in
		     let _ = printf "\nRead_86: %s " s in
		     let l = t_of_string s in
		     if (l.pid = newt.pid) then (*update time of acquisition*)
		       let serialized = string_of_t newt in
		       let _ = single_write fd serialized in
		       let _ = ftruncate fd (Int64.of_int (Core.Std.String.length serialized)) in
		       let _ = printf "\nPIDs match, wrote_90 %s" serialized in
		       true
		     else (*check if lock can be considered expired and take it if so*)
		       (match leaseseconds with
			  Some ls -> let nowtime = Core.Std.Time.now () in
				     let age = Core.Std.Time.diff nowtime (Core.Std.Time.of_string_fix_proto `Utc l.acquired_dt) in
				     let age_seconds = Core.Std.Time.Span.to_sec age in
				     let _ = printf "\n99_Age of existing lock in secs: %f" age_seconds in
				     if((Float.to_int age_seconds) >= ls)
				     then (*lock is ours*)
				       let serialized = string_of_t newt in
				       let _ = single_write fd serialized in
				       let _ = ftruncate fd (Int64.of_int (Core.Std.String.length serialized)) in
				       let _ = printf "\n102_Age of existing lock exceeds max lease life %d ; acquiring lock" ls in
				       true
				     else (*lock lease still valid...not ours*)
				       let _ = printf "\n108_Age of existing lock less than max lease" in
				       false
			| None -> let _ = printf "\n110_Lock lease still valid..." in false)
      | None -> raise Impossible_lock2large in
    try 
      let r = access alockstruct.path [`Read;`Write;`Exists] in
      match r with
      | Error _ -> let _ = with_file ~perm:0o600 ~mode:[O_EXCL;O_CREAT;O_RDWR]
				     alockstruct.path ~f:create_and_write in
		   let readback = with_file ~perm:0o600 ~mode:[O_RDWR]
					    alockstruct.path ~f:readback_verify in
		   let _ = printf "\n119_Acquiring...readback: %s" readback in
		   let l = t_of_string readback in
		   if (idendtt l newt) then true else false
      | Ok () -> with_file ~perm:0o600 ~mode:[O_RDWR] alockstruct.path
			   ~f:readback_verify_truncate_update
    with
    | MyEExist -> let _ = printf "\n125_File exists...reading it see if it belongs to us..." in
		  let attempt_on_existinglock =
		    with_file ~perm:0o600 ~mode:[O_RDWR] alockstruct.path
			      ~f:readback_verify_truncate_update in
		  if attempt_on_existinglock then true else false
    | Impossible_lock2large -> let _ = printf "\n130_Lock file size too large for int type. U R SOL." in false
  (*| _ -> let _ = printf "\nUnexpected error..." in false*)

  let release_ (alockstruct:lock_) =
    let open Core.Std in 
    let open Core.Std.Unix in
    let readback_verify fd =
      let open Flock_j in
      let thestats = fstat fd in
      let thesize = (Int64.to_int (thestats.st_size)) in 
      match thesize with
      | Some size -> let s = String.create size in
		     let _ = read fd ~buf:s ~len:size in
		     let l = t_of_string s in
		     if (l.pid = (Core.Std.Pid.to_int (Core.Std.Unix.getpid ()))) then true
		     else false
      | None -> raise Impossible_lock2large in
    let r = access alockstruct.path [`Read;`Write;`Exists] in
    match r with
    | Ok () -> let _ = printf "\n149_Releasing lock file, it exists...confirm it belongs to us first" in
	       let is_it_ours = with_file ~perm:0o600 ~mode:[O_RDWR]
					  alockstruct.path ~f:(readback_verify) in
	       if is_it_ours then
		 let _ = remove alockstruct.path in true
	       else
		 false
    | Error _ -> let _ = printf "156_Could not release lock!" in false;;

  let create thepath =
    let thepid = Core.Std.Unix.getpid () in
    let thepid_asint = Core.Std.Pid.to_int thepid in
    {
      pid = thepid_asint;
      localhostname = Core.Std.Unix.gethostname ();
      acquired_dt = "";
      path = thepath;
      status="Unlocked";
    };;

  let release (lockt:Flock_t.t) =
    let internallock = { path = lockt.path; status = Unlocked } in
    let _ = release_ internallock in ();;
  let acquire (lockt:Flock_t.t) leaseseconds =
    let internallock = { path = lockt.path; status = Unlocked } in
    acquire_ internallock ~leaseseconds;;
end
