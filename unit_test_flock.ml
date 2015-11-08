open OUnit
open Core.Std
open Flock
module TestLock = struct
  let lockfilename = "mylock";;
  exception Testerror of string
  let dne_already fname =
    let open Core.Std.Unix in
    let r = access fname [`Read;`Write;`Exists] in
    match r with
    | Ok () -> false
    | Error _ -> true;;
  let alock = Flock.create lockfilename;;
  let leaselength = None;;
  let testAcquire_test1 fname =
    Flock.acquire (Flock.create fname) None;;
  let testAcquire fname lexp =
    Flock.acquire (Flock.create fname) lexp;;
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
		     let lopt = Flock.of_yojson (Yojson.Safe.from_string s) in
		     (match lopt with
		      | `Ok l -> 
			 let l2 = { l with pid=newpid } in
			 let serialized = Yojson.Safe.to_string (Flock.to_yojson l2) in
			 let _ = lseek fd (Int64.of_int 0) SEEK_SET in
			 let _ = single_write fd serialized in
			 let _ = ftruncate fd (Int64.of_int (Core.Std.String.length serialized)) in
  		         (*let s = Core.Std.Time.Span.of_int_sec 1 in
		         let _  = Core.Std.Time.pause s in*)
			 let _ = printf "\nPID updated, wrote %s" serialized in
			 true
		      | `Error s -> raise (Testerror "index 45, failed to marhsall json"))
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
