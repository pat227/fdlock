//gcc -isystem /usr/include/asm-generic -pthread example.c
#define _GNU_SOURCE
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#define FILENAME        "foo"
/* From /usr/include/asm-generic  the non64 version has same field names
struct flock64 {
	short  l_type;
	short  l_whence;
	__kernel_loff_t l_start;
	__kernel_loff_t l_len;
	__kernel_pid_t  l_pid;
	__ARCH_FLOCK64_PAD
};
*/

flock* acquireLock (int fd)
{
  flock* flp = (flock*)malloc(sizeof(flock));
  memset(((void*)flp),'\0',sizeof(flock));
  flp->l_whence = SEEK_SET;
  flp->l_start = 0;
  flp->l_len = 1;
  flp->l_type = F_WRLCK;
  //fd = open (*arg, O_RDWR | O_CREAT, 0666);
  fcntl (fd, F_OFD_SETLKW, flp);
  printf ("\nAcquired lock");
  return flp;
}
void releaseLock(flock* lck, int fd){
  lck->l_type = F_UNLCK;
  fcntl (fd, F_OFD_SETLK, lck);
  /* sleep to ensure lock is yielded to another thread */
  usleep (1);
  free(lck);
  return;
}
