#include "util.h"

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <algorithm>
#include <random>
#include <ctime>

namespace priism {

int run(const std::vector<std::string>& argv, std::string* capture,
        bool mergeStderr) {
  if (argv.empty()) return 127;

  int pipefd[2] = {-1, -1};
  if (capture && pipe(pipefd) != 0) return -1;

  pid_t pid = fork();
  if (pid < 0) {
    if (capture) {
      close(pipefd[0]);
      close(pipefd[1]);
    }
    return -1;
  }

  if (pid == 0) {
    // kid
    if (capture) {
      close(pipefd[0]);
      dup2(pipefd[1], STDOUT_FILENO);
      if (mergeStderr) dup2(pipefd[1], STDERR_FILENO);
      close(pipefd[1]);
    }
    std::vector<std::string> copy = argv;
    std::vector<char*> cargs;
    for (auto& s : copy) cargs.push_back(const_cast<char*>(s.c_str()));
    cargs.push_back(nullptr);
    execvp(cargs[0], cargs.data());
    _exit(127);  // only gets here if exec blew it
  }

  // parent
  if (capture) close(pipefd[1]);
  if (capture) {
    capture->clear();
    char buf[4096];
    ssize_t n;
    while ((n = read(pipefd[0], buf, sizeof(buf))) > 0)
      capture->append(buf, (size_t)n);
    close(pipefd[0]);
  }

  int status = 0;
  while (waitpid(pid, &status, 0) < 0) {
  }
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
  return -1;
}

int runShell(const std::string& cmdline, std::string* capture,
             bool mergeStderr) {
  return run({"/bin/sh", "-c", cmdline}, capture, mergeStderr);
}

int runBash(const std::string& snippet, std::string* capture) {
  if (pathExists("/bin/bash")) return run({"/bin/bash", "-c", snippet}, capture);
  return runShell(snippet, capture);
}

std::string trim(const std::string& s) {
  size_t a = 0, b = s.size();
  while (a < b && isspace((unsigned char)s[a])) a++;
  while (b > a && isspace((unsigned char)s[b - 1])) b--;
  return s.substr(a, b - a);
}

std::vector<std::string> splitWs(const std::string& s) {
  std::vector<std::string> out;
  size_t i = 0;
  while (i < s.size()) {
    while (i < s.size() && isspace((unsigned char)s[i])) i++;
    if (i >= s.size()) break;
    size_t j = i;
    while (j < s.size() && !isspace((unsigned char)s[j])) j++;
    out.push_back(s.substr(i, j - i));
    i = j;
  }
  return out;
}

std::string toUpperFiltered(const std::string& s) {
  std::string out;
  for (char c : s) {
    if (c >= 'a' && c <= 'z')
      out += (char)(c - 'a' + 'A');
    else if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))
      out += c;
    else
      out += '_';
  }
  return out;
}

bool pathExists(const std::string& path) {
  struct stat st;
  return ::stat(path.c_str(), &st) == 0;
}

bool fileExists(const std::string& path) {
  struct stat st;
  return ::stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

bool dirExists(const std::string& path) {
  struct stat st;
  return ::stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

std::string readFile(const std::string& path, bool* ok) {
  FILE* f = fopen(path.c_str(), "r");
  if (!f) {
    if (ok) *ok = false;
    return "";
  }
  std::string out;
  char buf[8192];
  size_t n;
  while ((n = fread(buf, 1, sizeof(buf), f)) > 0) out.append(buf, n);
  fclose(f);
  if (ok) *ok = true;
  return out;
}

bool writeFile(const std::string& path, const std::string& data) {
  FILE* f = fopen(path.c_str(), "w");
  if (!f) return false;
  size_t w = fwrite(data.data(), 1, data.size(), f);
  fclose(f);
  return w == data.size();
}

std::vector<std::string> listDir(const std::string& dir) {
  std::vector<std::string> out;
  DIR* d = opendir(dir.c_str());
  if (!d) return out;
  while (struct dirent* e = readdir(d)) {
    std::string n = e->d_name;
    if (n == "." || n == "..") continue;
    out.push_back(dir + "/" + n);
  }
  closedir(d);
  std::sort(out.begin(), out.end());
  return out;
}

std::vector<std::string> globRegularFiles(const std::string& dir,
                                           const std::string& suffix) {
  std::vector<std::string> out;
  for (auto& p : listDir(dir)) {
    struct stat st;
    if (::stat(p.c_str(), &st) != 0) continue;
    if (!S_ISREG(st.st_mode) && !S_ISLNK(st.st_mode)) continue;
    if (!suffix.empty()) {
      if (p.size() < suffix.size()) continue;
      if (p.compare(p.size() - suffix.size(), suffix.size(), suffix) != 0)
        continue;
    }
    out.push_back(p);
  }
  return out;
}

bool isNonEmptyDir(const std::string& dir, bool* ok) {
  DIR* d = opendir(dir.c_str());
  if (!d) {
    if (ok) *ok = false;
    return false;
  }
  if (ok) *ok = true;
  while (struct dirent* e = readdir(d)) {
    std::string n = e->d_name;
    if (n == "." || n == "..") continue;
    closedir(d);
    return true;
  }
  closedir(d);
  return false;
}

int mkdirP(const std::string& path) {
  return runShell("mkdir -p " + shellEscape(path));
}

int chmodPath(const std::string& path, mode_t mode) {
  return ::chmod(path.c_str(), mode);
}

std::string shellEscape(const std::string& s) {
  std::string out = "'";
  for (char c : s) {
    if (c == '\'')
      out += "'\\''";
    else
      out += c;
  }
  return out + "'";
}

std::string getenvStr(const std::string& key, const std::string& def) {
  const char* v = ::getenv(key.c_str());
  return v ? v : def;
}

void setenvStr(const std::string& key, const std::string& val) {
  ::setenv(key.c_str(), val.c_str(), 1);
}

void clearScreen() {
  printf("\033[2J\033[H");
  fflush(stdout);
}

void pressEnter(const std::string& prompt) {
  printf("%s", prompt.c_str());
  fflush(stdout);
  int c;
  do {
    c = getchar();
  } while (c != '\n' && c != EOF);
}

char promptYN(const std::string& prompt) {
  printf("%s", prompt.c_str());
  fflush(stdout);
  int c = getchar();
  int d;
  do {
    d = getchar();
    if (d == '\n' || d == EOF) break;
  } while (true);
  printf("\n");
  if (c == EOF) return '\0';
  return (char)tolower(c);
}

void syncFs() { ::sync(); }

unsigned long pickRandom(unsigned long n) {
  if (n == 0) return 0;
  static bool seeded = []() {
    std::srand(static_cast<unsigned>(time(nullptr)) ^ static_cast<unsigned>(getpid()));
    return true;
  }();
  (void)seeded;
  return static_cast<unsigned long>(std::rand()) % n;
}

}
