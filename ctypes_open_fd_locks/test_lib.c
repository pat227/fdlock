#include "lib_openfd_lock.h"

int main(int argc, char** args){
  if(argc != 2){
    printf("\nUsage:   string\n");
    return 1;
  }
  printf("\nTesting shared library linkage, ctypes, and open fd locks.");
  char* s = args[1];
  truncate (*s, 0);
  char buf[256];
  //open needs s not *s, yet bad form gets past compiler even with -Wall -Wextra
  //(possible -Werror?) while complaining about fcntl which works!
  int fd = open (s, O_RDWR | O_CREAT, 0666);
  printf("\nBTW; sizeof mystruct is: %u and fd is:%d", sizeof(struct flock), fd);
  if(fd <=0 ){
    printf("\nFailed to open file descriptor. Exiting.");
    return -1;
  }
  int fd2 = open (s, O_RDWR, 0666);
  printf("\nSecond fd is: %d", fd);
  struct flock* flk = NULL;
  //int i = 0;
  flk = acquireLock(fd);
  printf("Main: flk address:%x", flk);
  //if(i != 0){
  //  printf("\nError--exiting");
  //  exit(1);
  //}
  int len = sprintf (buf, "fd=%d\n", fd);
  lseek (fd, 0, SEEK_END);
  write (fd, buf, len);
  fsync (fd);
  printf("\nAcquired lock in main...will now release it.");
  releaseLock(flk, fd);
  printf("\n");
  return 0;
}
