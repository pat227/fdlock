#define _GNU_SOURCE
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include "lib_openfd_lock.h"

int main(int argc, char** args){
  if(argc != 2){
    printf("\nUsage:   string\n");
    return 1;
  }
  printf("\nTesting shared library linkage, ctypes, and open fd locks.");
  char* s = atoi(args[1]);
  
  printf("\nMaking struct by ref to ptr");
  printf("\nBTW; sizeof mystruct is: %u", sizeof(flock));
  flock * flk = NULL;

  flk = acquireLock(flk);
  if(i != 0){
    printf("\nError--exiting");
    exit(1);
  }
  printf("\nAcquired lock in main...will now release it.");
  releaseLock(flk);
  printf("\n");
  return 0;
}
