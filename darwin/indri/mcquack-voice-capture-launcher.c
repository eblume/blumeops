/* Launchd-facing shim for the voice-capture watcher (eblume/blumeops#2485).
 * launchd runs this binary, so its iCloud Drive consent is the one the watcher's
 * scan uses. It runs the watcher as a child and passes its exit status back. */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s <watcher>\n", argv[0]);
    return 64;
  }
  pid_t pid = fork();
  if (pid < 0) {
    fprintf(stderr, "voice-capture-launcher: error: fork: %s\n", strerror(errno));
    return 1;
  }
  if (pid == 0) {
    execl(argv[1], argv[1], (char *)NULL);
    fprintf(stderr, "voice-capture-launcher: error: cannot exec %s: %s\n", argv[1], strerror(errno));
    _exit(127);
  }
  int status;
  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR) {
      fprintf(stderr, "voice-capture-launcher: error: waitpid: %s\n", strerror(errno));
      return 1;
    }
  }
  if (WIFEXITED(status)) {
    return WEXITSTATUS(status);
  }
  return 128 + WTERMSIG(status);
}
