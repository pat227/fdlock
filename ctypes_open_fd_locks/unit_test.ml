open OUnit
open Core.Std;;
(*
DO NOT use async here...want no interleaving of threads by async so we are 
assured interleaving is due to open file descriptor lock. AND use PARMAP
so we have > 1 thread contending for lock on > 1 cores.
*)
open Core.Std.Unix;;
module FDL = Openfdlocks.OpenFDLocks;;
module Unit_Test = struct
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

  let check_linecount_and_ids fname =
    let open In_channel in
    let open Pcre in 
    let tryparsei aline =
      (*find i:x and parse the x as int*)
      let _ = printf "\nprocessing a line: %s " aline in
      let regexp_pattern = regexp "i:[0-9][0-9]?" in
      let result_exn = Pcre.pcre_exec ~rex:regexp_pattern aline in
      let startslice = result_exn.(0) + 2 in
      let endslice = result_exn.(1) in
      let x = String.slice aline startslice endslice in
      int_of_string x in
    let inchan = create ?binary:(Some false) fname in
    let lines = input_lines inchan in
    let rec getNums (accum:int list) l =
      match l with
	[] -> accum
      | h :: t -> if String.length h > 0 then
		    let nxt = tryparsei h in
		    getNums (nxt::accum) t
		  else
		    getNums accum t in
    let check_completeness l1 l2 =
      let rec makeAssocList l1 (accum:(int * bool) list) =
	match l1, accum with
	  h :: t, [] -> let element = [(h, false)] in
			makeAssocList t element
	| h :: t, h2 :: t2 -> let al = List.Assoc.add accum h false in
			      makeAssocList t al
	| [], _ -> accum in 
      let rec docheck l1 l2 =
	match l1 with
	  [] -> let r = List.fold l2 ~f:(fun y x -> if (snd x) && y then true else false) ~init:true in
		if r then
		  let _ = printf "\nFolded true." in r else
		  let _ = printf "\nFolded false." in r
	| h :: t -> if List.Assoc.mem l2 h then
		      let _ = List.Assoc.remove l2 h in
		      let lc = List.Assoc.add l2 h true in
		      docheck t lc
		    else
		      let _ = printf "\nFailed in docheck with h:%d" h in
		      false in
      let tobechecked = makeAssocList l2 [] in
      docheck l1 tobechecked in
    let nums = getNums [] lines in
    check_completeness [1;2;3;4;5;6;7;8;9;10] nums;;
      
          
  let test_suite_one = "openfd_locking_tests" >:::
			 [
			   "Should see perfect interleaving of writes, no missing lines, no gibberish, etc."
			   >:: ( fun () -> 
				 assert_equal true (exec "foo2";check_linecount_and_ids "foo2")
			       );
			 ]
  let _ = run_test_tt (*?verbose:(Some true)*) test_suite_one
end
		  
