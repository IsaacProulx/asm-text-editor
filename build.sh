nasm -felf64 -g -F stabs -o ./build/main.o main.asm
ld ./build/main.o -o ./out/editor
