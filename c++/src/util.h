#pragma once
// tiny helpers

#include <string>
#include <vector>

namespace priism {

// runs a program directly, no shell, exit code back
// if capture isn't null, stdout lands in there
int run(const std::vector<std::string>& argv, std::string* capture = nullptr,
        bool mergeStderr = false);

// for pipes and globs and stuff — goes through /bin/sh -c
int runShell(const std::string& cmdline, std::string* capture = nullptr,
             bool mergeStderr = false);

// payloads need bash
// they use [[ ]] and $RANDOM and whatnot and we don't want to break compatibility 
int runBash(const std::string& snippet, std::string* capture = nullptr);

std::string trim(const std::string& s);
std::vector<std::string> splitWs(const std::string& s);
// this is just `tr 'a-z' 'A-Z' | tr -dc '[A-Za-z0-9]_'`
std::string toUpperFiltered(const std::string& s);

bool fileExists(const std::string& path);
bool dirExists(const std::string& path);
bool pathExists(const std::string& path);
std::string readFile(const std::string& path, bool* ok = nullptr);
bool writeFile(const std::string& path, const std::string& data);

std::vector<std::string> listDir(const std::string& dir);
std::vector<std::string> globRegularFiles(const std::string& dir,
                                           const std::string& suffix = "");
bool isNonEmptyDir(const std::string& dir, bool* ok = nullptr);

int mkdirP(const std::string& path);
int chmodPath(const std::string& path, mode_t mode);

std::string shellEscape(const std::string& s);
std::string getenvStr(const std::string& key, const std::string& def = "");
void setenvStr(const std::string& key, const std::string& val);

void clearScreen();
void pressEnter(const std::string& prompt = "Press enter to continue.");
char promptYN(const std::string& prompt);

void syncFs();
unsigned long pickRandom(unsigned long n);

}
