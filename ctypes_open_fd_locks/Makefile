default:	all
clean:
	rm *.o *.so* *.cmi *.cmo
all:	lib_openfd_lock.o lib_openfd_lock.so.0 main.o main lib_openfd_ctypes.cmo
lib_openfd_lock.o:	lib_openfd_lock.c
	gcc -isystem /usr/include/asm-generic -pthread -fPIC -g -c -fvisibility=default -rdynamic -Werror -Wextra -lm lib_openfd_lock.c -olib_openfd_lock.o
lib_openfd_lock.so.0:	lib_openfd_lock.o
	gcc -isystem /usr/include/asm-generic -pthread -g -shared -fvisibility=default -rdynamic -Werror -Wextra -Wl,-E,--no-undefined,-soname,lib_openfd_lock.so.0 lib_openfd_lock.o -o lib_openfd_lock.so.0 -lc -lm
main.o:	test_lib.c
	gcc -isystem /usr/include/asm-generic -pthread -c test_lib.c -Werror -Wextra -omain.o
main:	main.o lib_openfd_lock.so.0
	gcc -isystem /usr/include/asm-generic -pthread -g -Wextra -Werror -ohelloworld main.o -L./ lib_openfd_lock.so.0 -lm -Wl,-rpath=./
lib_openfd_ctypes.cmo:	lib_openfd_ctypes.ml
	ocamlfind ocamlc -g -c -thread -package core,ctypes lib_openfd_ctypes.ml
testml_target:	testml.ml lib_openfd_ctypes.cmo
	ocmalfind ocamlc -g -thread -package core,ctypes testml.ml
