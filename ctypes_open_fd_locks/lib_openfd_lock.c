//gcc -isystem /usr/include/asm-generic -pthread example.c
#include "lib_openfd_lock.h"
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

struct flock* acquireLock (int fd)
{
  struct flock* flp = (struct flock*)malloc(sizeof(struct flock));
  //printf("\nflp ptr address:%x", flp);
  memset(((void*)flp),'\0',sizeof(struct flock));
  //printf("\nflp ptr address > memset:%x", flp);
  flp->l_whence = SEEK_SET;
  flp->l_start = 0;
  //in future can support byte range locking here; zero indicates lock entire
  //file; else x number bytes
  flp->l_len = 0;
  flp->l_type = F_WRLCK;
  //F_OFD_SETLKW is just like F_OFD_SETLK but blocks until request can be
  //completed instead of returning immediately with success or failure
  //extern int errno;
  //int errsv = errno;
  //printf ("\nAcquiring lock fd:%d", fd);
  int r = fcntl (fd, F_OFD_SETLKW, flp);
  //errsv = errno;
  //printf ("\nAcquired lock? fd:%d fcntl returned:%d\n", fd, r);
  if(r!=0){
    //printf ("\nFailed to acquire lock.");
    return NULL;
  }
  //printf("\nReturning flp ptr address:%x", flp);
  return flp;
}
void releaseLock(struct flock* lck, int fd){
  lck->l_type = F_UNLCK;
  //printf ("\nReleasing lock fd:%d", fd);
  fcntl (fd, F_OFD_SETLK, lck);
  /* sleep to ensure lock is yielded to another thread */
  usleep (1);
  free(lck);
  return;
}
