#include "priism.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "ui.h"
#include "util.h"

namespace priism {

[[noreturn]] void fail(const std::string& msg) {
  fprintf(stderr, "Priism panic: %s%s%s\n", COLOR_RED_B, msg.c_str(),
          COLOR_RESET);
  printf("panic: We are hanging here...");
  fflush(stdout);
  syncFs();
  run({"umount", "/mnt/priism/"});
  run({"umount", "/mnt/shimroot"});
  run({"umount", "/newroot"});
  run({"umount", "/mnt/recoroot"});
  run({"losetup", "-D"});
  hang();
}

[[noreturn]] void hang() {
  run({"tput", "civis"});
  run({"stty", "-echo"});
  sleep(3600);
  printf("You really still haven't turned off your device?\n");
  fflush(stdout);
  sleep(86400);
  printf("I give up. Bye.\n");
  fflush(stdout);
  sleep(5);
  run({"reboot", "-f"});
  for (;;) pause();  // Juuuuust in case.
}

std::string getLargestCrosBlockdev() {
  std::string biggest;
  long long best = 0;

  for (auto& blockdev : listDir("/sys/block")) {
    std::string name = blockdev.substr(blockdev.find_last_of('/') + 1);
    if (name.rfind("loop", 0) == 0 || name.rfind("ram", 0) == 0) continue;

    bool ok = false;
    long long size = 0;
    try {
      size = std::stoll(trim(readFile(blockdev + "/size", &ok)));
    } catch (...) {
      continue;
    }
    if (!ok) continue;

    bool ok2 = false;
    long long removable = 0;
    try {
      removable = std::stoll(trim(readFile(blockdev + "/removable", &ok2)));
    } catch (...) {
      continue;
    }
    if (!ok2) removable = 0;
    if (!(size > best && removable == 0)) continue;

    std::string table;
    run({"sfdisk", "-d", "/dev/" + name}, &table, true);
    if (table.find("name=\"STATE\"") != std::string::npos &&
        table.find("name=\"KERN-A\"") != std::string::npos &&
        table.find("name=\"ROOT-A\"") != std::string::npos) {
      biggest = "/dev/" + name;
      best = size;
    }
  }
  return biggest;
}

void exportKernelArgs(Context& ctx) {
  // Ported from shim initramfs
  bool ok = false;
  std::string cmdline = readFile("/proc/cmdline", &ok);
  if (!ok) return;

  // sed -e 's/"[^"]*"/DROPPED/g'
  std::string scrubbed;
  for (size_t i = 0; i < cmdline.size();) {
    if (cmdline[i] == '"') {
      size_t end = cmdline.find('"', i + 1);
      scrubbed += "DROPPED";
      i = (end == std::string::npos) ? cmdline.size() : end + 1;
    } else {
      scrubbed += cmdline[i++];
    }
  }

  printf("Exporting kernel arguments...\n");
  for (auto& arg : splitWs(scrubbed)) {
    size_t eq = arg.find('=');
    std::string rawKey = (eq == std::string::npos) ? arg : arg.substr(0, eq);
    std::string val = (eq == std::string::npos) ? arg : arg.substr(eq + 1);
    std::string key = toUpperFiltered(rawKey);
    setenvStr("KERN_ARG_" + key, val);
    ctx.kernArgs[key] = val;
  }
  printf("\n");
  fflush(stdout);
}

int copyLsb(Context& ctx) {
  printf("Copying lsb...\n");
  fflush(stdout);

  std::string lsbFile = "dev_image/etc/lsb-factory";
  std::string dest = ctx.newrootMnt + "/mnt/stateful_partition/" + lsbFile;
  std::string src = ctx.statefulMnt + "/" + lsbFile;

  size_t slash = dest.find_last_of('/');
  if (slash != std::string::npos) mkdirP(dest.substr(0, slash));

  if (!fileExists(src)) {
    printf("Failed to find %s!!\n", src.c_str());
    return 1;
  }

  // Convert kern_guid to uppercase and store extra info
  std::string guid = getenvStr("KERN_ARG_KERN_GUID");
  auto it = ctx.kernArgs.find("KERN_GUID");
  if (it != ctx.kernArgs.end()) guid = it->second;
  for (auto& c : guid) c = (char)toupper((unsigned char)c);

  printf("Found %s\n", src.c_str());
  if (run({"cp", "-a", src, dest}) != 0) return 1;
  FILE* f = fopen(dest.c_str(), "a");
  if (!f) return 1;
  fprintf(f, "REAL_USB_DEV=%sp3\n", ctx.loop.c_str());
  fprintf(f, "KERN_ARG_KERN_GUID=%s\n", guid.c_str());
  fclose(f);
  return 0;
}

int pvDircopy(const std::string& src, const std::string& dst) {
  struct stat st;
  if (::stat(src.c_str(), &st) != 0 || !S_ISDIR(st.st_mode)) return 1;

  std::string du;
  run({"du", "-sb", src}, &du);
  std::string bytes = "0";
  auto bits = splitWs(du);
  if (!bits.empty()) bytes = trim(bits[0]);

  mkdirP(dst);
  std::string pipe;
  if (run({"sh", "-c", "command -v pv >/dev/null 2>&1"}) == 0)
    pipe = "tar -cf - -C " + shellEscape(src) + " . | pv -f -s " +
           shellEscape(bytes) + " | tar -xf - -C " + shellEscape(dst);
  else
    pipe = "tar -cf - -C " + shellEscape(src) + " . | tar -xf - -C " +
           shellEscape(dst);
  return runShell(pipe);
}

// Wow. Just wow.
// Why didn't I think of any of this before.
void setupImagesPartition(Context& ctx) {
  if (run({"mount", ctx.priismImages, ctx.priismMnt}) != 0)
    fail("Failed to mount PRIISM_IMAGES partition!");

  // this shit is no longer janky!
  bool needResize = false;
  {
    std::string marker = ctx.priismMnt + "/.IMAGES_NOT_YET_RESIZED";
    if (pathExists(marker)) {
      if (dirExists(marker)) {
        bool ok = false;
        needResize = isNonEmptyDir(marker, &ok) && ok;
      } else {
        needResize = true;
      }
    }
  }

  if (needResize) {
    printf("%sPriism needs to resize your images partition!%s\n", COLOR_YELLOW,
           COLOR_RESET);
    pressEnter();
    printf("%sInfo: Growing PRIISM_IMAGES partition%s\n", COLOR_GREEN,
           COLOR_RESET);

    run({"umount", ctx.priismImages});

    // resolve the by-label symlink first, growpart chokes on it otherwise
    char resolved[4096];
    std::string part = realpath(ctx.priismImages.c_str(), resolved)
                           ? std::string(resolved)
                           : ctx.priismImages;
    // growpart. why. why didn't you have to be different.
    if (run({"growpart", part}) != 0)
      fail("growpart failed on " + part + "! Not resizing, bailing out.");
    run({"e2fsck", "-f", ctx.priismImages});

    printf(
        "%sInfo: Resizing filesystem (This operation may take a while, do not "
        "panic if it looks stuck!)%s\n",
        COLOR_GREEN, COLOR_RESET);
    if (run({"resize2fs", "-p", ctx.priismImages}) != 0)
      fail("Failed to resize filesystem on " + ctx.priismImages + "!");

    printf("%sDone. Remounting partition...%s\n", COLOR_GREEN, COLOR_RESET);
    run({"mount", ctx.priismImages, ctx.priismMnt});
    run({"rm", "-rf", ctx.priismMnt + "/.IMAGES_NOT_YET_RESIZED"});
    syncFs();
  }

  for (auto& p : listDir(ctx.priismMnt)) chmodPath(p, 0777);
}

void actionCredits(Context& ctx) {
  printf("%sPriism credits\n", COLOR_MAGENTA_B);
  printf("%sxmb9%s: Pioneering the creation of this tool\n", COLOR_BLUE_B, COLOR_RESET);
  printf("%sMercury Workshop%s: Finding the SH1MMER exploit\n", COLOR_MAGENTA_B, COLOR_RESET);
  printf("%sOlyB%s: Help with adapting wax to Priism and PID1\n", COLOR_MAGENTA_B, COLOR_RESET);
  printf("%skxtzownsu%s: Help with sed syntax\n", COLOR_MAGENTA_B, COLOR_RESET);
  printf("%sSimon%s: Testing Priism and building the very first shims\n", COLOR_RED_B, COLOR_RESET);
  printf(" \n");
  pressEnter();
  clearScreen();
  splash(ctx.version.str(), ctx.version.buildDate);
}

static std::string firstWordFirstLine(const std::string& s) {
  size_t nl = s.find('\n');
  auto words = splitWs(trim(s.substr(0, nl)));
  return words.empty() ? "" : words[0];
}

static bool fileHas(const std::string& path, const std::string& needle) {
  bool ok = false;
  std::string data = readFile(path, &ok);
  return ok && data.find(needle) != std::string::npos;
}

void actionShimboot(Context& ctx) {
  std::string shim;

  {
    bool ok = false;
    bool empty = !isNonEmptyDir(ctx.priismMnt + "/shims", &ok) || !ok;
    if (empty) {
      printf(
          "%sYou have no shims downloaded!\n"
          "Please download a few images for your board %s (%s) into the shims "
          "folder on PRIISM_IMAGES!\n"
          "If you have a computer running Windows, use WSL or this chrome "
          "device. If you have a Mac, use this chrome device to download "
          "images instead.%s\n\n",
          COLOR_YELLOW_B, ctx.boardName.c_str(), ctx.chromeosBoard.c_str(),
          COLOR_RESET);
      shim = "Exit";
    } else {
      printf("Choose the shim you want to boot:\n");
      auto opts = listDir(ctx.priismMnt + "/shims");
      opts.push_back("Exit");
      shim = menuCompat("Boot an RMA shim", opts);
      if (shim.empty()) shim = "Exit";
    }
  }

  if (shim == "Exit") {
    pressEnter();
    clearScreen();
    return;
  }

  mkdirP(ctx.shimroot);
  printf("Searching for ROOT-A on shim...\n");

  std::string loopOut;
  if (run({"losetup", "-fP", "--show", shim}, &loopOut) != 0)
    fail("losetup failed for " + shim);
  ctx.loop = trim(loopOut);
  setenvStr("loop", ctx.loop);

  std::string found;
  {
    std::string out;
    if (run({"cgpt", "find", "-l", "ROOT-A", ctx.loop}, &out) == 0 &&
        !trim(out).empty()) {
      found = out;
    } else {
      out.clear();
      if (run({"cgpt", "find", "-t", "rootfs", ctx.loop}, &out) == 0)
        found = out;
    }
  }
  std::string loopRoot = firstWordFirstLine(found);
  if (loopRoot.empty()) {
    run({"losetup", "-D"});
    fail("Could not find ROOT-A on " + shim);
  }

  int mountRc = run({"mount", loopRoot, ctx.shimroot});
  if (mountRc != 0) {
    fail("Mount process failed! Exit code was " + std::to_string(mountRc) +
         ".\n"
         "              This may be a bug! Please check your shim,\n"
         "              and if it looks fine, report it to the GitHub repo!\n");
  }
  printf("ROOT-A found successfully and mounted.\n");

  bool unpatched = false;
  std::string bootstrap = ctx.shimroot + "/sbin/bootstrap.sh";
  std::string main_sh = ctx.shimroot + "/usr/sbin/sh1mmer_main.sh";


  if (fileHas(main_sh, "Portable recovery image installer/shim manager")) {
    printf("%s%s%s\n", COLOR_YELLOW_B, randomRefusal().c_str(), COLOR_RESET);
    run({"umount", "/mnt/shimroot"});
    run({"losetup", "-D"});
    pressEnter();
    clearScreen();
    return;
  }

  std::string stateful;
  {
    std::string out;
    if (run({"cgpt", "find", "-l", "STATE", ctx.loop}, &out) == 0) {
      std::string cand = firstWordFirstLine(out);
      if (cand.find("/dev/") != std::string::npos) stateful = cand;
    }
    if (stateful.empty()) {
      printf(
          "%sFinding stateful via partition label \"STATE\" failed (try "
          "1...)%s\n",
          COLOR_YELLOW_B, COLOR_RESET);
      out.clear();
      if (run({"cgpt", "find", "-l", "SH1MMER", ctx.loop}, &out) == 0) {
        std::string cand = firstWordFirstLine(out);
        if (cand.find("/dev/") != std::string::npos) stateful = cand;
      }
    }
    if (stateful.empty()) {
      printf(
          "%sFinding stateful via partition label \"SH1MMER\" failed (try "
          "2...)%s\n",
          COLOR_YELLOW_B, COLOR_RESET);
      for (int i = 1; i <= 64 && stateful.empty(); i++) {
        for (auto& dev :
             {ctx.loop + "p" + std::to_string(i), ctx.loop + std::to_string(i)}) {
          if (!pathExists(dev)) continue;
          std::string info;
          run({"udevadm", "info", "--query=property", "--name=" + dev}, &info);
          if (info.find("ID_PART_ENTRY_TYPE=0fc63daf-8483-4772-8e79-3d69d8477de4") !=
              std::string::npos) {
            stateful = dev;
            break;
          }
        }
      }
    }
  }
  if (trim(stateful).empty()) {
    printf(
        "%sFinding stateful via partition type \"Linux data\" failed! (try "
        "3...)%s\n",
        COLOR_RED_B, COLOR_RESET);
    printf("Last resort (try 4...)\n");
    stateful = ctx.loop + "p1";
  }

  if (!unpatched) {
    mkdirP("/stateful");
    mkdirP("/newroot");

    if (run({"mount", "-t", "tmpfs", "tmpfs", "/newroot", "-o", "size=1024M"}) !=
        0)
      fail("Could not allocate 1GB of TMPFS to the newroot mountpoint.");
    if (run({"mount", stateful, "/stateful"}) != 0)
      fail("Failed to mount stateful partition!");

    copyLsb(ctx);

    printf("Copying rootfs to ram.\n");
    pvDircopy(ctx.shimroot, "/newroot");

    printf("Moving mounts...\n");
    mkdirP("/newroot/dev");
    mkdirP("/newroot/proc");
    mkdirP("/newroot/sys");
    mkdirP("/newroot/tmp");
    mkdirP("/newroot/run");
    run({"mount", "-t", "tmpfs", "-o", "mode=1777", "none", "/newroot/tmp"});
    run({"mount", "-t", "tmpfs", "-o", "mode=0555", "run", "/newroot/run"});
    run({"mkdir", "-p", "-m", "0755", "/newroot/run/lock"});

    run({"umount", "-l", "/dev/pts"});
    run({"umount", "-f", "/dev/pts"});

    for (auto* m : {"/dev", "/proc", "/sys"}) {
      run({"mount", "--move", m, std::string("/newroot") + m});
      run({"umount", "-l", m});
    }

    if (run({"umount", "/stateful"}) != 0)
      fail("Failed to unmount stateful partition before switching root!");

    printf("Done.\n");
    printf(
        "About to switch root. If your screen goes black and the device "
        "reboots, it may be a bug. Please make a GitHub issue if you're sure "
        "your shim isn't corrupted.\n");
    sleep(1);
    printf("Switching root!\n");
    clearScreen();

    mkdirP("/newroot/tmp/priism");
    if (run({"pivot_root", "/newroot", "/newroot/tmp/priism"}) != 0)
      fail("pivot_root failed!");

    printf("Starting init\n");
    for (const char* initPath : {"/bin/kvs", "/sbin/init", "/etc/init",
                                 "/bin/init", "/usr/bin/init",
                                 "/usr/sbin/init"}) {
      if (pathExists(initPath)) execl(initPath, initPath, (char*)nullptr);
    }

    printf("Failed to start init!!!\n");
    printf("Bailing out, you are on your own. Good luck.\n");
    printf("This shell has PID 1. Exit = panic.\n");
    run({"/tmp/priism/bin/uname", "-a"});
    execl("/tmp/priism/bin/sh", "/tmp/priism/bin/sh", (char*)nullptr);
    fail("exec init failed!");
  }
}

void actionInstallCros(Context& ctx) {
  std::string reco;

  {
    bool ok = false;
    bool empty = !isNonEmptyDir(ctx.priismMnt + "/recovery", &ok) || !ok;
    if (empty) {
      printf(
          "%sYou have no recovery images downloaded!\n"
          "Please download a few images for your board %s (%s) into the "
          "recovery folder on PRIISM_IMAGES!\n"
          "These are available on websites such as chrome100.dev, or "
          "cros.tech.\n"
          "Chrome100 hosts old and new recovery images, whereas cros.tech "
          "only hosts the latest images.\n"
          "If you have a computer running Windows, use WSL or this chrome "
          "device. If you have a Mac, use this chrome device to download "
          "images instead.%s\n\n",
          COLOR_YELLOW_B, ctx.boardName.c_str(), ctx.chromeosBoard.c_str(),
          COLOR_RESET);
      reco = "Exit";
    } else {
      printf("Choose the image you want to flash:\n");
      auto opts = listDir(ctx.priismMnt + "/recovery");
      opts.push_back("Exit");
      reco = menuCompat("Install a ChromeOS recovery image", opts);
      if (reco.empty()) reco = "Exit";
    }
  }

  if (reco == "Exit") {
    pressEnter();
    clearScreen();
    return;
  }

  mkdirP(ctx.recoroot);
  printf("Searching for ROOT-A on reco image...\n");

  std::string loopOut;
  if (run({"losetup", "-fP", "--show", reco}, &loopOut) != 0)
    fail("losetup failed for " + reco);
  ctx.loop = trim(loopOut);
  setenvStr("loop", ctx.loop);

  // Usually the 3rd partition is always the "real" ROOT-A
  std::string rootOut;
  run({"cgpt", "find", "-l", "ROOT-A", ctx.loop}, &rootOut);
  std::string loopRoot = firstWordFirstLine(rootOut);
  if (loopRoot.empty()) fail("Could not find ROOT-A on " + reco);

  int mountRc = run({"mount", "-r", loopRoot, ctx.recoroot});
  if (mountRc != 0) {
    fail("Mount process failed! Exit code was " + std::to_string(mountRc) +
         ".\n"
         "              This may be a bug! Please check your recovery image,\n"
         "              and if it looks fine, report it to the GitHub repo!\n");
  }
  printf("ROOT-A found successfully and mounted.\n");

  std::string stateOut;
  std::string preferred;
  if (run({"cgpt", "find", "-l", "STATE", ctx.loop}, &stateOut) == 0)
    preferred = firstWordFirstLine(stateOut);
  if (trim(preferred).empty())
    fail("Failed to find stateful partition on " + ctx.loop + "!");

  mkdirP("/mnt/stateful_partition");

  std::vector<std::string> candidates;
  candidates.push_back(preferred);
  auto addLoopDevs = [&](const std::vector<std::string>& args) {
    std::vector<std::string> cmd = {"blkid", "-o", "device"};
    cmd.insert(cmd.end(), args.begin(), args.end());
    std::string out;
    if (run(cmd, &out) != 0) return;
    for (auto& dev : splitWs(out)) {
      if (dev.rfind(ctx.loop, 0) != 0 || dev == preferred ||
          dev == loopRoot)
        continue;
      bool dup = false;
      for (auto& c : candidates)
        if (c == dev) dup = true;
      if (!dup) candidates.push_back(dev);
    }
  };
  addLoopDevs({"-t", "LABEL=STATE"});
  addLoopDevs({"-t", "TYPE=ext4"});

  std::string stateful;
  bool readOnly = false;
  for (auto& dev : candidates) {
    std::string type;
    run({"blkid", "-o", "value", "-s", "TYPE", dev}, &type);
    type = trim(type);
    if (!type.empty()) {
      if (run({"mount", "-t", type, dev, "/mnt/stateful_partition"}) == 0) {
        stateful = dev;
        break;
      }
    } else if (run({"mount", dev, "/mnt/stateful_partition"}) == 0) {
      stateful = dev;
      break;
    }
    if (run({"mount", "-o", "ro", dev, "/mnt/stateful_partition"}) == 0) {
      stateful = dev;
      readOnly = true;
      break;
    }
  }
  if (stateful.empty()) {
    std::string tried;
    for (auto& dev : candidates) tried += (tried.empty() ? "" : ", ") + dev;
    fail("Failed to mount stateful partition! Tried: " + tried +
         ". Check dmesg if possible.");
  }
  if (readOnly)
    printf("WARNING: stateful mounted read-only, install may fail.\n");
  if (stateful != preferred)
    printf("Using %s as stateful instead of %s.\n", stateful.c_str(),
           preferred.c_str());


  // I can't think of any other way to do this.
  runShell("cd " + shellEscape(ctx.recoroot) +
           " && for d in /proc /dev /sys /tmp /run /var "
           "/mnt/stateful_partition; do "
           "mount -n --bind \"$d\" \".$d\" && mount --make-slave \".$d\"; done");

  std::string crosDev = getLargestCrosBlockdev();
  if (trim(crosDev).empty()) {
    printf(
        "%sNo ChromeOS drive was found on the device! Please make sure "
        "ChromeOS is installed before using Priism. Continuing anyway...%s\n",
        COLOR_YELLOW_B, COLOR_RESET);
  }

  setenvStr("IS_RECOVERY_INSTALL", "1");
  std::string install =
      "cd " + shellEscape(ctx.recoroot) +
      " && IS_RECOVERY_INSTALL=1 chroot ./ /usr/sbin/chromeos-install "
      "--payload_image=" +
      shellEscape(ctx.loop) + " --yes";
  if (runShell(install) != 0) fail("Failed during chroot!");

  // Juusst in case.
  if (!trim(crosDev).empty()) {
    if (run({"cgpt", "add", "-i", "2", crosDev, "-P", "15", "-T", "15", "-S",
             "1", "-R", "1"}) != 0)
      printf("%sFailed to set kernel priority! Continuing anyway.%s\n",
             COLOR_YELLOW_B, COLOR_RESET);
  }

  printf("%s\n", COLOR_GREEN);
  pressEnter("Recovery finished. Press any key to reboot.");
  run({"reboot"});
  sleep(1);
  printf("\n%sReboot failed. Hanging...", COLOR_RED_B);
  hang();
}

void actionReboot(Context& ctx) {
  if (ctx.releaseBuild) {
    printf("Rebooting...\n");
    syncFs();
    run({"reboot", "-f"});
    sleep(1);
    printf("%sReboot failed. Hanging...", COLOR_RED_B);
    hang();
  } else {
    printf("Use the bash shell to reboot.\n");
  }
  pressEnter();
  clearScreen();
}

void actionShutdown(Context& ctx) {
  if (ctx.releaseBuild) {
    printf("Shutting down...\n");
    syncFs();
    run({"poweroff", "-f"});
    sleep(1);
    printf("%sShutdown failed. Hanging...", COLOR_RED_B);
    hang();
  } else {
    printf("Use the bash shell to shutdown.\n");
  }
  pressEnter();
  clearScreen();
}

void actionExitDebug(Context& ctx) {
  if (!ctx.releaseBuild) {
    printf("%sExit is only meant to be used when\n", COLOR_YELLOW_B);
    printf("testing Priism outside of shims!\n");
    printf("Are you sure you want to do this?%s\n", COLOR_RESET);
    printf("(y/n) >");
    fflush(stdout);
    int c = getchar();
    int d;
    do {
      d = getchar();
      if (d == '\n' || d == EOF) break;
    } while (true);
    if (c == 'y' || c == 'Y') {
      run({"umount", "/mnt/recoroot"});
      run({"umount", "/mnt/shimroot"});
      run({"umount", "/mnt/new_root"});
      run({"umount", "/mnt/priism"});
      run({"losetup", "-D"});
      run({"rm", "-rf", "/mnt/recoroot"});
      run({"rm", "-rf", "/mnt/priism"});
      run({"rm", "-rf", "/mnt/shimroot"});
      run({"rm", "-rf", "/mnt/new_root"});
      exit(0);
    }
    printf("Cancelled.\n");
  } else {
    printf("This option is only available on debug builds.\n");
  }
  pressEnter();
  clearScreen();
}

void actionPayloads(Context& ctx) {
  auto opts = globRegularFiles(ctx.priismMnt + "/payloads", ".sh");
  opts.push_back("Exit");
  std::string payload = menuCompat("Payloads", opts);
  if (payload.empty() || payload == "Exit") {
    clearScreen();
    return;
  }
  // payloads expect the colors, same as when priism.sh sourced them
  setenvStr("COLOR_RESET", COLOR_RESET);
  setenvStr("COLOR_RED_B", COLOR_RED_B);
  setenvStr("COLOR_GREEN", COLOR_GREEN);
  setenvStr("COLOR_GREEN_B", COLOR_GREEN_B);
  setenvStr("COLOR_YELLOW", COLOR_YELLOW);
  setenvStr("COLOR_YELLOW_B", COLOR_YELLOW_B);
  setenvStr("COLOR_BLUE_B", COLOR_BLUE_B);
  setenvStr("COLOR_MAGENTA_B", COLOR_MAGENTA_B);
  setenvStr("COLOR_CYAN_B", COLOR_CYAN_B);
  setenvStr("COLOR_BLACK_B", COLOR_BLACK_B);
  runBash("source " + shellEscape(payload));
  pressEnter();
  clearScreen();
}

void actionChangelog(Context&) {
  if (runShell("cat /changelog.txt | busybox less") != 0)
    runShell("cat /changelog.txt");
  pressEnter();
  clearScreen();
}

int runMainLoop(Context& ctx) {
  std::vector<std::string> options = {
      "Bash shell", "Boot an RMA shim", "Install a ChromeOS recovery image",
      "Payloads",   "Credits",          "Changelog",
      "Reboot",     "Power off"};
  if (!ctx.releaseBuild) options.push_back("Exit [Debug]");

  for (;;) {
    std::string prompt =
        "Main menu - Priism [" + ctx.version.str() + "] - " + randomSplash();
    std::string picked = menuCompat(prompt, options);
    clearScreen();

    if (picked.empty()) {
      printf("No selection. Exiting.\n"); 
      return 0;
    } else if (picked == "Bash shell") {
      run({"bash"});
    } else if (picked == "Boot an RMA shim") {
      actionShimboot(ctx);
    } else if (picked == "Install a ChromeOS recovery image") {
      actionInstallCros(ctx);
    } else if (picked == "Payloads") {
      actionPayloads(ctx);
    } else if (picked == "Credits") {
      actionCredits(ctx);
    } else if (picked == "Changelog") {
      actionChangelog(ctx);
    } else if (picked == "Reboot") {
      actionReboot(ctx);
    } else if (picked == "Power off") {
      actionShutdown(ctx);
    } else if (picked == "Exit [Debug]") {
      actionExitDebug(ctx);
    } else {
      printf("You entered an invalid option (%s)... Somehow.\n",
             picked.c_str());
      sleep(1);
    }
    printf("\n");
  }
}

}
