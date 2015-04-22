flock_t.mli: 
	atdgen -t flock.atd
flock_j.mli:
	atdgen -j flock.atd
flock_t.cmi: flock_t.mli
	ocamlfind ocamlc -c flock_t.mli -package atdgen
flock_j.cmi: flock_j.mli
	ocamlfind ocamlc -c flock_j.mli -package atdgen
flock_j.cma: flock_t.mli flock_j.mli flock_t.cmi flock_j.cmi
	ocamlfind ocamlc -a flock_j.ml -package atdgen -o flock_j.cma
flocksig.cmi:	flocksig.mli
	ocamlfind ocamlc -c -principal -thread -I ./ -package core flocksig.mli
all:	flock_t.mli flock_j.mli flock_t.cmi flock_j.cmi flock_j.cma flocksig.cmi  
	ocamlfind ocamlc -principal -thread -I ./ -package core flocksig.mli flock.ml
clean:
	rm *.cm?; rm *.o; rm flock_?.mli; rm flock_?.ml
