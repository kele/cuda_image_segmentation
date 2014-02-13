OBJS = cpu_utils.o cpu_seg.o
FLAGS = -Xcompiler -Wno-unused-result -arch=compute_30
CC = nvcc $(FLAGS)

all: FLAGS += -O2
all: flow Makefile

debug: FLAGS += -g -G
debug: flow Makefile

flow: main.o gpu_seg.o
	$(CC) $(OBJS) gpu_seg.o main.o -o flow
 
main.o: main.cu $(OBJS)
	$(CC) -c main.cu

gpu_seg.o: gpu_seg.cu $(OBJS)
	$(CC) -c gpu_seg.cu

%.o: %.cpp
	$(CC) -c $<
	
clean:
	rm -f flow
	rm -f *.o
