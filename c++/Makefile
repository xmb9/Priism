CXX ?= c++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra
BUILD_DATE := $(shell date +%Y-%m-%d)
CXXFLAGS += -DPRIISM_BUILD_DATE_STR="\"[$(BUILD_DATE)]\""

SRC = src/main.cpp src/util.cpp src/ui.cpp src/priism.cpp
OBJ = $(SRC:.cpp=.o)
BIN = priism
INIT_SRC = src/init.cpp src/util.cpp src/ui.cpp
INIT_OBJ = $(INIT_SRC:.cpp=.o)
INIT_BIN = priism-init

all: $(BIN) $(INIT_BIN)

$(BIN): $(OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJ)

$(INIT_BIN): $(INIT_OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $(INIT_OBJ)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

static: CXXFLAGS += -static -static-libstdc++ -static-libgcc
static: clean $(BIN) $(INIT_BIN)

clean:
	rm -f $(OBJ) $(INIT_OBJ) $(BIN) $(INIT_BIN)

.PHONY: all static clean
