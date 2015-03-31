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
open Core.Std
module Flock : sig 
  type t
  val create string -> t
  val acquire t -> bool
  val release t -> unit
end = struct
  type t = { pid:string; acquired_dt:Core.Std.Time.t; path:string};;
  let idendtt t1 t2 =
    if (((String.compare t1.pid t2.pid) <>0) ||
	  ((String.compare t1.acquired_dt t2.acquired_dt) <>0) ||
	    ((String.compare t1.path t2.path) <>0)) then
      false
    else
      true
  type lock_status =
    | Locked
    | Unlocked;;
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
    
    (*Serialize / deserialize current time with: 
        Core.Std.Time.to_string_fix_proto `Utc t
        Core.Std.Time.to_string_fix_proto `Utc t
     *)

  (*internal use only*)
  type lock { path:string; status:lock_status }
  let create apath =
    { path:apath; status:Unlocked }
  let acquire alockstruct =
    let open Unix in
    let open Flock_j in
    let newt = { pid:thepid; acquired_dt:"serializets"; path:alockstruct.apath } in
    let f fd =
      let thepid = getpid () in
      let serialized = string_of_t newt in
      single_write fd serialized in
    let f2 fd =
      let thestats = stat alockstruct.path in
      let thesize = thestats.st_size in 
      let s = "" in
      let readback = read fd s thesize in s in
    try
      let _ = with_file ~perm:0o644 ~mode:[O_EXCL;O_CREATE;O_RDWR] alockstruct.apath f in
      let contents = with_file ~perm:0o644 ~mode:[O_EXCL;O_CREATE;O_RDWR] alockstruct.path f2 in
      let l = t_of_string contents in
      if (idendtt l newt) then true else false
    with
    | EACCES -> let _ = printf "Permission denied" in false
    | EAGAIN -> let _ = printf "Resource temporarily unavailable; try again" in false
    | EBADF -> let _ = printf "Bad file descriptor" in false
    | EBUSY -> let _ = printf "Resource unavailable" in false
    | EDEADLK -> let _ = printf "Resource deadlock would occur" in false
    | EEXIST -> let _ = printf "File exists" in false
    | EINVAL -> let _ = printf "Invalid argument" in false
    | EIO -> let _ = printf "" in ()                 (** Hardware I/O error *)
    | EISDIR -> let _ = printf "" in ()              (** Is a directory *)
    | EMFILE -> let _ = printf "" in ()              (** Too many open files by the process *)
    | ENAMETOOLONG -> let _ = printf "" in ()        (** Filename too long *)
    | ENFILE -> let _ = printf "" in ()              (** Too many open files in the system *)
    | ENODEV -> let _ = printf "" in ()              (** No such device *)
    | ENOENT -> let _ = printf "" in ()              (** No such file or directory *)
    | ENOLCK -> let _ = printf "" in ()              (** No locks available *)
    | ENOMEM -> let _ = printf "" in ()              (** Not enough memory *)
    | ENOSPC -> let _ = printf "" in ()              (** No space left on device *)
    | ENOSYS -> let _ = printf "" in ()              (** Function not supported *)
    | ENXIO -> let _ = printf "" in ()               (** No such device or address *)
    | EPERM -> let _ = printf "" in ()               (** Operation not permitted *)
    | EROFS -> let _ = printf "" in ()               (** Read-only file system *)
    | EUNKNOWNERR of int -> let _ = printf "" in ()
    | _ -> let _ = printf "" in ()
end 
