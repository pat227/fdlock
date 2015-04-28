open OUnit
open Core.Std
open Flock
open Flock_t
open Flock_j
module F = Flock
module TestLock = struct
  let lockfilename = "mylock";;
  let dne_already fname =
    let open Core.Std.Unix in
    let r = access fname [`Read;`Write;`Exists] in
    match r with
    | Ok () -> false
    | Error _ -> true;;
  let alock = F.create lockfilename;;
  let leaselength = None;;
  let testAcquire_test1 fname =
    F.acquire (F.create fname) None;;
  let testAcquire fname lexp =
    F.acquire (F.create fname) lexp;;
  let cleanUp fname =
    try
      Core.Std.Unix.remove fname
    with
      _ -> ();;
  (*search for {"pid":"xxxx", and replace the xxxx with a new number  *)
  let alterPID_of_lock_on_disk lockpath newpid =
    let open Core.Std.Unix in
    let alterfile fd =
      let thestats = fstat fd in
      let thesize = (Int64.to_int (thestats.st_size)) in 
      match thesize with
      | Some size -> let s = (String.create size) in
		     let _ = read fd ~buf:s ~len:size in
		     let l = t_of_string s in
		     let l2 = { l with pid=newpid } in
		     let serialized = string_of_t l2 in
		     let _ = lseek fd (Int64.of_int 0) SEEK_SET in
		     let _ = single_write fd serialized in
		     (*let _ = ftruncate fd (Int64.of_int (Core.Std.String.length serialized)) in
		     let s = Core.Std.Time.Span.of_int_sec 1 in
		     let _  = Core.Std.Time.pause s in*)
		     let _ = printf "\nPID updated, wrote %s" serialized in
		     true
      | None -> false in
    let r = access lockpath [`Read;`Write;`Exists] in
    match r with
    | Error _ -> false
    | Ok () -> let _ = with_file ~perm:0o600 ~mode:[O_RDWR] lockpath ~f:alterfile in
	       let _ = printf "\nAltered pid of lock for testing purposes..." in
	       true
       
  let test_suite_one = "locking_tests" >:::
			 [
			   "Should acquire" >:: ( fun () -> 
						  assert_equal true (cleanUp lockfilename; testAcquire_test1 lockfilename)
						);
			   "Should acquire same lock again" >:: ( fun () -> 
								  assert_equal true (testAcquire_test1 lockfilename)
								);
			   "Should fail to acquire lock b/c of pid" >:: ( fun () -> 
									  assert_equal false (alterPID_of_lock_on_disk lockfilename 1; testAcquire_test1 lockfilename)
									);
			   "Should acquire lock b/c of lease expiration" >:: ( fun () -> 
									       assert_equal true (testAcquire lockfilename (Some(0)))
									     );
			 ]
  let _ = run_test_tt (*?verbose:(Some true)*) test_suite_one
end
