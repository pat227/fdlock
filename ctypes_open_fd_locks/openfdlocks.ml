open Ctypes;;
open Unsigned;;
open Signed;;
module OpenFDLocks = struct
  type flock64;;
  let flock64 : flock64 structure typ = structure "flock64";;
  let l_type = field flock64 "l_type" short;;
  let l_whence = field flock64 "l_whence" short;;
  let l_start = field flock64 "l_start" int64_t;;
  let l_len = field flock64 "l_len" int64_t;;
  let l_pid = field flock64 "l_pid" int;;
  let () = seal flock64;;
  (* Actual struct:
struct flock64 {
	short  l_type;
	short  l_whence;
	__kernel_loff_t l_start;
	__kernel_loff_t l_len;
	__kernel_pid_t  l_pid;
	__ARCH_FLOCK64_PAD
};
   *)
  let openfdlockdl = Dl.dlopen ~filename:"/home/paul/Documents/ocaml/flock/ctypes_open_fd_locks/lib_openfd_lock.so.0" ~flags:[Dl.RTLD_LAZY];;
  let acquireLock = Foreign.foreign ~from:openfdlockdl "acquireLock" (int @-> returning (ptr flock64));;
  let releaseLock = Foreign.foreign ~from:openfdlockdl "releaseLock" (ptr flock64 @-> int @-> returning void);;
end
