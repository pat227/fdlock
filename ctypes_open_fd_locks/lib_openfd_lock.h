#define _GNU_SOURCE
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

flock* acquireLock (int fd);
void releaseLock(flock* lck, int fd);
