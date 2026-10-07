#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <string>

#include "util.h"
#include "ui.h"

using namespace priism;

#ifdef PRIISM_BUILD_DATE_STR
static const char* SCRIPT_DATE = PRIISM_BUILD_DATE_STR;
#else
static const char* SCRIPT_DATE = "[2025-5-24]";
#endif

static std::string g_stateful_mnt;
static std::string g_rootfs_mnt = "/usb";
static std::string g_newroot = "/newroot";

static void cleanup() {
  if (!g_stateful_mnt.empty()) run({"umount", g_stateful_mnt});
  run({"umount", g_rootfs_mnt});
}

[[noreturn]] static void fail(const std::string& msg) {
  fprintf(stderr, "%s\nAborting.\n", msg.c_str());
  cleanup();
  sleep(1);
  run({"self_shell"});  // not always around, fine either way
  run({"tail", "-f", "/dev/null"});
  exit(1);
}

static int pvDircopy(const std::string& src, const std::string& dst) {
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

static std::string determineRootfs(const std::string& bootstrapDev) {
  size_t end = bootstrapDev.size();
  size_t start = end;
  while (start > 0 && isdigit((unsigned char)bootstrapDev[start - 1])) start--;
  if (start == end) return "";
  std::string prefix = bootstrapDev.substr(0, start);
  int num = atoi(bootstrapDev.substr(start).c_str());
  return prefix + std::to_string(num + 1);
}

static bool isBlockDev(const std::string& path) {
  struct stat st;
  return ::stat(path.c_str(), &st) == 0 && S_ISBLK(st.st_mode);
}

static void patchNewRootSh1mmer(const std::string& newroot) {
  std::string a = newroot + "/sbin/chromeos_startup";
  if (fileExists(a))
    runShell("sed -i \"s/BLOCK_DEVMODE=1/BLOCK_DEVMODE=/g\" " + shellEscape(a));
  std::string b = newroot + "/usr/share/cros/dev_utils.sh";
  if (fileExists(b))
    runShell("sed -i \"/^dev_check_block_dev_mode\\(\\)/a return\" " + shellEscape(b));
  std::string c = newroot + "/sbin/chromeos-boot-alert";
  if (fileExists(c))
    runShell("sed -i \"/^mode_block_devmode\\(\\)/a return\" " + shellEscape(c));
  // disable factory-related jobs
  for (auto* job : {"factory_shim", "factory_install", "factory_ui"}) {
    std::string f = newroot + "/etc/init/" + job + ".conf";
    if (fileExists(f)) {
      runShell("sed -i '/^start /!d' " + shellEscape(f));
      FILE* fp = fopen(f.c_str(), "a");
      if (fp) {
        fprintf(fp, "exec true\n");
        fclose(fp);
      }
    }
  }
}

// todo: dev console on tty4, better logging

int main(int argc, char** argv) {
  if (argc < 4) {
    fprintf(stderr, "Usage: %s <stateful_mnt> <stateful_dev> <bootstrap_dev> [arch]\n",
            argv[0]);
    return 1;
  }
  g_stateful_mnt = argv[1];
  std::string statefulDev = argv[2];
  std::string bootstrapDev = argv[3];
  std::string arch = (argc >= 5) ? argv[4] : "x86_64";
  const char* TMPFS_SIZE = "1024M";

  run({"stty", "-echo"});

  mkdirP(g_newroot);
  mkdirP(g_rootfs_mnt);
  if (run({"mount", "-t", "tmpfs", "tmpfs", g_newroot, "-o",
           std::string("size=") + TMPFS_SIZE}) != 0)
    fail("Failed to mount tmpfs");

  std::string rootfsDev = determineRootfs(bootstrapDev);
  if (rootfsDev.empty() || !isBlockDev(rootfsDev))
    fail("Could not determine rootfs");
  if (run({"mount", "-o", "ro", rootfsDev, g_rootfs_mnt}) != 0)
    fail("Failed to mount rootfs " + rootfsDev);

  printf("\033[?25l\033[2J\033[H");
  printf("%s", COLOR_MAGENTA_B);
  printf("                                              ....\n");
  printf("                        ..                  ......\n");
  printf("                       .::.              .........\n");
  printf("                      .:..:.          ......:::...\n");
  printf("                     .::..::.      ..::::---:::...\n");
  printf("  ........          ::::::::::  ..::-====--::.... \n");
  printf("        ...:::::...::::::::..:::-=++=--:.....     \n");
  printf("              ....----:::::::::-:.....            \n");
  printf("                .:-:.........::::.                \n");
  printf("               .............::::-:.               \n");
  printf("               ............::::::-:.              \n");
  printf("              .....::::::::::::::--:              \n");
  printf("%s", COLOR_RESET);
  printf("Priism is loading...\n");
  printf("Bootloader version: %s\n", SCRIPT_DATE);
  printf("https://github.com/xmb9/Priism\n");
  printf("\n");

  printf("Copying rootfs...\n");
  pvDircopy(g_rootfs_mnt, g_newroot);
  run({"umount", g_rootfs_mnt});
  printf("\n");

  int skipPatch = 0;

  printf("Patching new root...\n");
  printf("%s", COLOR_BLACK_B);
  run({"/bin/patch_new_root.sh", g_newroot, statefulDev});
  if (!skipPatch) patchNewRootSh1mmer(g_newroot);
  printf("%s", COLOR_RESET);
  printf("\n");

  if (!skipPatch) {
    printf("Copying Priism files...\n");
    runShell("cp -a " + shellEscape(g_newroot + "/sbin/init") + " /tmp/sh1mmer_init_orig >/dev/null 2>&1");
    pvDircopy(g_stateful_mnt + "/root/noarch", g_newroot);
    pvDircopy(g_stateful_mnt + "/root/" + arch, g_newroot);
    run({"cp", "/bin/busybox", g_newroot + "/bin/busybox"});
    runShell("cp -a /tmp/sh1mmer_init_orig " + shellEscape(g_newroot + "/sbin/init_sh1mmer_old_elf") + " >/dev/null 2>&1");
    runShell("cp -a /tmp/sh1mmer_init_orig " + shellEscape(g_newroot + "/usr/sbin/sh1mmer_init_old") + " >/dev/null 2>&1");
    runShell("cp -a /tmp/sh1mmer_init_orig " + shellEscape(g_newroot + "/sbin/sh1mmer_init_old") + " >/dev/null 2>&1");
    runShell("rm -f /tmp/sh1mmer_init_orig >/dev/null 2>&1");
    printf("\n");
  }

  run({"umount", g_stateful_mnt});

  // write this to a file so the user can easily run this from the debug shell
  {
    std::string script =
        "#!/bin/busybox sh\n"
        "\n"
        "if [ $$ -ne 1 ]; then\n"
        "\techo \"No PID 1. Abort.\"\n"
        "\texit 1\n"
        "fi\n"
        "\n"
        "BASE_MOUNTS=\"/sys /proc /dev\"\n"
        "move_mounts() {\n"
        "\t# copied from https://chromium.googlesource.com/chromiumos/platform/initramfs/+/54ea247a6283e7472a094215b4929f664e337f4f/factory_shim/bootstrap.sh#302\n"
        "\techo \"Moving $BASE_MOUNTS to " +
        g_newroot +
        "\"\n"
        "\tfor mnt in $BASE_MOUNTS; do\n"
        "\t\t# $mnt is a full path (leading '/'), so no '/' joiner\n"
        "\t\tmkdir -p \"" +
        g_newroot +
        "$mnt\"\n"
        "\t\tmount -n -o move \"$mnt\" \"" +
        g_newroot +
        "$mnt\"\n"
        "\tdone\n"
        "\techo \"Done.\"\n"
        "}\n"
        "\n"
        "move_mounts\n"
        "echo \"exec switch_root\"\n"
        "echo \"this shouldn't take more than a few seconds\"\n"
        "exec switch_root \"" +
        g_newroot + "\" /sbin/init -v --default-console output || :\n";
    writeFile("/bin/sh1mmer_switch_root", script);
    run({"chmod", "+x", "/bin/sh1mmer_switch_root"});
  }

  run({"stty", "echo"});
  execl("/bin/sh1mmer_switch_root", "/bin/sh1mmer_switch_root", (char*)nullptr);

  // should never reach here
  fail("Failed to exec switch_root.");
}
