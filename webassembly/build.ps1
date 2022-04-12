emsdk_env.ps1
emcc ../c/RayTracer.c -O3 -s WASM=1 -s SINGLE_FILE=1 -o RayTracer.html