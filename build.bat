set PATH=%PATH%;D:/Programming/QT/Tools/CMake_64/bin
set PATH=%PATH%;D:/Programming/QT/Tools/Ninja
set PATH=%PATH%;D:/Programming/QT/Tools/mingw1310_64/bin

cmake -B build -S . -G "MinGW Makefiles" -DCMAKE_PREFIX_PATH="D:/Programming/QT/6.10.1/mingw_64"
cd build
mingw32-make -j8