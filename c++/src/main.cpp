#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "priism.h"
#include "ui.h"
#include "util.h"

using namespace priism;

static void help(const char* argv0) {
  printf("Usage: %s [options]\n", argv0);
  printf("\nAvailable arguments:\n");
  printf("\n  --debug      Allow interrupts and show the Exit option in the menu\n");
  printf("  --dev        Skip PRIISM_IMAGES mount/resize operations\n");
  printf("  --version    Print the version\n");
  printf("  -h, --help   You're reading it.\n");
  printf("\nEnv:\n");
  printf("  PRIISM_USE_SHMENU=1  Use the old `shmenu` binary for menus\n");
  printf("  PRIISM_MENU_PLAIN=1  Numbered menus (pipes, tests, etc)\n");
  printf("  PRIISM_DEV=1         Same as --dev\n");
}

static std::string lsbBoard() {
  // before we just did `source /etc/lsb-release`, this is the same thing
  // but only for the one var we actually care about
  bool ok = false;
  std::string data = readFile("/etc/lsb-release", &ok);
  if (!ok) return "";
  size_t pos = 0;
  while (pos < data.size()) {
    size_t nl = data.find('\n', pos);
    std::string line =
        trim(data.substr(pos, nl == std::string::npos ? std::string::npos : nl - pos));
    pos = (nl == std::string::npos) ? data.size() : nl + 1;
    if (line.rfind("CHROMEOS_RELEASE_BOARD=", 0) == 0) {
      std::string v = trim(line.substr(strlen("CHROMEOS_RELEASE_BOARD=")));
      if (v.size() >= 2 && v.front() == '"' && v.back() == '"')
        v = v.substr(1, v.size() - 2);
      return v;
    }
  }
  return "";
}

int main(int argc, char** argv) {
  Context ctx;

  bool devMode = getenvStr("PRIISM_DEV") == "1";
  for (int i = 1; i < argc; i++) {
    std::string a = argv[i];
    if (a == "--debug")
      ctx.releaseBuild = false;
    else if (a == "--dev")
      devMode = true;
    else if (a == "--version") {
      printf("Priism %s %s\n", ctx.version.str().c_str(),
             ctx.version.buildDate.c_str());
      return 0;
    } else if (a == "-h" || a == "--help") {
      help(argv[0]);
      return 0;
    } else {
      fprintf(stderr, "Unknown argument: %s\n", a.c_str());
      help(argv[0]);
      return 2;
    }
  }
  if (getenv("PRIISM_DEBUG")) ctx.releaseBuild = false;
  // --dev is for poking at the menu on a normal computer, so it gets the
  // debug behavior too (ctrl-c works, Exit shows up, reboot is a no-op).
  if (devMode) ctx.releaseBuild = false;

  if (ctx.releaseBuild) signal(SIGINT, SIG_IGN);  // `trap '' INT`

  clearScreen();
  splash(ctx.version.str(), ctx.version.buildDate);
  printf(
      "%sPriism is currently in active development. Please report any issues "
      "you find.%s\n\n",
      COLOR_YELLOW_B, COLOR_RESET);
  pressEnter();

  mkdirP("/mnt/priism");
  mkdirP("/mnt/new_root");
  mkdirP("/mnt/shimroot");
  mkdirP("/mnt/recoroot");

  // Remember when I was an idiot and didn't do this?
  ctx.priismImages = "/dev/disk/by-label/PRIISM_IMAGES";

  {
    bool ok = false;
    std::string name =
        readFile("/sys/devices/virtual/dmi/id/board_name", &ok);
    if (!ok) {
      printf("%sBoard name detection failed. This isn't that big of an issue.%s\n",
             COLOR_YELLOW_B, COLOR_RESET);
      ctx.boardName = "";
    } else {
      size_t nl = name.find('\n');  // head -n 1
      ctx.boardName = trim(name.substr(0, nl));
    }
  }
  ctx.chromeosBoard = lsbBoard();

  if (!devMode)
    setupImagesPartition(ctx);
  else
    printf("Skipping PRIISM_IMAGES mount/resize\n");

  exportKernelArgs(ctx);

  return runMainLoop(ctx);
}
