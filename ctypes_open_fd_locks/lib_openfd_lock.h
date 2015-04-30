#define _GNU_SOURCE
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#define FILENAME        "foo"
#include <stdlib.h>
#include <string.h>
#include <errno.h>
struct flock* acquireLock (int fd);
void releaseLock(struct flock* lck, int fd);
