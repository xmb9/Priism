#pragma once
#include <map>
#include <string>
#include <vector>

namespace priism {

struct Version {
  // version strings: use dev, stable, or release candidate
  std::string branch = "stable";
  std::string number = "3.0-rewrite";

  static std::string defaultBuildDate() {
#ifdef PRIISM_BUILD_DATE_STR
    return PRIISM_BUILD_DATE_STR;
#else
    return std::string("[") + __DATE__ + "]";
#endif
  }
  std::string buildDate = defaultBuildDate();

  std::string str() const { return "v" + number + " " + branch; }
};

struct Context {
  bool releaseBuild = true;
  std::string recoroot = "/mnt/recoroot";
  std::string shimroot = "/mnt/shimroot";
  std::string newrootMnt = "/mnt/shimroot";
  std::string statefulMnt = "/stateful";
  std::string priismMnt = "/mnt/priism";
  std::string priismImages = "/dev/disk/by-label/PRIISM_IMAGES";
  Version version;
  std::string boardName;
  std::string chromeosBoard; 
  std::string loop;          
  std::map<std::string, std::string> kernArgs;
};

[[noreturn]] void fail(const std::string& msg);
[[noreturn]] void hang();

std::string getLargestCrosBlockdev();
void exportKernelArgs(Context& ctx);
int copyLsb(Context& ctx);
int pvDircopy(const std::string& src, const std::string& dst);

void setupImagesPartition(Context& ctx);

void actionCredits(Context& ctx);
void actionShimboot(Context& ctx);
void actionInstallCros(Context& ctx);
void actionReboot(Context& ctx);
void actionShutdown(Context& ctx);
void actionExitDebug(Context& ctx);
void actionPayloads(Context& ctx);
void actionChangelog(Context& ctx);

int runMainLoop(Context& ctx);

}
