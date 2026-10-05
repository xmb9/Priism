#pragma once
// colors + splash + menus. basically the fun parts of priism.sh

#include <string>
#include <vector>

namespace priism {

extern const char* COLOR_RESET;
extern const char* COLOR_BLACK_B;
extern const char* COLOR_RED_B;
extern const char* COLOR_GREEN;
extern const char* COLOR_GREEN_B;
extern const char* COLOR_YELLOW;
extern const char* COLOR_YELLOW_B;
extern const char* COLOR_BLUE_B;
extern const char* COLOR_MAGENTA_B;
extern const char* COLOR_CYAN_B;

std::string randomSplash();
std::string randomRefusal();

void splash(const std::string& versionString, const std::string& buildDate);

std::string menu(const std::string& prompt,
                 const std::vector<std::string>& options);

// if PRIISM_USE_SHMENU=1, shell out to the old shmenu binary instead
// otherwise just uses menu() above
std::string menuCompat(const std::string& prompt,
                       const std::vector<std::string>& options);

}
