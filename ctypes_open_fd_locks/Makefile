default:	all
clean:
	rm *.o *.so* *.cmi *.cmo *.annot tests helloworld timedlock unit_tests
all:	lib_openfd_lock.o lib_openfd_lock.so.0 lib_openfd_lock.so main.o main tests single_timed_lock unit_test
lib_openfd_lock.o:	lib_openfd_lock.c
	gcc -isystem /usr/include/asm-generic -isystem /user/include -pthread -fPIC -g -c -fvisibility=default -rdynamic -Werror -Wextra -lm lib_openfd_lock.c -olib_openfd_lock.o
lib_openfd_lock.so.0:	lib_openfd_lock.o
	gcc -isystem /usr/include/asm-generic -pthread -g -shared -fvisibility=default -rdynamic -Werror -Wextra -Wl,-E,--no-undefined,-soname,lib_openfd_lock.so.0 lib_openfd_lock.o -o lib_openfd_lock.so.0 -lc -lm
lib_openfd_lock.so:	lib_openfd_lock.o
	gcc -isystem /usr/include/asm-generic -pthread -g -shared -fvisibility=default -rdynamic -Werror -Wextra -Wl,-E,--no-undefined,-soname,lib_openfd_lock.so.0 lib_openfd_lock.o -o dlllib_openfd_lock.so -lc -lm
main.o:	test_lib.c
	gcc -isystem /usr/include/asm-generic -pthread -c test_lib.c -Werror -Wextra -omain.o
main:	main.o lib_openfd_lock.so.0
	gcc -isystem /usr/include/asm-generic -pthread -g -Wextra -Werror -ohelloworld main.o -L./ lib_openfd_lock.so.0 -lm -Wl,-rpath=./
openfdlocks.cmi:	openfdlocks.mli
	ocamlfind ocamlc -g -c -thread -principal -package core,ctypes,ctypes.foreign openfdlocks.mli
openfdlocks.cmo:	openfdlocks.ml
	ocamlfind ocamlc -g -c -thread -principal -dllib lib_openfd_lock -dllpath ./ -package core,ctypes,ctypes.foreign openfdlocks.ml
testml.cmo:	testml.ml openfdlocks.cmi openfdlocks.cmo testml.cmi
	ocamlfind ocamlc -g -c -thread -principal  -linkall -package core,parmap,ctypes,ctypes.foreign testml.ml
testml.cmi:	testml.mli
	ocamlfind ocamlc -g -c -thread -principal -package core,parmap,ctypes,ctypes.foreign testml.mli
tests:	testml.cmo openfdlocks.cmo openfdlocks.cmi testml.cmi
	ocamlfind ocamlc -g -thread -principal -linkpkg -package core,parmap,ctypes,ctypes.foreign openfdlocks.mli testml.mli openfdlocks.cmo testml.cmo -o tests
single_timed_lock.cmo:	single_timed_lock.ml
	ocamlfind ocamlc -g -c -thread -principal -package core,ctypes,ctypes.foreign single_timed_lock.ml
single_timed_lock.cmi:	single_timed_lock.ml
	ocamlfind ocamlc -g -c -thread -principal -package core,ctypes,ctypes.foreign single_timed_lock.mli
single_timed_lock:	single_timed_lock.cmi single_timed_lock.cmo
	ocamlfind ocamlc -g -thread -principal -linkpkg -package core,ctypes,ctypes.foreign openfdlocks.mli openfdlocks.cmo single_timed_lock.cmo -o timedlock
unit_test:	unit_test.ml openfdlocks.cmo
	ocamlfind ocamlc -g -thread -principal -linkpkg -package core,ctypes,ctypes.foreign,parmap,pcre openfdlocks.cmo unit_test.ml -o unit_tests
