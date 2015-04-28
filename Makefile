flock_t.mli: 
	atdgen -t flock.atd
flock_j.mli:
	atdgen -j flock.atd
flock_t.cmi:	flock_t.mli
	ocamlfind ocamlc -g -c flock_t.mli -package atdgen
flock_j.cmi:	flock_j.mli
	ocamlfind ocamlc -g -c flock_j.mli -package atdgen
flock_j.cmo:	flock_t.mli flock_j.mli flock_j.cmi
	ocamlfind ocamlc -g -c flock_j.ml -package atdgen
flock_t.cmo:	flock_j.mli flock_t.mli flock_t.cmi 
	ocamlfind ocamlc -g -c flock_t.ml -package atdgen
flocksig.cmi:	flocksig.mli
	ocamlfind ocamlc -g -c -principal -thread flocksig.mli
flock.cmo:	flock_t.mli flock_j.mli flock_t.cmi flock_j.cmi flock_t.cmo flocksig.cmi  
	ocamlfind ocamlc -c -g -principal -thread -package core,yojson flock.ml
testlock.cmo:	flock_t.mli flock_j.mli flock_t.cmi flock_j.cmi flock_t.cmo flocksig.cmi flock.cmo
	ocamlfind ocamlc -c -g -principal -thread -package core,yojson testlock.ml
all:	testlock.cmo flock.cmo flock_j.cmo flock_t.cmo
	ocamlfind ocamlc -g -principal -thread -linkpkg -package atdgen,yojson,core flock_t.mli flock_j.mli flock_t.cmo flock_j.cmo flock.cmo testlock.cmo
tests:	all
	ocamlfind ocamlc -g -principal -thread -linkpkg -package atdgen,yojson,core flock_t.mli flock_j.mli flock_t.cmo flock_j.cmo flock.cmo unit_test_flock.ml -o tests
clean:
	rm *.cm?; rm *.o; rm flock_?.mli; rm flock_?.ml; rm a.out; rm tests
