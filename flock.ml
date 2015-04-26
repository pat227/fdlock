(*
http://0pointer.de/blog/projects/locking.html
It's amazing how far Linux has come without providing for proper file locking that works and is usable from userspace. A little overview why file locking is still in a very sad state:

To begin with, there's a plethora of APIs, and all of them are awful:

POSIX File locking as available with fcntl(F_SET_LK): the POSIX locking API is the most portable one and in theory works across NFS. It can do byte-range locking. So much on the good side. On the bad side there's a lot more however: locks are bound to processes, not file descriptors. That means that this logic cannot be used in threaded environments unless combined with a process-local mutex. This is hard to get right, especially in libraries that do not know the environment they are run in, i.e. whether they are used in threaded environments or not. The worst part however is that POSIX locks are automatically released if a process calls close() on any (!) of its open file descriptors for that file. That means that when one part of a program locks a file and another by coincidence accesses it too for a short time, the first part's lock will be broken and it won't be notified about that. Modern software tends to load big frameworks (such as Gtk+ or Qt) into memory as well as arbitrary modules via mechanisms such as NSS, PAM, gvfs, GTK_MODULES, Apache modules, GStreamer modules where one module seldom can control what another module in the same process does or accesses. The effect of this is that POSIX locks are unusable in any non-trivial program where it cannot be ensured that a file that is locked is never accessed by any other part of the process at the same time. Example: a user managing daemon wants to write /etc/passwd and locks the file for that. At the same time in another thread (or from a stack frame further down) something calls getpwuid() which internally accesses /etc/passwd and causes the lock to be released, the first thread (or stack frame) not knowing that. Furthermore should two threads use the locking fcntl()s on the same file they will interfere with each other's locks and reset the locking ranges and flags of each other. On top of that locking cannot be used on any file that is publicly accessible (i.e. has the R bit set for groups/others, i.e. more access bits on than 0600), because that would otherwise effectively give arbitrary users a way to indefinitely block execution of any process (regardless of the UID it is running under) that wants to access and lock the file. This is generally not an acceptable security risk. Finally, while POSIX file locks are supposedly NFS-safe they not always really are as there are still many NFS implementations around where locking is not properly implemented, and NFS tends to be used in heterogenous networks. The biggest problem about this is that there is no way to properly detect whether file locking works on a specific NFS mount (or any mount) or not.
The other API for POSIX file locks: lockf() is another API for the same mechanism and suffers by the same problems. One wonders why there are two APIs for the same messed up interface.
BSD locking based on flock(). The semantics of this kind of locking are much nicer than for POSIX locking: locks are bound to file descriptors, not processes. This kind of locking can hence be used safely between threads and can even be inherited across fork() and exec(). Locks are only automatically broken on the close() call for the one file descriptor they were created with (or the last duplicate of it). On the other hand this kind of locking does not offer byte-range locking and suffers by the same security problems as POSIX locking, and works on even less cases on NFS than POSIX locking (i.e. on BSD and Linux < 2.6.12 they were NOPs returning success). And since BSD locking is not as portable as POSIX locking this is sometimes an unsafe choice. Some OSes even find it funny to make flock() and fcntl(F_SET_LK) control the same locks. Linux treats them independently -- except for the cases where it doesn't: on Linux NFS they are transparently converted to POSIX locks, too now. What a chaos!
Mandatory locking is available too. It's based on the POSIX locking API but not portable in itself. It's dangerous business and should generally be avoided in cleanly written software.
Traditional lock file based file locking. This is how things where done traditionally, based around known atomicity guarantees of certain basic file system operations. It's a cumbersome thing, and requires polling of the file system to get notifications when a lock is released. Also, On Linux NFS < 2.6.5 it doesn't work properly, since O_EXCL isn't atomic there. And of course the client cannot really know what the server is running, so again this brokeness is not detectable.
=========>FROM POSIX: If O_CREAT and O_EXCL are set, open() shall fail if the file exists. The check for the existence of the file and the creation of the file if it does not exist shall be atomic with respect to other threads executing open() naming the same filename in the same directory with O_EXCL and O_CREAT set. If O_EXCL and O_CREAT are set, and path names a symbolic link, open() shall fail and set errno to [EEXIST], regardless of the contents of the symbolic link. If O_EXCL is set and O_CREAT is not set, the result is undefined.
========>An implementation of traditional file locking does not have to depend on the atomicity of O_EXCL: require each process / thread attempting to acquire a lock to not only attempt detection of the lock, followed by creation if it does not exist, but also after creation of the lock to write to it with process / thread specific data followed by a reading of that data back to verify success and exclusivity. A cooperating process / thread that finds someone else's data in the lock must respect that lock and consider itself as having "lost" for contention of the lock.
 *)

(*===ANOTHER IDEA====when private file locks are available, write ctypes ocaml code for some c-code that invokes privat file locks====
Although private file locks, like flocks, are local. This code seeks to be old school file locking and not local...should work across
different OS's and mounts across networks and file systems.
 *)

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
  (*Internal use only*)
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
      let _ = printf " uniquename: %s " uniquename in
      let _ = link ~force:true ~target:alockstruct.path ~link_name:uniquename () in
      let thestats = fstat fd in
      match thestats.st_nlink with
      |	2 -> let _ = unlink uniquename in
	     let serialized = string_of_t newt in   
	     let _ = printf "\nAcquiring...serialized: %s" serialized in
	     single_write fd ~buf:serialized
      | _ -> let _ = printf "ERROR 85 links:%d" thestats.st_nlink in
	     raise MyEExist in
    let readback_verify fd = 
      let thestats = fstat fd in
      let thesize = (Int64.to_int (thestats.st_size)) in
      match thesize with
	Some size -> let s = (String.create size) in
		     let _ = printf "\nAcquiring ... size: %d" size in 
		     let _ = read fd ~buf:s ~len:size in s
      | None -> let _ = printf "ERROR 92" in
		raise Impossible_lock2large in
    let readback_verify_truncate_update fd =
      let thestats = fstat fd in
      let thesize = (Int64.to_int (thestats.st_size)) in 
      match thesize with
      | Some size -> let s = (String.create size) in
		     let _ = read fd ~buf:s ~len:size in
		     let _ = printf "\nRead: %s " s in
		     let l = t_of_string s in
		     if (l.pid = newt.pid) then (*update time of acquisition*)
		       let serialized = string_of_t newt in
		       let _ = printf "\nWriting %s" serialized in
		       let _ = single_write fd serialized in
		       let _ = ftruncate fd (Int64.of_int (Core.Std.String.length serialized)) in
		       true
		     else (*check if lock can be considered expired and take it if so*)
		       (match leaseseconds with
			  Some ls -> let nowtime = Core.Std.Time.now () in
				     let age = Core.Std.Time.diff nowtime (Core.Std.Time.of_string_fix_proto `Utc l.acquired_dt) in
				     let age_seconds = Core.Std.Time.Span.to_sec age in
				     let _ = printf "\nAge of existing lock in secs: %f" age_seconds in
				     if((Float.to_int age_seconds) >= ls)
				     then (*lock is ours*)
				       let _ = printf "\nAge of existing lock exceeds max lease life %d ; acquiring lock" ls in
				       let serialized = string_of_t newt in
				       let _ = single_write fd serialized in
				       let _ = ftruncate fd (Int64.of_int (Core.Std.String.length serialized)) in 
				       true
				     else (*lock lease still valid...not ours*)
				       let _ = printf "\nAge of existing lock less than max lease" in
				       false
			| None -> let _ = printf "\nLock lease still valid..." in false)
      | None -> raise Impossible_lock2large in
    try 
      let r = access alockstruct.path [`Read;`Write;`Exists] in
      match r with
      | Error _ -> let _ = with_file ~perm:0o600 ~mode:[O_EXCL;O_CREAT;O_RDWR]
				     alockstruct.path ~f:create_and_write in
		   let readback = with_file ~perm:0o600 ~mode:[O_RDWR]
					    alockstruct.path ~f:readback_verify in
		   let _ = printf "\nAcquiring...readback: %s" readback in
		   let l = t_of_string readback in
		   if (idendtt l newt) then true else false
      | Ok () -> with_file ~perm:0o600 ~mode:[O_RDWR] alockstruct.path
			   ~f:readback_verify_truncate_update
    with
    | MyEExist -> let _ = printf "\nFile exists...reading it see if it belongs to us..." in
		  let attempt_on_existinglock =
		    with_file ~perm:0o600 ~mode:[O_RDWR] alockstruct.path
			      ~f:readback_verify_truncate_update in
		  if attempt_on_existinglock then true else false
    | Impossible_lock2large -> let _ = printf "\nLock file size too large for int type. U R SOL." in false
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
    | Ok () -> let _ = printf "\nReleasing lock file, it exists...confirm it belongs to us first" in
	       let is_it_ours = with_file ~perm:0o600 ~mode:[O_RDWR]
					  alockstruct.path ~f:(readback_verify) in
	       if is_it_ours then
		 let _ = remove alockstruct.path in true
	       else
		 false
    | Error _ -> let _ = printf "Could not release lock!" in false;;

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






  (*Attempt openfile : ?perm:file_perm -> mode:open_flag list -> string -> File_descr.t
      With error ENOENT, try to create and write t's data serialized as json, with 
      with EROFS throw error b/c impossible to lock on ro fs, 
      with EACCES I think that means file exists if we try to open with the O_EXCL open flag.
USE: O_RDWR O_CREAT  O_EXCL
cover these:
    | EACCES              (** Permission denied *)
    | EAGAIN              (** Resource temporarily unavailable; try again *)
    | EBADF               (** Bad file descriptor *)
    | EBUSY               (** Resource unavailable *)
    | EDEADLK             (** Resource deadlock would occur *)
    | EEXIST              (** File exists *)
    | EINVAL              (** Invalid argument *)
    | EIO                 (** Hardware I/O error *)
    | EISDIR              (** Is a directory *)
    | EMFILE              (** Too many open files by the process *)
    | ENAMETOOLONG        (** Filename too long *)
    | ENFILE              (** Too many open files in the system *)
    | ENODEV              (** No such device *)
    | ENOENT              (** No such file or directory *)
    | ENOLCK              (** No locks available *)
    | ENOMEM              (** Not enough memory *)
    | ENOSPC              (** No space left on device *)
    | ENOSYS              (** Function not supported *)
    | ENXIO               (** No such device or address *)
    | EPERM               (** Operation not permitted *)
    | EROFS               (** Read-only file system *)
    | EUNKNOWNERR of int
   *)
    (*| EEXIST -> 
    | EACCES -> let _ = printf "\nPermission denied" in false
    | EAGAIN -> let _ = printf "\nResource temporarily unavailable; try again" in false
    | EBADF -> let _ = printf "\nBad file descriptor" in false
    | EBUSY -> let _ = printf "\nResource unavailable" in false
    | EDEADLK -> let _ = printf "\nResource deadlock would occur" in false

    | EINVAL -> let _ = printf "\nInvalid argument" in false
    | EIO -> let _ = printf "\nHardware I/O error" in false
    | EISDIR -> let _ = printf "\nIs a directory" in false
    | EMFILE -> let _ = printf "\nToo many open files by the process" in ()
    | ENAMETOOLONG -> let _ = printf "\nFilename too long" in false
    | ENFILE -> let _ = printf "\nToo many open files in the system" in false
    | ENODEV -> let _ = printf "\nNo such device" in false
    | ENOENT -> let _ = printf "\nNo such file or directory" in false
    | ENOLCK -> let _ = printf "\nNo locks available" in false
    | ENOMEM -> let _ = printf "\nNot enough memory" in false
    | ENOSPC -> let _ = printf "\nNo space left on device" in false
    | ENOSYS -> let _ = printf "\nFunction not supported" in false
    | ENXIO -> let _ = printf "\nNo such device or address" in false
    | EPERM -> let _ = printf "\nOperation not permitted" in false
    | EROFS -> let _ = printf "\nRead-only file system" in false
    | EUNKNOWNERR int -> let _ = printf "\nUnknown error" in false
    | _ -> let _ = printf "\nReally unknown error" in false *)
