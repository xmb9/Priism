#include "ui.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include "util.h"

namespace priism {

const char* COLOR_RESET = "\033[0m";
const char* COLOR_BLACK_B = "\033[1;30m";
const char* COLOR_RED_B = "\033[1;31m";
const char* COLOR_GREEN = "\033[0;32m";
const char* COLOR_GREEN_B = "\033[1;32m";
const char* COLOR_YELLOW = "\033[0;33m";
const char* COLOR_YELLOW_B = "\033[1;33m";
const char* COLOR_BLUE_B = "\033[1;34m";
const char* COLOR_MAGENTA_B = "\033[1;35m";
const char* COLOR_CYAN_B = "\033[1;36m";

std::string randomSplash() {
  static const char* lines[] = {
      "Triangle is love, triangle is life.",
      "Placeholder splash text",
      "The lower tape fade meme is still massive",
      "Now in C++!",
      "The average reaction after talking with fanqyxl",
      "Discord speech impediment... oh wait that's 2468",
  };
  return lines[pickRandom(6)];
}

std::string randomRefusal() {
  static const char* lines[] = {
      "Hearsay!",
      "I refuse.",
      "I shall do no such thing!",
      "Like... why???",
      "I certainly will not!",
      "Are you just here to dillydaddle?",
      "You really have nothing better to do, don't you?",
  };
  return lines[pickRandom(7)];
}

static std::string centerPad(const std::string& s, int width) {
  int pad = (width - (int)s.size()) / 2;
  if (pad < 0) pad = 0;
  return std::string((size_t)pad, ' ') + s;
}

void splash(const std::string& versionString, const std::string& buildDate) {
  const int width = 48;
  printf("%s                                             ....\n", COLOR_MAGENTA_B);
  printf("                       ..                  ......\n");
  printf("                      .::.              .........\n");
  printf("                     .:..:.          ......:::...\n");
  printf("                    .::..::.      ..::::---:::...\n");
  printf(" ........          ::::::::::  ..::-====--::.... \n");
  printf("       ...:::::...::::::::..:::-=++=--:.....     \n");
  printf("             ....----:::::::::-:.....            \n");
  printf("               .:-:.........::::.                \n");
  printf("              .............::::-:.               \n");
  printf("              ............::::::-:.              \n");
  printf("             .....::::::::::::::--:  %s\n", COLOR_RESET);
  printf("                     Priism                      \n");
  printf("                       or                        \n");
  printf(" Portable recovery image installer/shim manager  \n");
  printf("%s\n", centerPad(versionString, width).c_str());
  printf("%s\n", centerPad(buildDate, width).c_str());
  printf(" \n");
  printf("%s\n", centerPad(randomSplash().c_str(), width).c_str());
  printf(" \n");
  fflush(stdout);
}

namespace {

struct TermGuard {
  struct termios saved{};
  bool active = false;

  void enter() {
    if (!isatty(STDIN_FILENO)) return;
    if (tcgetattr(STDIN_FILENO, &saved) != 0) return;
    active = true;
    struct termios raw = saved;
    raw.c_lflag &= (tcflag_t) ~(ICANON | ECHO);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    printf("\e[?7l\e[?1049h");
    fflush(stdout);
  }

  void leave() {
    if (!active) return;
    active = false;
    printf("\e[?7h\e[?1049l");
    fflush(stdout);
    tcsetattr(STDIN_FILENO, TCSANOW, &saved);
    printf("\e[?25h");
    fflush(stdout);
  }
};

std::string readKey() {
  char c;
  if (read(STDIN_FILENO, &c, 1) <= 0) return "EOF";
  if (c == '\n' || c == '\r') return "ENTER";
  if (c == '\033') {
    char seq[2];
    if (read(STDIN_FILENO, &seq[0], 1) <= 0) return "OTHER";
    if (read(STDIN_FILENO, &seq[1], 1) <= 0) return "OTHER";
    if (seq[0] == '[' && seq[1] == 'B') return "DOWN";
    if (seq[0] == '[' && seq[1] == 'A') return "UP";
    return "OTHER";
  }
  if (c == 'j') return "DOWN";
  if (c == 'k') return "UP";
  return "OTHER";
}

void drawMenu(const std::string& prompt, const std::vector<std::string>& opts,
              size_t cur) {
  printf("\e[2J\e[H");
  printf("\e[4m%s\e[m\n\r", prompt.c_str());
  for (size_t i = 0; i < opts.size(); i++) {
    if (i == cur)
      printf("\e[7m[X] %s\e[m\n\r", opts[i].c_str());
    else
      printf("[ ] %s\n\r", opts[i].c_str());
  }
  printf("\e[7mUse arrow keys to navigate. Press enter to confirm.\e[m\n\r");
  fflush(stdout);
}

}

std::string menu(const std::string& prompt,
                 const std::vector<std::string>& options) {
  if (options.empty()) return "";

  if (!isatty(STDIN_FILENO) || getenv("PRIISM_MENU_PLAIN")) {
    // piped / test mode
    printf("%s\n", prompt.c_str());
    for (size_t i = 0; i < options.size(); i++)
      printf("  %zu) %s\n", i + 1, options[i].c_str());
    printf("> ");
    fflush(stdout);
    char* line = nullptr;
    size_t cap = 0;
    ssize_t n = getline(&line, &cap, stdin);
    std::string picked;
    if (n > 0) {
      std::string s = trim(std::string(line, (size_t)n));
      char* end = nullptr;
      long idx = strtol(s.c_str(), &end, 10);
      if (end && *end == '\0' && idx >= 1 && (size_t)idx <= options.size())
        picked = options[(size_t)idx - 1];
      else
        for (auto& o : options)
          if (o == s) picked = o;
    }
    free(line);
    return picked;
  }

  TermGuard tg;
  tg.enter();
  printf("\e[?25l");
  fflush(stdout);

  size_t cur = 0;
  std::string picked;
  while (true) {
    drawMenu(prompt, options, cur);
    if (!isatty(STDOUT_FILENO)) break;  // thanks, taken from fff
    std::string k = readKey();
    if (k == "DOWN") {
      if (cur + 1 < options.size()) cur++;
    } else if (k == "UP") {
      if (cur > 0) cur--;
    } else if (k == "ENTER") {
      picked = options[cur];
      break;
    } else if (k == "EOF") {
      break;
    }
  }
  tg.leave();
  return picked;
}

std::string menuCompat(const std::string& prompt,
                       const std::vector<std::string>& options) {
  if (getenv("PRIISM_USE_SHMENU")) {
    // old path: `shmenu -o ... -p ...`, answer lands in /tmp/shmenu_choice
    std::string joined;
    for (size_t i = 0; i < options.size(); i++) {
      if (i) joined += "\n";
      joined += options[i];
    }
    char tmpl[] = "/tmp/priism_opts_XXXXXX";
    int fd = mkstemp(tmpl);
    if (fd >= 0) {
      (void)write(fd, joined.data(), joined.size());
      close(fd);
      runShell(std::string("shmenu -o \"$(cat ") + tmpl + ")\" -p " +
               shellEscape(prompt));
      unlink(tmpl);
    }
    bool ok = false;
    std::string choice = trim(readFile("/tmp/shmenu_choice", &ok));
    if (ok && !choice.empty()) return choice;
    return "";
  }
  return menu(prompt, options);
}

}
