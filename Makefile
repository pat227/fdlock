WARN_FLAGS =-w A-4-33-39-40-41-42-43-34-44-45
all:	prog
#flock_t.mli: 
#	atdgen -t flock.atd
#flock_j.mli:
#	atdgen -j flock.atd
#flock_t.cmi:	flock_t.mli
#	ocamlfind ocamlc -g -c flock_t.mli -package atdgen
#flock_j.cmi:	flock_j.mli
#	ocamlfind ocamlc -g -c flock_j.mli -package atdgen
#flock_j.cmo:	flock_t.mli flock_j.mli flock_j.cmi
#	ocamlfind ocamlc -g -c flock_j.ml -package atdgen
#flock_t.cmo:	flock_j.mli flock_t.mli flock_t.cmi 
#	ocamlfind ocamlc -g -c flock_t.ml -package atdgen
flock.cmi:	flock.mli
	ocamlfind ocamlc -g -c $(WARN_FLAGS) -principal -thread -safe-string -package core,yojson,ppx_deriving,ppx_deriving.show,ppx_deriving_yojson flock.mli
flock.cmo:	flock.ml flock.cmi
	ocamlfind ocamlc -c -g $(WARN_FLAGS) -principal -thread -safe-string -package core,yojson,ppx_deriving,ppx_deriving.show,ppx_deriving_yojson flock.ml
testlock.cmo:	flock.cmi flock.cmo
	ocamlfind ocamlc -c -g $(WARN_FLAGS) -principal -thread -safe-string -package core,yojson,ppx_deriving,ppx_deriving.show,ppx_deriving_yojson testlock.ml
prog:	testlock.cmo flock.cmo
	ocamlfind ocamlc -g $(WARN_FLAGS) -principal -thread -safe-string -linkpkg -package core,yojson,ppx_deriving,ppx_deriving.show,ppx_deriving_yojson flock.cmo testlock.cmo
tests:	all
	ocamlfind ocamlc -g $(WARN_FLAGS) -principal -thread -safe-string -linkpkg -package core,yojson,ppx_deriving,ppx_deriving.show,ppx_deriving_yojson flock.cmo unit_test_flock.ml -o tests
clean:
	rm *.cm?; rm *.o; rm flock_?.mli; rm flock_?.ml; rm a.out; rm tests a.out
